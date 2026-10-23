enum SubscriptionTier {
  neophyte('neophyte', 'Neophyte (Free)', 'Core sigil generators, local combustion, pen & ink export'),
  adept('adept', 'Adept Tier', 'All 8 esoteric skins, high-res PDF print sheets, unlimited ritual burns'),
  magus('magus', 'Magus Tier', 'Full access + monthly \$IGNOSIS energetic allowance & live on-chain consecrations');

  final String id;
  final String title;
  final String subtitle;
  const SubscriptionTier(this.id, this.title, this.subtitle);
}

class RevenueModelConfig {
  // Mobile (In-App Purchases) & Web (Stripe / Solana Pay)
  static const String adeptMonthlyIapId = 'com.ignosis.adept.monthly';
  static const String adeptYearlyIapId = 'com.ignosis.adept.yearly';
  static const String magusMonthlyIapId = 'com.ignosis.magus.monthly';

  // Digital Micro-transaction Packs
  static const String pack3BurnsIapId = 'com.ignosis.burns.pack3';
  static const String pack9BurnsIapId = 'com.ignosis.burns.pack9';

  static const double adeptMonthlyPriceUsd = 4.99;
  static const double adeptYearlyPriceUsd = 39.99;
  static const double magusMonthlyPriceUsd = 12.99;
  static const double pack3BurnsPriceUsd = 1.99;
}
