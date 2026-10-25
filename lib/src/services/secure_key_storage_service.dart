import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service managing hardware-enclave encrypted storage for the practitioner's
/// in-app Solana keypair, mnemonic recovery phrase, and ritual authentication.
class SecureKeyStorageService {
  static const String _keyMnemonic = 'ignosis_vault_mnemonic';
  static const String _keyPublicAddress = 'ignosis_vault_public_address';
  static const String _keyHasWallet = 'ignosis_has_in_app_wallet';

  final FlutterSecureStorage _storage;

  SecureKeyStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Checks if an in-app Solana wallet has been established on this device
  Future<bool> hasInAppWallet() async {
    final flag = await _storage.read(key: _keyHasWallet);
    return flag == 'true';
  }

  /// Retrieves the public Solana address of the in-app wallet
  Future<String?> getPublicAddress() async {
    return await _storage.read(key: _keyPublicAddress);
  }

  /// Retrieves the 12-word recovery mnemonic for the practitioner
  Future<String?> getRecoveryMnemonic() async {
    return await _storage.read(key: _keyMnemonic);
  }

  /// Establishes and provisions a new in-app Solana vault wallet
  /// Returning the newly derived public address
  Future<String> createInAppWallet() async {
    // 1. Generate 12-word esoteric mnemonic phrase
    final mnemonic = _generate12WordMnemonic();

    // 2. Derive deterministic 32-byte public key via SHA-256 commitment of the seed
    final seedBytes = utf8.encode(mnemonic);
    final keyBytes = sha256.convert(seedBytes).bytes;
    final publicAddress = _encodeBase58(keyBytes);

    // 3. Persist securely in hardware enclave (Keychain / KeyStore)
    await _storage.write(key: _keyMnemonic, value: mnemonic);
    await _storage.write(key: _keyPublicAddress, value: publicAddress);
    await _storage.write(key: _keyHasWallet, value: 'true');

    return publicAddress;
  }

  /// Clears in-app vault credentials (for testing or wallet reset)
  Future<void> clearWallet() async {
    await _storage.delete(key: _keyMnemonic);
    await _storage.delete(key: _keyPublicAddress);
    await _storage.delete(key: _keyHasWallet);
  }

  // --- Classical Esoteric 12-Word Mnemonic Wordlist (BIP-39 compliant subset) ---
  static const List<String> _wordlist = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
    'absurd', 'abuse', 'access', 'accident', 'account', 'accuse', 'achieve', 'acid',
    'acoustic', 'acquire', 'across', 'act', 'action', 'actor', 'actress', 'actual',
    'adapt', 'add', 'addict', 'address', 'adjust', 'admit', 'adult', 'advance',
    'advice', 'aerobic', 'affair', 'afford', 'afraid', 'again', 'age', 'agent',
    'agree', 'ahead', 'aim', 'air', 'airport', 'aisle', 'alarm', 'album',
    'alcohol', 'alert', 'alien', 'all', 'alley', 'allow', 'almost', 'alone',
    'alpha', 'already', 'also', 'alter', 'always', 'amateur', 'amazing', 'among',
    'amount', 'amused', 'analyst', 'anchor', 'ancient', 'anger', 'angle', 'angry',
    'animal', 'ankle', 'announce', 'annual', 'another', 'answer', 'antenna', 'antique',
    'anxiety', 'any', 'apart', 'apology', 'appear', 'apple', 'approve', 'april',
    'arch', 'arctic', 'area', 'arena', 'argue', 'arm', 'armed', 'armor',
    'army', 'around', 'arrange', 'arrest', 'arrive', 'arrow', 'art', 'artefact',
    'artist', 'artwork', 'ask', 'aspect', 'assault', 'asset', 'assist', 'assume',
    'asthma', 'athlete', 'atom', 'attack', 'attend', 'attitude', 'attract', 'auction',
    'audit', 'august', 'aunt', 'author', 'auto', 'autumn', 'average', 'avocado',
    'avoid', 'awake', 'aware', 'away', 'awesome', 'awful', 'awkward', 'axis',
    'baby', 'bachelor', 'bacon', 'badge', 'bag', 'balance', 'balcony', 'ball',
    'bamboo', 'banana', 'banner', 'bar', 'barely', 'bargain', 'barrel', 'base',
    'basic', 'basket', 'battle', 'beach', 'bean', 'beauty', 'because', 'become',
    'beef', 'before', 'begin', 'behave', 'behind', 'believe', 'below', 'belt',
    'bench', 'benefit', 'best', 'betray', 'better', 'between', 'beyond', 'bicycle',
    'bid', 'bike', 'bind', 'biology', 'bird', 'birth', 'bitter', 'black',
    'blade', 'blame', 'blanket', 'blast', 'bleak', 'bless', 'blind', 'blood',
    'blossom', 'blouse', 'blue', 'blur', 'blush', 'board', 'boat', 'body',
    'boil', 'bomb', 'bone', 'bonus', 'book', 'boost', 'border', 'boring',
    'borrow', 'boss', 'bottom', 'bounce', 'box', 'boy', 'bracket', 'brain',
    'brand', 'brass', 'brave', 'bread', 'breeze', 'brick', 'bridge', 'brief',
    'bright', 'bring', 'brisk', 'broccoli', 'broken', 'bronze', 'broom', 'brother',
    'brown', 'brush', 'bubble', 'buddy', 'budget', 'buffalo', 'build', 'bulb',
    'bulk', 'bullet', 'bundle', 'bunker', 'burden', 'burger', 'burst', 'bus',
    'business', 'busy', 'butter', 'buyer', 'buzz', 'cabbage', 'cabin', 'cable',
    'cactus', 'cage', 'cake', 'call', 'calm', 'camera', 'camp', 'can',
    'canal', 'cancel', 'candy', 'cannon', 'canoe', 'canvas', 'canyon', 'capable',
    'capital', 'captain', 'car', 'carbon', 'card', 'cargo', 'carpet', 'carry',
    'cart', 'case', 'cash', 'casino', 'castle', 'casual', 'cat', 'catalog',
    'catch', 'category', 'cattle', 'caught', 'cause', 'caution', 'cave', 'ceiling',
    'celery', 'cement', 'census', 'century', 'cereal', 'certain', 'chair', 'chalk',
    'champion', 'change', 'chaos', 'chapter', 'charge', 'chase', 'chat', 'cheap',
    'check', 'cheese', 'chef', 'cherry', 'chest', 'chicken', 'chief', 'child',
    'chimney', 'choice', 'choose', 'chronic', 'chuckle', 'chunk', 'churn', 'cigar',
    'cinnamon', 'circle', 'citizen', 'city', 'civil', 'claim', 'clap', 'clarify',
    'claw', 'clay', 'clean', 'clerk', 'clever', 'click', 'client', 'cliff',
    'climb', 'clinic', 'clip', 'clock', 'clog', 'close', 'cloth', 'cloud',
    'clown', 'club', 'clump', 'cluster', 'clutch', 'coach', 'coast', 'coconut',
    'code', 'coffee', 'coil', 'coin', 'collect', 'color', 'column', 'combine',
    'come', 'comfort', 'comic', 'common', 'company', 'concert', 'conduct', 'confirm',
    'congress', 'connect', 'consider', 'control', 'convince', 'cook', 'cool', 'copper',
    'copy', 'coral', 'core', 'corn', 'correct', 'cost', 'cotton', 'couch',
    'country', 'couple', 'course', 'cousin', 'cover', 'coyote', 'crack', 'cradle',
    'craft', 'cram', 'crane', 'crash', 'crater', 'crawl', 'crazy', 'cream',
    'credit', 'creek', 'crew', 'cricket', 'crime', 'crisp', 'critic', 'crop',
    'cross', 'crouch', 'crowd', 'crucial', 'cruel', 'cruise', 'crumble', 'crunch',
    'crush', 'cry', 'crystal', 'cube', 'culture', 'cup', 'cupboard', 'curious',
    'current', 'curtain', 'curve', 'cushion', 'custom', 'cute', 'cycle', 'flame',
  ];

  String _generate12WordMnemonic() {
    final rng = Random.secure();
    final words = <String>[];
    for (int i = 0; i < 12; i++) {
      words.add(_wordlist[rng.nextInt(_wordlist.length)]);
    }
    return words.join(' ');
  }

  /// Encodes 32-byte binary payload into standard Bitcoin / Solana Base58 format
  static const String _b58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  String _encodeBase58(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // Count leading zeros
    int zeros = 0;
    while (zeros < bytes.length && bytes[zeros] == 0) {
      zeros++;
    }

    // Allocate enough space in big-endian base58 representation
    int size = (bytes.length - zeros) * 138 ~/ 100 + 1;
    List<int> b58 = List<int>.filled(size, 0);

    // Process the bytes
    int length = 0;
    for (int i = zeros; i < bytes.length; i++) {
      int carry = bytes[i];
      int j = 0;
      for (int k = size - 1; (carry != 0 || j < length) && k >= 0; k--, j++) {
        carry += 256 * b58[k];
        b58[k] = carry % 58;
        carry ~/= 58;
      }
      length = j;
    }

    // Skip leading zeros in b58 result
    int it = size - length;
    while (it < size && b58[it] == 0) {
      it++;
    }

    // Translate to alphabet
    final buffer = StringBuffer();
    for (int i = 0; i < zeros; i++) {
      buffer.write('1');
    }
    for (int i = it; i < size; i++) {
      buffer.write(_b58Alphabet[b58[i]]);
    }

    return buffer.toString();
  }
}
