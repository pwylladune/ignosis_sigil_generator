import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Configuration and Solana RPC bridge for $IGNOSIS on-chain consecration
class SolanaIgnosisBridge {
  static const String devnetRpc = 'https://api.devnet.solana.com';
  static const String mainnetRpc = 'https://api.mainnet-beta.solana.com';

  /// Program ID for the Ignosis Incinerator Anchor program
  static const String programId = 'Ignos1s111111111111111111111111111111111111';

  /// Official $IGNOSIS Mint Address (Solana SPL)
  static const String ignosisMintAddress = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

  /// Fixed burn cost per ritual consecration (e.g. 93 $IGNOSIS = 93 * 10^9 atomic units)
  static final BigInt consecrationBurnUnits = BigInt.from(93000000000);

  /// Hashes the raw intent into a one-way 32-byte cryptographic commitment
  /// Ensuring private statements of intent are NEVER published on the public ledger
  static List<int> hashIntentForLedger(String rawIntent) {
    final bytes = utf8.encode(rawIntent.trim().toUpperCase());
    return sha256.convert(bytes).bytes;
  }

  /// Builds the instruction payload for the Anchor `consecrate_burn` method
  static Map<String, dynamic> createBurnPayload({
    required String practitionerWallet,
    required String rawIntent,
    BigInt? customAmount,
  }) {
    final amount = customAmount ?? consecrationBurnUnits;
    final intentHash = hashIntentForLedger(rawIntent);

    return {
      'programId': programId,
      'instruction': 'consecrate_burn',
      'practitioner': practitionerWallet,
      'mint': ignosisMintAddress,
      'amount': amount.toString(),
      'intentHashHex': intentHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
