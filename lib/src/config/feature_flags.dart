import 'package:flutter/foundation.dart' show kIsWeb;

/// Compile-time feature flags.
///
/// The legacy `$IGNOSIS` token surfaces (wallet, starter pack, trade copy)
/// stay hidden while [kEnableChain] is false. The on-chain rite that replaced
/// them is [kEnableRite] (ADR 2026-10-25-ignosis-joule-token).
const bool kEnableChain = false;

/// Base URL of the rite backend, e.g. `https://api.ignosis.net`, set at
/// build time: `flutter build web --dart-define=IGNOSIS_RITE_API=...`.
const String kRiteApiBase = String.fromEnvironment('IGNOSIS_RITE_API');

/// The on-chain rite: a paid release burns Joules with the intent's salted
/// commitment. Web only for now (Stripe Checkout); store purchases come later.
const bool kEnableRite = kRiteApiBase != '' && kIsWeb;
