import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/feature_flags.dart';
import '../../models/revenue_schema.dart';
import 'rite_commitment.dart';

/// The product named for a web payment. The backend reads the package from
/// the Checkout session itself, so the client's word is not needed.
const _webProductId = 'stripe-checkout';

/// What the rite needs from an app store (Google Play on Android); the
/// purchase service provides it. A package purchase stays unconsumed until its
/// rites are all burnt: until then it is the practitioner's credit.
abstract class RiteStore implements Listenable {
  /// Rite packages paid and not yet consumed: purchase token to product ID.
  Map<String, String> get unconsumedRites;

  /// The store's localised price for [pack], once known.
  String? packPrice(RitePack pack);

  /// Opens the store's purchase sheet; false if the store or product is unavailable.
  Future<bool> buyRite(RitePack pack);

  /// Consumes a package whose rites are all burnt, so another can be bought.
  Future<void> consumeRite(String purchaseToken);
}

/// A package on sale, with its price once known.
@immutable
class RiteOffer {
  const RiteOffer(this.pack, this.price);

  final RitePack pack;
  final String? price;
}

/// A price as the backend reports it (from Stripe), for display.
String formatRitePrice(int amount, String currency) {
  const symbols = {'usd': r'$', 'eur': '€', 'gbp': '£', 'cad': r'CA$', 'aud': r'A$'};
  final value = amount % 100 == 0 ? '${amount ~/ 100}' : (amount / 100).toStringAsFixed(2);
  final symbol = symbols[currency.toLowerCase()];
  return symbol == null ? '$value ${currency.toUpperCase()}' : '$symbol$value';
}

/// A burn this device started: the payment it spends ([platform] and its
/// [receipt]: a Checkout session on the web, a Play purchase token of
/// [productId] on Android) and the commitment it burns. Saved before the
/// request, so a retry burns the same commitment and never asks the backend
/// for a second burn.
@immutable
class RiteSpend {
  const RiteSpend({
    required this.platform,
    required this.receipt,
    required this.saltHex,
    required this.commitment,
    this.productId = _webProductId,
  });

  final String platform;
  final String receipt;
  final String productId;
  final String saltHex;
  final String commitment;

  Map<String, Object> toJson() =>
      {'platform': platform, 'receipt': receipt, 'product': productId, 'salt': saltHex, 'commitment': commitment};

  static RiteSpend? fromJson(Object? json) {
    if (json is! Map) return null;
    final platform = json['platform'] ?? 'web', r = json['receipt'] ?? json['sessionId'];
    final product = json['product'] ?? _webProductId;
    final salt = json['salt'], c = json['commitment'];
    if (platform is! String || r is! String || product is! String || salt is! String || c is! String) return null;
    return RiteSpend(platform: platform, receipt: r, productId: product, saltHex: salt, commitment: c);
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
/// 1. Before or during the rite, the practitioner buys a package of rites: on
///    the web through Stripe Checkout (the session ID becomes a credit once
///    the backend reports it paid), on Android through Google Play (an
///    unconsumed package purchase is the credit; see [attachStore]).
/// 2. On release, [releaseWith] computes the salted commitment of the intent
///    on the device and spends one rite on a burn of the rite's Joules. The
///    backend counts the rites; its count after each burn is the one kept.
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
  static const _kStoreLeft = 'ignosis_rite_store_left';

  final http.Client _client;
  final String _api;
  final Duration pollInterval;

  /// Opened checkouts not yet paid, as `sessionId|openedAtMs`. Kept until
  /// paid or a day old (Stripe expires sessions after 24 hours), so a payment
  /// finished late, or after another checkout was opened, still becomes a credit.
  final List<String> _pending = [];

  /// Paid web checkouts with rites left: session ID to rites left.
  final Map<String, int> _credits = {};

  /// Rites left in each store purchase, once a burn has reported it; a
  /// purchase not listed has its package's full count.
  final Map<String, int> _storeLeft = {};

  /// Web prices by package ID, from the backend.
  final Map<String, String> _webPrices = {};

  /// The app store, on platforms that pay through one (Android).
  RiteStore? _store;

  /// Store purchases whose rites are all spent: never spent again, and
  /// consumed as soon as the store hands them back.
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

  /// The packages on sale, with prices once known (from the store on Android,
  /// from the backend on the web).
  List<RiteOffer> get offers => [
        for (final pack in RevenueSchemaConfig.ritePacks)
          RiteOffer(pack, usesStore ? _store!.packPrice(pack) : _webPrices[pack.id])
      ];

  int _storeLeftOf(String token) =>
      _storeLeft[token] ??
      RevenueSchemaConfig.ritePackForProduct(_store?.unconsumedRites[token] ?? '')?.rites ??
      0;

  /// Store purchases with rites left to spend.
  List<String> get _storeCredits => [
        for (final t in _store?.unconsumedRites.keys ?? const <String>[])
          if (!_spentTokens.contains(t) && _storeLeftOf(t) > 0) t
      ];

  /// Paid rites ready to spend, across every package bought.
  int get credits => usesStore
      ? _storeCredits.fold(0, (n, t) => n + _storeLeftOf(t))
      : _credits.values.fold(0, (n, left) => n + left);

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
    for (final t in store.unconsumedRites.keys) {
      if (_spentTokens.contains(t)) unawaited(store.consumeRite(t));
    }
    notifyListeners();
  }

  /// Opens the store's purchase sheet for [pack], or sets a [notice].
  Future<void> buyInStore(RitePack pack) async {
    final store = _store;
    _notice = null;
    if (store == null || !await store.buyRite(pack)) {
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
      ..addAll(_counts(prefs.getStringList(_kCredits)));
    _storeLeft
      ..clear()
      ..addAll(_counts(prefs.getStringList(_kStoreLeft)));
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
    if (_store == null) unawaited(loadOffers());
    // A burn interrupted by a closed tab is finished now (the backend's
    // sweeper finishes it regardless; this only fetches the receipt).
    if (_spend != null) unawaited(_spendNow());
  }

  /// `id|count` entries; an entry without a count (saved before packages) is one rite.
  static Map<String, int> _counts(List<String>? entries) => {
        for (final e in entries ?? const <String>[])
          if (e.isNotEmpty)
            e.contains('|') ? e.substring(0, e.lastIndexOf('|')) : e:
                e.contains('|') ? int.tryParse(e.substring(e.lastIndexOf('|') + 1)) ?? 1 : 1
      };

  static List<String> _entries(Map<String, int> counts) => [for (final e in counts.entries) '${e.key}|${e.value}'];

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
    await prefs.setStringList(_kCredits, _entries(_credits));
    // Kept short, like the spent tokens.
    await prefs.setStringList(_kStoreLeft, _entries(_storeLeft).reversed.take(100).toList());
    // Kept short: a consumed token never comes back from the store.
    await prefs.setStringList(_kSpentTokens, _spentTokens.toList().reversed.take(100).toList());
    final spend = _spend;
    spend == null ? await prefs.remove(_kSpend) : await prefs.setString(_kSpend, jsonEncode(spend.toJson()));
    await prefs.setString(_kReceipts, jsonEncode([for (final r in _receipts.take(50)) r.toJson()]));
  }

  /// Reads the web prices of the packages from the backend (Stripe's prices).
  Future<void> loadOffers() async {
    try {
      final res = await _client.get(_url('/packs'));
      final body = jsonDecode(res.body);
      if (res.statusCode != 200 || body is! Map || body['packs'] is! List) return;
      for (final p in body['packs'] as List) {
        if (p is Map && p['id'] is String && p['amount'] is int && p['currency'] is String) {
          _webPrices[p['id'] as String] = formatRitePrice(p['amount'] as int, p['currency'] as String);
        }
      }
      notifyListeners();
    } catch (_) {
      // Prices are shown when known; checkout works without them.
    }
  }

  /// Creates a Checkout session for [pack] and returns its URL, or null with a [notice].
  Future<Uri?> beginCheckout(RitePack pack) async {
    await load();
    _notice = null;
    try {
      final res = await _client.post(
        _url('/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pack': pack.id}),
      );
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
      final left = credit['remaining'];
      if (credit['paid'] == true && left is int && left > 0) {
        _credits[session] = left;
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

  /// The release: if the next release is witnessed, spends one rite on a
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
    final String receipt;
    var product = _webProductId;
    if (usesStore) {
      receipt = _storeCredits.first;
      product = _store!.unconsumedRites[receipt]!;
      _storeLeft[receipt] = _storeLeftOf(receipt) - 1;
    } else {
      // Counted down here; the backend's count replaces it once the burn is in.
      receipt = _credits.keys.first;
      _setWebLeft(receipt, _credits[receipt]! - 1);
    }
    _spend = RiteSpend(
      platform: usesStore ? 'android' : 'web',
      receipt: receipt,
      productId: product,
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
          'productId': spend.productId,
          'receiptData': spend.receipt,
          'commitment': spend.commitment,
        }),
      );
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      switch (res.statusCode) {
        case 200:
          return _Outcome.burnt(body['signature'] as String, body['joules'] as int, body['explorerUrl'] as String,
              remaining: body['remaining'] is int ? body['remaining'] as int : null);
        case 402:
          return _Outcome.refused('This payment could not be used (it may have been refunded).');
        case 409:
          return _Outcome.refused(
              body['exhausted'] == true
                  ? 'Every rite in this package has been used.'
                  : 'This payment was already used for another release.',
              conflict: true);
        default:
          return null; // 202 pending, 5xx, rate limit: ask again.
      }
    } catch (_) {
      return null; // Offline: ask again.
    }
  }

  void _setWebLeft(String session, int left) => left > 0 ? _credits[session] = left : _credits.remove(session);

  Future<void> _finish(RiteSpend spend, _Outcome outcome) async {
    _spend = null;
    final token = spend.receipt;
    if (spend.platform == 'web') {
      if (outcome.error != null) {
        _credits.remove(token); // Refunded, or every rite spent.
      } else if (outcome.remaining != null) {
        _setWebLeft(token, outcome.remaining!);
      }
    } else {
      if (outcome.error == null && outcome.remaining != null) _storeLeft[token] = outcome.remaining!;
      // A refused purchase is left alone (the store still holds it) and its
      // rite is given back; one with no rites left is spent: consume it.
      if (outcome.error != null && !outcome.conflict) _storeLeft[token] = _storeLeftOf(token) + 1;
      if (outcome.conflict || (outcome.error == null && _storeLeftOf(token) <= 0)) {
        _spentTokens.add(token);
        unawaited(_store?.consumeRite(token));
      }
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
  _Outcome.burnt(this.signature, this.joules, this.explorerUrl, {this.remaining})
      : error = null,
        conflict = false;
  _Outcome.refused(this.error, {this.conflict = false})
      : signature = null,
        joules = null,
        explorerUrl = null,
        remaining = null;

  final String? signature;
  final int? joules;
  final String? explorerUrl;
  final String? error;

  /// Rites left in the payment's package after this burn, as the backend counts.
  final int? remaining;

  /// The payment has no rites left for this release.
  final bool conflict;
}
