import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Compile-time feature flags.
///
/// The legacy `$IGNOSIS` token surfaces (wallet, starter pack, trade copy)
/// stay hidden while [kEnableChain] is false. The on-chain rite that replaced
/// them is [kEnableRite] (ADR 2026-10-25-ignosis-joule-token).
const bool kEnableChain = false;

/// Premium skins are sold through the stores only in builds made with
/// `--dart-define=IGNOSIS_SELL_SKINS=true`. Until the store products exist,
/// every skin is free, so nobody meets a lock they cannot open.
const bool kSellSkins = bool.fromEnvironment('IGNOSIS_SELL_SKINS');

/// Base URL of the rite backend, e.g. `https://api.ignosis.net`, set at
/// build time: `flutter build web --dart-define=IGNOSIS_RITE_API=...`.
const String kRiteApiBase = String.fromEnvironment('IGNOSIS_RITE_API');

/// The on-chain rite: a paid release burns Joules with the intent's salted
/// commitment. On the web it is paid through Stripe Checkout, on Android
/// through Google Play Billing; iOS comes later.
bool get kEnableRite => kRiteApiBase != '' && (kIsWeb || defaultTargetPlatform == TargetPlatform.android);
