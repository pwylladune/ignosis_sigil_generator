import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/revenue_schema.dart';

/// Service managing In-App Purchases (iOS StoreKit & Android Google Play Billing).
class IapService {
  static final IapService instance = IapService._internal();
  IapService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  final Set<String> _unlockedSkins = {};

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  Set<String> get unlockedSkins => _unlockedSkins;

  /// Initializes store connection and loads unlocked items
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('ignosis_unlocked_skins') ?? [];
    _unlockedSkins.addAll(cached);

    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        _subscription = _iap.purchaseStream.listen(
          _handlePurchaseUpdates,
          onDone: () => _subscription?.cancel(),
          onError: (e) => debugPrint('[IAP] Purchase stream error: $e'),
        );
        await loadProducts();
      }
    } catch (e) {
      debugPrint('[IAP] Store unavailable or running on web/desktop: $e');
    }
  }

  /// Loads official product IDs from Apple / Google Play
  Future<void> loadProducts() async {
    const ids = {
      RevenueSchemaConfig.allSkinsBundleId,
      RevenueSchemaConfig.skinTechOccultId,
      RevenueSchemaConfig.skinDarkAcademiaId,
      RevenueSchemaConfig.skinCosmicId,
      RevenueSchemaConfig.skinSurrealistId,
      RevenueSchemaConfig.skinAlchemicalId,
      RevenueSchemaConfig.skinWiccanId,
      RevenueSchemaConfig.skinChaosId,
    };

    final response = await _iap.queryProductDetails(ids);
    _products = response.productDetails;
  }

  /// Handles incoming purchase verification and fulfillment
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Transaction pending user confirmation
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('[IAP] Error purchasing ${purchaseDetails.productID}: ${purchaseDetails.error}');
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        await _deliverProduct(purchaseDetails);
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Delivers a bought skin (or the bundle) by unlocking it locally.
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    _unlockedSkins.add(productId);
    if (productId == RevenueSchemaConfig.allSkinsBundleId) {
      _unlockedSkins.addAll([
        RevenueSchemaConfig.skinTechOccultId,
        RevenueSchemaConfig.skinDarkAcademiaId,
        RevenueSchemaConfig.skinCosmicId,
        RevenueSchemaConfig.skinSurrealistId,
        RevenueSchemaConfig.skinAlchemicalId,
        RevenueSchemaConfig.skinWiccanId,
        RevenueSchemaConfig.skinChaosId,
      ]);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ignosis_unlocked_skins', _unlockedSkins.toList());
  }

  /// Restores prior non-consumable skin purchases across user devices
  Future<void> restorePurchases() async {
    if (_isAvailable) {
      await _iap.restorePurchases();
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
