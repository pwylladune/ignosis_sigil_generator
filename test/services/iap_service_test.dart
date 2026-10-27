import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/models/revenue_schema.dart';
import 'package:ignosis_sigil_generator/src/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

GooglePlayPurchaseDetails playPurchase(String productId, PurchaseStateWrapper state, PurchaseStatus status) =>
    GooglePlayPurchaseDetails(
      productID: productId,
      verificationData: PurchaseVerificationData(localVerificationData: '{}', serverVerificationData: 'token', source: 'google_play'),
      transactionDate: '0',
      status: status,
      billingClientPurchase: PurchaseWrapper(
        orderId: 'order',
        packageName: 'pkg',
        purchaseTime: 0,
        purchaseToken: 'token',
        signature: 'sig',
        products: [productId],
        isAutoRenewing: false,
        originalJson: '{}',
        isAcknowledged: false,
        purchaseState: state,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The service is a singleton: start every test from a clean state.
  setUp(() {
    IapService.instance.resetForTest();
    // These tests cover the paid path, which ships once the store sells skins.
    IapService.instance.sellSkins = true;
    SharedPreferences.setMockInitialValues({});
  });

  test('entitlements come only from recorded purchases; no simulated unlocks', () async {
    SharedPreferences.setMockInitialValues({
      'ignosis_unlocked_skins': [RevenueSchemaConfig.skinCosmicId],
    });
    final iap = IapService.instance;
    await iap.initialize(); // no store in tests: must not throw or block

    expect(iap.isAvailable, isFalse);
    expect(iap.isSkinUnlocked('vellumDraft'), isTrue, reason: 'default skin is free');
    expect(iap.isSkinUnlocked('cosmic'), isTrue, reason: 'restored from cache');
    expect(iap.isSkinUnlocked('chaos'), isFalse);

    // With no store, buying must fail and unlock nothing.
    expect(await iap.buy(RevenueSchemaConfig.skinChaosId), PurchaseStart.storeUnavailable);
    expect(await iap.buy(RevenueSchemaConfig.allSkinsBundleId), PurchaseStart.storeUnavailable);
    expect(await iap.restorePurchases(), PurchaseStart.storeUnavailable);
    expect(iap.isSkinUnlocked('chaos'), isFalse);
  });

  test('Android restore of a purchase still pending payment does not unlock', () async {
    final iap = IapService.instance;
    expect(iap.isSkinUnlocked('wiccan'), isFalse, reason: 'clean state per test');
    await iap.initialize();
    final pending = playPurchase(RevenueSchemaConfig.skinWiccanId, PurchaseStateWrapper.pending, PurchaseStatus.restored);
    await iap.handlePurchaseUpdates([pending]);
    expect(iap.isSkinUnlocked('wiccan'), isFalse);

    final paid = playPurchase(RevenueSchemaConfig.skinWiccanId, PurchaseStateWrapper.purchased, PurchaseStatus.restored);
    await iap.handlePurchaseUpdates([paid]);
    expect(iap.isSkinUnlocked('wiccan'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('ignosis_unlocked_skins'), contains(RevenueSchemaConfig.skinWiccanId));
  });

  test('a store error is surfaced, and unknown products never unlock', () async {
    final iap = IapService.instance;
    await iap.initialize();
    final failed = playPurchase(RevenueSchemaConfig.skinChaosId, PurchaseStateWrapper.unspecified_state, PurchaseStatus.error)
      ..error = IAPError(source: 'google_play', code: 'x', message: 'Card declined');
    await iap.handlePurchaseUpdates([failed]);
    expect(iap.lastError, 'Card declined');
    expect(iap.isSkinUnlocked('chaos'), isFalse);

    await iap.handlePurchaseUpdates([playPurchase('com.example.other', PurchaseStateWrapper.purchased, PurchaseStatus.purchased)]);
    expect(iap.unlockedProducts.contains('com.example.other'), isFalse);
  });

  test('every premium skin has a product and the bundle covers them all', () {
    expect(RevenueSchemaConfig.skinProductIds.length, 7);
    expect(RevenueSchemaConfig.allProductIds.length, 8);
    expect(RevenueSchemaConfig.skinProductIds.containsKey('vellumDraft'), isFalse);
  });

  test('the rite packages are 3, 7 and 21 rites, each its own Play product', () {
    expect([for (final p in RevenueSchemaConfig.ritePacks) p.rites], [3, 7, 21]);
    expect(RevenueSchemaConfig.riteProductIds,
        {'net.ignosis.studio.rite.pack3', 'net.ignosis.studio.rite.pack7', 'net.ignosis.studio.rite.pack21'});
    expect(RevenueSchemaConfig.ritePackForProduct('net.ignosis.studio.rite.pack7')?.rites, 7);
    expect(RevenueSchemaConfig.ritePackForProduct('net.ignosis.studio.rite'), isNull);
  });

  test('a paid rite package is held as an unconsumed purchase; a pending one is not', () async {
    final iap = IapService.instance;
    final pack = RevenueSchemaConfig.ritePacks[1];
    await iap.initialize();
    await iap.handlePurchaseUpdates([playPurchase(pack.productId, PurchaseStateWrapper.pending, PurchaseStatus.pending)]);
    expect(iap.unconsumedRites, isEmpty);
    await iap.handlePurchaseUpdates(
        [playPurchase(pack.productId, PurchaseStateWrapper.purchased, PurchaseStatus.purchased)]);
    expect(iap.unconsumedRites, {'token': pack.productId});
    // A rite is not a skin, and unlocks nothing.
    iap.sellSkins = true;
    expect(iap.isSkinUnlocked('cosmic'), isFalse);
    // With no store in tests, buying a package cannot start.
    expect(await iap.buyRite(pack), isFalse);
  });
}
