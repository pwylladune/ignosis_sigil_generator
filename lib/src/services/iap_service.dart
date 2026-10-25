import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/revenue_schema.dart';

/// Outcome of asking the store to start a purchase.
enum PurchaseStart {
  /// The store sheet was shown; the result arrives on the purchase stream.
  started,

  /// The store is not available on this device or platform (e.g. web).
  storeUnavailable,

  /// The product was not returned by the store (not configured, not approved,
  /// or the store could not be reached).
  productUnavailable,

  /// The store reported an error while starting; see [IapService.lastError].
  failed,
}

/// In-app purchases for premium skins (StoreKit / Google Play Billing).
///
/// Entitlements are granted only for store events that represent a completed
/// payment: `purchased`, or `restored` with (on Android) a Play purchase state
/// of `purchased`. Pending purchases are never unlocked or acknowledged. There
/// is no simulated or offline fulfilment.
///
/// Unlocks are cached locally so skins work offline. The cache only grows:
/// refunds are not revoked on the device (an accepted risk for cosmetic
/// non-consumables). On Android, owned purchases are re-queried at startup and
/// on resume so purchases that completed while the app was closed are
/// delivered and acknowledged before Play's 3-day auto-refund.
class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  static const _prefsKey = 'ignosis_unlocked_skins';

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  AppLifecycleListener? _lifecycle;
  Future<void>? _init;

  bool _isAvailable = false;
  Map<String, ProductDetails> _products = {};
  final Set<String> _unlocked = {};
  String? _lastError;
  bool _restoring = false;

  bool get isAvailable => _isAvailable;
  bool get isRestoring => _restoring;
  Set<String> get unlockedProducts => Set.unmodifiable(_unlocked);

  /// Last purchase error message, cleared when a purchase starts or succeeds.
  String? get lastError => _lastError;

  /// Localised store product, if the store returned it.
  ProductDetails? product(String id) => _products[id];

  /// Whether the skin with [skinKey] (`SigilSkinId.key`) may be used.
  bool isSkinUnlocked(String skinKey) {
    final productId = RevenueSchemaConfig.skinProductIds[skinKey];
    if (productId == null) return true; // free skin
    return _unlocked.contains(productId) || _unlocked.contains(RevenueSchemaConfig.allSkinsBundleId);
  }

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Connects to the store and loads cached unlocks. Safe to call more than
  /// once; call it without awaiting so a slow store never blocks startup.
  Future<void> initialize() => _init ??= _initialize();

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _unlocked.addAll(prefs.getStringList(_prefsKey) ?? const []);
    notifyListeners();

    try {
      final iap = InAppPurchase.instance;
      _isAvailable = await iap.isAvailable();
      if (!_isAvailable) return;
      _iap = iap;
      _subscription = iap.purchaseStream.listen(
        handlePurchaseUpdates,
        onError: (Object e) => _fail('$e'),
      );
      await _loadProducts();
      if (_isAndroid) {
        unawaited(_syncOwnedPurchases());
        _lifecycle = AppLifecycleListener(onResume: () => unawaited(_syncOwnedPurchases()));
      }
    } catch (e) {
      _isAvailable = false;
      debugPrint('[IAP] Store unavailable: $e');
    }
    notifyListeners();
  }

  /// Queries products; failures (offline, store error) leave the map as is so
  /// a later purchase attempt retries.
  Future<void> _loadProducts() async {
    final iap = _iap;
    if (iap == null) return;
    try {
      final response = await iap.queryProductDetails(RevenueSchemaConfig.allProductIds);
      if (response.error != null) {
        debugPrint('[IAP] Product query failed: ${response.error!.message}');
      }
      if (response.productDetails.isNotEmpty) {
        _products = {..._products, for (final p in response.productDetails) p.id: p};
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[IAP] Products not found in store: ${response.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('[IAP] Product query threw: $e');
    }
    notifyListeners();
  }

  /// Android only: replays owned purchases through the purchase stream, so any
  /// that completed while the app was closed are delivered and acknowledged.
  /// Silent: errors are logged, not shown.
  Future<void> _syncOwnedPurchases() async {
    try {
      await _iap?.restorePurchases();
    } catch (e) {
      debugPrint('[IAP] Owned-purchase sync failed: $e');
    }
  }

  /// Starts the purchase of a skin (or the bundle) by product ID.
  Future<PurchaseStart> buy(String productId) async {
    await initialize();
    final iap = _iap;
    if (!_isAvailable || iap == null) return PurchaseStart.storeUnavailable;
    if (!_products.containsKey(productId)) await _loadProducts();
    final product = _products[productId];
    if (product == null) return PurchaseStart.productUnavailable;
    _lastError = null;
    notifyListeners();
    try {
      final ok = await iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      return ok ? PurchaseStart.started : PurchaseStart.storeUnavailable;
    } catch (e) {
      _fail(_describe(e));
      return PurchaseStart.failed;
    }
  }

  /// Asks the store to replay prior non-consumable purchases on this account.
  Future<PurchaseStart> restorePurchases() async {
    await initialize();
    final iap = _iap;
    if (!_isAvailable || iap == null) return PurchaseStart.storeUnavailable;
    _restoring = true;
    _lastError = null;
    notifyListeners();
    try {
      await iap.restorePurchases();
      return PurchaseStart.started;
    } catch (e) {
      _fail(_describe(e));
      return PurchaseStart.failed;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// True when the event represents money actually received.
  static bool _isPaid(PurchaseDetails p) {
    if (p.status != PurchaseStatus.purchased && p.status != PurchaseStatus.restored) return false;
    // Android's restore marks every owned purchase "restored", including ones
    // still pending payment; only Play's own state can tell them apart.
    if (p is GooglePlayPurchaseDetails) {
      return p.billingClientPurchase.purchaseState == PurchaseStateWrapper.purchased;
    }
    return true;
  }

  @visibleForTesting
  Future<void> handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    var changed = false;
    for (final p in purchases) {
      if (p.status == PurchaseStatus.error) {
        _fail(p.error?.message ?? 'Purchase failed');
      }
      final paid = _isPaid(p);
      if (paid && RevenueSchemaConfig.allProductIds.contains(p.productID)) {
        changed |= _unlocked.add(p.productID);
        _lastError = null;
      }
      // Never acknowledge a pending Android purchase: Play rejects it, and it
      // is redelivered once payment clears.
      final pendingOnPlay = p is GooglePlayPurchaseDetails && !paid && p.status != PurchaseStatus.error;
      if (p.pendingCompletePurchase && !pendingOnPlay) {
        try {
          await _iap?.completePurchase(p);
        } catch (e) {
          debugPrint('[IAP] completePurchase failed for ${p.productID}: $e');
        }
      }
    }
    if (changed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _unlocked.toList());
    }
    notifyListeners();
  }

  void _fail(String message) {
    _lastError = message;
    notifyListeners();
  }

  static String _describe(Object e) {
    if (e is InAppPurchaseException) return e.message ?? 'The store reported an error.';
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return 'The store reported an error.';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
