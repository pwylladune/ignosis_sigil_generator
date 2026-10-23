/// Revenue Schema & In-App Purchase Catalog for IGNOSIS
///
/// Principles:
/// 1. Free version is 100% fully functional: All math engines, local burns, PDF printing,
///    AND full external wallet connection (Phantom, Solflare, etc.) to burn externally acquired $IGNOSIS.
/// 2. Aesthetic Skins: $0.99 one-time unlocks individual premium skins (or $3.99 for all-skins master pack).
/// 3. Ignition Starter Pack: $1.99 provisions/links a fresh Solana wallet and deposits 279 $IGNOSIS tokens.
/// 4. Burn Quantities: Fully modifiable by the practitioner (defaults to 93 $IGNOSIS).
class RevenueSchemaConfig {
  // One-time microtransactions
  static const double individualSkinPriceUsd = 0.99;
  static const double allSkinsBundlePriceUsd = 3.99;
  static const double ignitionStarterPackPriceUsd = 1.99; // Sets up wallet + deposits 279 $IGNOSIS

  // Product IDs (iOS App Store & Google Play In-App Purchases)
  static const String skinTechOccultId = 'com.ignosis.skin.tech_occult';
  static const String skinDarkAcademiaId = 'com.ignosis.skin.dark_academia';
  static const String skinCosmicId = 'com.ignosis.skin.cosmic';
  static const String skinSurrealistId = 'com.ignosis.skin.surrealist';
  static const String skinAlchemicalId = 'com.ignosis.skin.alchemical';
  static const String skinWiccanId = 'com.ignosis.skin.wiccan';
  static const String skinChaosId = 'com.ignosis.skin.chaos';
  static const String allSkinsBundleId = 'com.ignosis.skin.all_bundle';
  static const String ignitionStarterPackId = 'com.ignosis.pack.ignition_279';

  // Token amounts
  static const int defaultBurnAmount = 93;
  static const int starterPackTokensDeposited = 279;
}
