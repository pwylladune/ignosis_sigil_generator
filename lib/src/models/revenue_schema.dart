/// Revenue schema and in-app purchase catalogue for IGNOSIS v1.0.
///
/// 1. The core studio is free and fully functional: all engines, the burn,
///    PNG share and the printable PDF burn sheet.
/// 2. Seven premium skins are one-time, non-consumable unlocks, sold
///    individually or as a bundle. The default Vellum & Ink skin is free.
/// 3. The on-chain rite is sold in packages: one payment buys a number of
///    witnessed releases. The practitioner never receives crypto
///    (ADR 2026-10-25-ignosis-joule-token).
class RevenueSchemaConfig {
  // Prices are configured in App Store Connect / Play Console (USD 0.99 per
  // skin, 3.99 for the bundle) and always displayed from the store, localised.

  // Product IDs (App Store and Google Play non-consumables).
  static const String skinTechOccultId = 'net.ignosis.studio.skin.tech_occult';
  static const String skinDarkAcademiaId = 'net.ignosis.studio.skin.dark_academia';
  static const String skinCosmicId = 'net.ignosis.studio.skin.cosmic';
  static const String skinSurrealistId = 'net.ignosis.studio.skin.surrealist';
  static const String skinAlchemicalId = 'net.ignosis.studio.skin.alchemical';
  static const String skinWiccanId = 'net.ignosis.studio.skin.wiccan';
  static const String skinChaosId = 'net.ignosis.studio.skin.chaos';
  static const String allSkinsBundleId = 'net.ignosis.studio.skin.all_bundle';

  /// The on-chain rite packages, smallest first (matches the backend's
  /// services/ritePacks.ts). Each is a Play consumable, consumed once all its
  /// rites are burnt; on the web each has a Stripe price.
  static const List<RitePack> ritePacks = [RitePack('pack7', 7), RitePack('pack21', 21), RitePack('pack100', 100)];

  static Set<String> get riteProductIds => {for (final p in ritePacks) p.productId};

  static RitePack? ritePackForProduct(String productId) {
    for (final p in ritePacks) {
      if (p.productId == productId) return p;
    }
    return null;
  }

  /// Product that unlocks each premium skin, keyed by `SigilSkinId.key`.
  /// Skins not listed here are free.
  static const Map<String, String> skinProductIds = {
    'techOccult': skinTechOccultId,
    'darkAcademia': skinDarkAcademiaId,
    'cosmic': skinCosmicId,
    'surrealist': skinSurrealistId,
    'alchemical': skinAlchemicalId,
    'wiccan': skinWiccanId,
    'chaos': skinChaosId,
  };

  static Set<String> get allProductIds => {...skinProductIds.values, allSkinsBundleId};
}

/// A package of rites: one payment, [rites] witnessed releases.
class RitePack {
  const RitePack(this.id, this.rites);

  /// Short ID, as the web checkout and the backend name it.
  final String id;
  final int rites;

  /// The Google Play product.
  String get productId => 'net.ignosis.studio.rite.$id';
}
