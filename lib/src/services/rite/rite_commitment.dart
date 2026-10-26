import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Domain prefix of the rite commitment; it changes only with the scheme.
const riteCommitmentDomain = 'IGNOSIS:v1';

/// The rite's commitment to an intent:
/// `SHA-256("IGNOSIS:v1" ‖ salt ‖ UTF-8(intent))`, as 64 lowercase hex
/// characters. Only the commitment leaves the device. Without the salt, the
/// burn cannot be linked to the intent, even by guessing short phrases.
String riteCommitment(String intent, List<int> salt) {
  if (salt.length != 32) throw ArgumentError.value(salt.length, 'salt', 'must be 32 bytes');
  return sha256.convert([...utf8.encode(riteCommitmentDomain), ...salt, ...utf8.encode(intent)]).toString();
}

/// 32 bytes from a cryptographically secure source.
Uint8List newRiteSalt([Random? random]) {
  final r = random ?? Random.secure();
  return Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
}

String hexEncode(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List hexDecode(String hex) =>
    Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
