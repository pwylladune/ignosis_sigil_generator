import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/feature_flags.dart';
import '../../models/revenue_schema.dart';
import 'rite_commitment.dart';

/// The product a rite is sold as, on every platform.
const riteProductId = RevenueSchemaConfig.riteProductId;

/// What the rite needs from an app store (Google Play on Android); the
/// purchase service provides it. A rite purchase stays unconsumed until its
/// burn is confirmed: until then it is the practitioner's credit.
abstract class RiteStore implements Listenable {
  /// Purchase tokens of rite purchases, paid and not yet consumed.
  List<String> get unconsumedRites;

  /// The store's localised price, once known.
  String? get ritePrice;

  /// Opens the store's purchase sheet; false if the store or product is unavailable.
  Future<bool> buyRite();

  /// Consumes a rite whose burn is confirmed, so another can be bought.
  Future<void> consumeRite(String purchaseToken);
}

/// A burn this device started: the payment it spends ([platform] and its
/// [receipt]: a Checkout session on the web, a Play purchase token on
/// Android) and the commitment it burns. Saved before the request, so a retry
/// burns the same commitment and never asks the backend for a second burn.
@immutable
class RiteSpend {
  const RiteSpend({required this.platform, required this.receipt, required this.saltHex, required this.commitment});

  final String platform;
  final String receipt;
  final String saltHex;
  final String commitment;

  Map<String, Object> toJson() => {'platform': platform, 'receipt': receipt, 'salt': saltHex, 'commitment': commitment};

  static RiteSpend? fromJson(Object? json) {
    if (json is! Map) return null;
    final platform = json['platform'] ?? 'web', r = json['receipt'] ?? json['sessionId'];
    final salt = json['salt'], c = json['commitment'];
    if (platform is! String || r is! String || salt is! String || c is! String) return null;
    return RiteSpend(platform: platform, receipt: r, saltHex: salt, commitment: c);
  }
}

/// A confirmed burn, kept on the device. The salt lets the practitioner,
/// and only them, show that the burn's commitment is their intent. The
/// intent itself is never stored.
@immutable
class RiteReceipt {
  const RiteReceipt({
    required this.signature,
    required this.commitment,
    required this.saltHex,
    required this.joules,
    required this.explorerUrl,
    required this.at,
    this.verified = false,
  });

  final String signature;
  final String commitment;
  final String saltHex;
  final int joules;
  final String explorerUrl;
  final DateTime at;

  /// The on-chain record was read back and carries this commitment.
  final bool verified;

  RiteReceipt asVerified() => RiteReceipt(
      signature: signature,
      commitment: commitment,
      saltHex: saltHex,
      joules: joules,
      explorerUrl: explorerUrl,
      at: at,
      verified: true);

  Map<String, Object> toJson() => {
        'signature': signature,
        'commitment': commitment,
        'salt': saltHex,
        'joules': joules,
        'explorerUrl': explorerUrl,
        'at': at.toIso8601String(),
      };

  static RiteReceipt? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      return RiteReceipt(
        signature: json['signature'] as String,
        commitment: json['commitment'] as String,
        saltHex: json['salt'] as String,
        joules: json['joules'] as int,
        explorerUrl: json['explorerUrl'] as String,
        at: DateTime.parse(json['at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Where the current release's on-chain burn stands.
enum RiteWitnessState { none, burning, witnessed, failed }

/// The on-chain rite (ADR 2026-10-25-ignosis-joule-token).
///
/// 1. Before or during the rite, the practitioner pays: on the web through
///    Stripe Checkout (the session ID becomes a credit once the backend
///    reports it paid), on Android through Google Play (an unconsumed rite
///    purchase is the credit; see [attachStore]).
/// 2. On release, [releaseWith] computes the salted commitment of the intent
///    on the device and spends one credit on a burn of the rite's Joules.
/// 3. The confirmed burn is read back from the chain and kept as a receipt.
///
/// Nothing on this path reports success before the backend confirms the burn.
class RiteService extends ChangeNotifier {
  RiteService({http.Client? client, String apiBase = kRiteApiBase, this.pollInterval = const Duration(seconds: 3)})
      : _client = client ?? http.Client(),
        _api = apiBase.replaceAll(RegExp(r'/+$'), '');

  static final RiteService instance = RiteService();

  static const _kPending = 'ignosis_rite_pending_checkouts';
  static const _kCredits = 'ignosis_rite_credits';
  static const _kSpend = 'ignosis_rite_spend';
  static const _kReceipts = 'ignosis_rite_receipts';
  static const _kSpentTokens = 'ignosis_rite_spent_tokens';

  final http.Client _client;
  final String _api;
  final Duration pollInterval;

  /// Opened checkouts not yet paid, as `sessionId|openedAtMs`. Kept until
  /// paid or a day old (Stripe expires sessions after 24 hours), so a payment
  /// finished late, or after another checkout was opened, still becomes a credit.
  final List<String> _pending = [];
  final List<String> _credits = [];

  /// The app store, on platforms that pay through one (Android).
  RiteStore? _store;

  /// Store purchases whose burn is confirmed: never spent again, and consumed
  /// as soon as the store hands them back.
  final Set<String> _spentTokens = {};
  RiteSpend? _spend;
  final List<RiteReceipt> _receipts = [];
  RiteWitnessState _state = RiteWitnessState.none;
  RiteReceipt? _current;
  String? _notice;
  bool _witness = true;
  Timer? _poll;
  int _pollsLeft = 0;
  bool _spending = false;
  Future<void>? _load;

  /// A checkout was opened and is not paid yet.
  bool get awaitingPayment => _pending.isNotEmpty;

  /// Pays through an app store instead of Stripe Checkout.
  bool get usesStore => _store != null;

  /// The store's price for a rite, once known.
  String? get storePrice => _store?.ritePrice;

  /// Store purchases ready to spend.
  List<String> get _storeCredits => [
        for (final t in _store?.unconsumedRites ?? const <String>[])
          if (!_spentTokens.contains(t) && t != _spend?.receipt) t
      ];

  /// Paid rites ready to spend.
  int get credits => usesStore ? _storeCredits.length : _credits.length;

  /// Whether the next release is burnt on-chain (the practitioner's choice).
  bool get witness => _witness;

  /// The next release will be witnessed.
  bool get willWitness => _witness && credits > 0;

  RiteWitnessState get state => _state;

  /// The receipt of the current release, once confirmed.
  RiteReceipt? get current => _current;

  List<RiteReceipt> get receipts => List.unmodifiable(_receipts);

  /// The latest user-facing message, if any.
  String? get notice => _notice;

  set witness(bool value) {
    _witness = value;
    notifyListeners();
  }

  Uri _url(String path) => Uri.parse('$_api/api/v1/rite$path');

  /// Pays through [store] from now on (Android). Its rite purchases are the
  /// credits; confirmed ones are consumed whenever the store reports them.
  void attachStore(RiteStore store) {
    if (identical(_store, store)) return;
    _store?.removeListener(_onStoreChanged);
    _store = store..addListener(_onStoreChanged);
    _onStoreChanged();
  }

  void _onStoreChanged() {
    final store = _store;
    if (store == null) return;
    for (final t in store.unconsumedRites) {
      if (_spentTokens.contains(t)) unawaited(store.consumeRite(t));
    }
    notifyListeners();
  }

  /// Opens the store's purchase sheet for one rite, or sets a [notice].
  Future<void> buyInStore() async {
    final store = _store;
    _notice = null;
    if (store == null || !await store.buyRite()) {
      _notice = 'The store is not available right now. Please try again.';
    }
    notifyListeners();
  }

  /// Restores credits and any unfinished payment or burn from the device.
  Future<void> load() => _load ??= _restore();

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final dayAgo = DateTime.now().millisecondsSinceEpoch - const Duration(hours: 24).inMilliseconds;
    _pending
      ..clear()
      ..addAll((prefs.getStringList(_kPending) ?? const []).where((p) => (int.tryParse(p.split('|').last) ?? 0) > dayAgo));
    _credits
      ..clear()
      ..addAll(prefs.getStringList(_kCredits) ?? const []);
    _spentTokens
      ..clear()
      ..addAll(prefs.getStringList(_kSpentTokens) ?? const []);
    _spend = RiteSpend.fromJson(_decode(prefs.getString(_kSpend)));
    final saved = _decode(prefs.getString(_kReceipts));
    _receipts
      ..clear()
      ..addAll([if (saved is List) ...saved.map(RiteReceipt.fromJson).whereType<RiteReceipt>()]);
    notifyListeners();
    if (_pending.isNotEmpty) _startPolling();
    // A burn interrupted by a closed tab is finished now (the backend's
    // sweeper finishes it regardless; this only fetches the receipt).
    if (_spend != null) unawaited(_spendNow());
  }

  Object? _decode(String? s) {
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kPending, _pending);
    await prefs.setStringList(_kCredits, _credits);
    // Kept short: a consumed token never comes back from the store.
    await prefs.setStringList(_kSpentTokens, _spentTokens.toList().reversed.take(100).toList());
    final spend = _spend;
    spend == null ? await prefs.remove(_kSpend) : await prefs.setString(_kSpend, jsonEncode(spend.toJson()));
    await prefs.setString(_kReceipts, jsonEncode([for (final r in _receipts.take(50)) r.toJson()]));
  }

  /// Creates a Checkout session and returns its URL, or null with a [notice].
  Future<Uri?> beginCheckout() async {
    await load();
    _notice = null;
    try {
      final res = await _client.post(_url('/checkout'));
      final body = jsonDecode(res.body);
      if (res.statusCode != 200 || body is! Map || body['url'] is! String || body['sessionId'] is! String) {
        throw const FormatException('checkout');
      }
      _pending.add('${body['sessionId']}|${DateTime.now().millisecondsSinceEpoch}');
      await _save();
      _startPolling();
      notifyListeners();
      return Uri.parse(body['url'] as String);
    } catch (_) {
      _notice = 'Checkout could not be opened. Please try again.';
      notifyListeners();
      return null;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    // About 20 minutes at the default interval; Checkout sessions last longer,
    // but a payer who left that long reopens the app (and [load]) to finish.
    _pollsLeft = (const Duration(minutes: 20).inMilliseconds / pollInterval.inMilliseconds).ceil();
    _poll = Timer.periodic(pollInterval, (_) => checkPayment());
  }

  /// Asks the backend whether the open checkouts have been paid.
  Future<void> checkPayment() async {
    if (_pending.isEmpty || --_pollsLeft < 0) {
      _poll?.cancel();
      return;
    }
    var changed = false;
    for (final entry in List.of(_pending)) {
      final session = entry.split('|').first;
      final credit = await _credit(session);
      if (credit == null) continue;
      if (credit['paid'] == true && credit['spent'] != true) {
        _credits.add(session);
      } else if (credit['revoked'] != true && credit['spent'] != true) {
        continue; // Not paid yet.
      }
      _pending.remove(entry);
      changed = true;
    }
    if (!changed) return;
    if (_pending.isEmpty) _poll?.cancel();
    await _save();
    notifyListeners();
  }

  Future<Map?> _credit(String session) async {
    try {
      final res = await _client.get(_url('/credit/$session'));
      final body = jsonDecode(res.body);
      return res.statusCode == 200 && body is Map ? body : null;
    } catch (_) {
      return null;
    }
  }

  /// The release: if the next release is witnessed, spends one credit on a
  /// burn of [intent]'s commitment. Call before the intent is cleared.
  Future<void> releaseWith(String intent) async {
    await load();
    if (_spend != null) return; // An earlier burn is still being finished.
    if (!willWitness) {
      // An off-chain release: no record shows for it.
      _state = RiteWitnessState.none;
      _current = null;
      notifyListeners();
      return;
    }
    final salt = newRiteSalt();
    _spend = RiteSpend(
      platform: usesStore ? 'android' : 'web',
      receipt: usesStore ? _storeCredits.first : _credits.removeAt(0),
      saltHex: hexEncode(salt),
      commitment: riteCommitment(intent, salt),
    );
    _current = null;
    _state = RiteWitnessState.burning;
    _notice = null;
    await _save();
    notifyListeners();
    await _spendNow();
  }

  Future<void> _spendNow() async {
    final spend = _spend;
    if (spend == null || _spending) return;
    _spending = true;
    _state = RiteWitnessState.burning;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < 40 && _spend == spend; attempt++) {
        final outcome = await _consecrate(spend);
        if (outcome != null) return await _finish(spend, outcome);
        await Future<void>.delayed(pollInterval * 2);
      }
      // Still not confirmed: it stays saved and the backend keeps working on
      // it; the receipt is fetched on the next load.
      _notice = 'Your burn is still being confirmed on-chain.';
      notifyListeners();
    } finally {
      _spending = false;
    }
  }

  /// One attempt. Returns the final outcome, or null to try again.
  Future<_Outcome?> _consecrate(RiteSpend spend) async {
    try {
      final res = await _client.post(
        _url('/consecrate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'platform': spend.platform,
          'productId': riteProductId,
          'receiptData': spend.receipt,
          'commitment': spend.commitment,
        }),
      );
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      switch (res.statusCode) {
        case 200:
          return _Outcome.burnt(body['signature'] as String, body['joules'] as int, body['explorerUrl'] as String);
        case 402:
        case 409:
          return _Outcome.refused(
              res.statusCode == 402
                  ? 'This payment could not be used (it may have been refunded).'
                  : 'This payment was already used for another release.',
              conflict: res.statusCode == 409);
        default:
          return null; // 202 pending, 5xx, rate limit: ask again.
      }
    } catch (_) {
      return null; // Offline: ask again.
    }
  }

  Future<void> _finish(RiteSpend spend, _Outcome outcome) async {
    _spend = null;
    // A store purchase that burnt (or was already used) is spent: consume it.
    // A refused one is left alone; the store still holds it.
    final spentInStore = spend.platform != 'web' && (outcome.error == null || outcome.conflict);
    if (spentInStore) {
      _spentTokens.add(spend.receipt);
      unawaited(_store?.consumeRite(spend.receipt));
    }
    if (outcome.error != null) {
      _state = RiteWitnessState.failed;
      _notice = outcome.error;
    } else {
      final receipt = RiteReceipt(
        signature: outcome.signature!,
        commitment: spend.commitment,
        saltHex: spend.saltHex,
        joules: outcome.joules!,
        explorerUrl: outcome.explorerUrl!,
        at: DateTime.now(),
      );
      _receipts.insert(0, receipt);
      _current = receipt;
      _state = RiteWitnessState.witnessed;
    }
    await _save();
    notifyListeners();
    final current = _current;
    if (current != null) unawaited(verify(current));
  }

  /// Reads the burn back from the chain (through the backend's public check)
  /// and marks the receipt verified if it carries this commitment.
  Future<bool> verify(RiteReceipt receipt) async {
    try {
      final res = await _client.get(_url('/${receipt.signature}'));
      final body = jsonDecode(res.body);
      final ok = res.statusCode == 200 &&
          body is Map &&
          body['commitment'] == receipt.commitment &&
          body['joules'] == receipt.joules;
      if (ok && identical(_current, receipt)) {
        _current = receipt.asVerified();
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}

class _Outcome {
  _Outcome.burnt(this.signature, this.joules, this.explorerUrl)
      : error = null,
        conflict = false;
  _Outcome.refused(this.error, {this.conflict = false})
      : signature = null,
        joules = null,
        explorerUrl = null;

  final String? signature;
  final int? joules;
  final String? explorerUrl;
  final String? error;

  /// The payment had already been spent on another release.
  final bool conflict;
}
