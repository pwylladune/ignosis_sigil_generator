import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignosis_sigil_generator/src/models/revenue_schema.dart';
import 'package:ignosis_sigil_generator/src/services/rite/rite_commitment.dart';
import 'package:ignosis_sigil_generator/src/services/rite/rite_service.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';
import 'package:ignosis_sigil_generator/src/ui/widgets/rite_witness.dart';
import 'package:shared_preferences/shared_preferences.dart';

const session = 'cs_test_aaaaaaaaaaaaaaaaaaaa1';
const signature = '3z8AGqQ4erPPkr7V1YvjTbxxoE1pkWqjniZ6UcJZ1VqhNU3cwC6s55QGDqoN6qizior5WiMeep31hQBmjLuBDEVZ';
const intent = 'I am free of the fear of the open road';
final pack3 = RevenueSchemaConfig.ritePacks[0];
final pack7 = RevenueSchemaConfig.ritePacks[1];

/// A scripted backend: each route answers from a queue (the last answer repeats).
class FakeBackend {
  final Map<String, List<http.Response>> answers = {};
  final List<http.Request> requests = [];
  int failuresBeforeAnswer = 0;

  void on(String route, List<http.Response> responses) => answers[route] = responses;

  late final client = MockClient((req) async {
    requests.add(req);
    if (failuresBeforeAnswer > 0) {
      failuresBeforeAnswer--;
      throw http.ClientException('offline');
    }
    final path = req.url.path.replaceFirst('/api/v1/rite', '');
    final route = '${req.method} ${path.startsWith('/credit/') ? '/credit' : const ['/consecrate', '/checkout', '/packs'].contains(path) ? path : '/verify'}';
    final queue = answers[route];
    if (queue == null || queue.isEmpty) return http.Response('{}', 404);
    return queue.length > 1 ? queue.removeAt(0) : queue.first;
  });

  List<Map> bodies(String path) => [
        for (final r in requests)
          if (r.url.path.endsWith(path) && r.method == 'POST') jsonDecode(r.body) as Map
      ];
}

http.Response json(int status, Object body) => http.Response(jsonEncode(body), status);

/// The backend's answer for a web payment of [rites], [used] of them spent.
Map<String, Object?> credit({bool paid = true, int rites = 3, int used = 0}) => {
      'success': true,
      'paid': paid,
      'revoked': false,
      'rites': paid ? rites : 0,
      'used': used,
      'remaining': paid ? rites - used : 0,
      'spent': paid && used >= rites,
      'burnt': used > 0,
      'signature': null,
    };

http.Response burnt({int remaining = 2}) => json(200, {
      'success': true,
      'signature': signature,
      'joules': 1618,
      'explorerUrl': 'https://explorer.solana.com/tx/$signature',
      'remaining': remaining,
    });

/// Google Play as the rite sees it: unconsumed package purchases by token.
class FakeStore extends ChangeNotifier implements RiteStore {
  final Map<String, String> tokens = {};
  final List<String> consumed = [];

  /// Consume calls are lost (as when the app closes before one lands).
  bool loseConsumes = false;

  @override
  Map<String, String> get unconsumedRites => Map.of(tokens);

  @override
  String? packPrice(RitePack pack) => pack == pack3 ? r'$2.99' : null;

  @override
  Future<bool> buyRite(RitePack pack) async {
    tokens['play-token-${tokens.length + 1}'] = pack.productId;
    notifyListeners();
    return true;
  }

  @override
  Future<void> consumeRite(String purchaseToken) async {
    if (loseConsumes) return;
    consumed.add(purchaseToken);
    tokens.remove(purchaseToken);
    notifyListeners();
  }
}

RiteService serviceFor(FakeBackend b) =>
    RiteService(client: b.client, apiBase: 'https://api.test/', pollInterval: const Duration(milliseconds: 1));

/// A service holding one paid package of three rites.
Future<RiteService> withCredit(FakeBackend b) async {
  b.on('POST /checkout', [json(200, {'success': true, 'sessionId': session, 'url': 'https://checkout.stripe.com/x'})]);
  b.on('GET /credit', [json(200, credit())]);
  final s = serviceFor(b);
  await s.beginCheckout(pack3);
  await s.checkPayment();
  expect(s.credits, 3);
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('commitment', () {
    final salt = List.generate(32, (i) => i);
    test('matches the backend and devnet tool (Node crypto vectors)', () {
      expect(riteCommitment(intent, salt), '12278cf392fdc13ddfddcd201be2efbc4750d9e580474913bbc7cb6085127a63');
      expect(riteCommitment('Ψυχή · 心', salt), '82c972c243b83565250ff9b51a6893e71f862e2ec2840beebbc108b72b873ae9');
    });
    test('needs a 32-byte salt; a fresh salt changes the commitment', () {
      expect(() => riteCommitment(intent, [1, 2, 3]), throwsArgumentError);
      expect(riteCommitment(intent, newRiteSalt()), isNot(riteCommitment(intent, newRiteSalt())));
      expect(hexDecode(hexEncode(salt)), salt);
    });
  });

  test('a paid checkout becomes a package of rites that survives a reload', () async {
    final b = FakeBackend();
    b.on('POST /checkout', [json(200, {'success': true, 'sessionId': session, 'url': 'https://checkout.stripe.com/x'})]);
    b.on('GET /credit', [json(200, credit(paid: false)), json(200, credit(rites: 7))]);
    final s = serviceFor(b);
    expect(await s.beginCheckout(pack7), Uri.parse('https://checkout.stripe.com/x'));
    expect(b.bodies('/checkout').single, {'pack': 'pack7'});
    expect(s.awaitingPayment, isTrue);
    await s.checkPayment();
    expect(s.credits, 0);
    await s.checkPayment();
    expect((s.awaitingPayment, s.credits), (false, 7));
    s.dispose();

    final reloaded = serviceFor(FakeBackend());
    await reloaded.load();
    expect(reloaded.credits, 7);
    reloaded.dispose();
  });

  test('each release spends one rite; the backend count is kept', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    b.on('POST /consecrate', [burnt(remaining: 2), burnt(remaining: 1), burnt(remaining: 0)]);
    await s.releaseWith(intent);
    expect(s.credits, 2);
    await s.releaseWith('second intent');
    await s.releaseWith('third intent');
    expect((s.credits, s.receipts.length), (0, 3));
    expect(b.bodies('/consecrate').map((m) => m['receiptData']).toSet(), {session});
    expect(b.bodies('/consecrate').map((m) => m['commitment']).toSet(), hasLength(3));
    // Spent: the next release stays off-chain.
    await s.releaseWith('fourth intent');
    expect((s.state, b.bodies('/consecrate').length), (RiteWitnessState.none, 3));
    s.dispose();
  });

  test('a package the backend reports used up is dropped', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    b.on('POST /consecrate', [json(409, {'success': false, 'exhausted': true})]);
    await s.releaseWith(intent);
    expect((s.state, s.credits), (RiteWitnessState.failed, 0));
    expect(s.notice, contains('Every rite'));
    s.dispose();
  });

  test('web prices come from the backend', () async {
    final b = FakeBackend()
      ..on('GET /packs', [
        json(200, {
          'success': true,
          'packs': [
            {'id': 'pack3', 'rites': 3, 'amount': 900, 'currency': 'usd'},
            {'id': 'pack7', 'rites': 7, 'amount': 1799, 'currency': 'eur'},
          ],
        }),
      ]);
    final s = serviceFor(b);
    await s.loadOffers();
    expect([for (final o in s.offers) (o.pack.rites, o.price)], [(3, r'$9'), (7, '€17.99'), (21, null)]);
    expect(formatRitePrice(1250, 'jpy'), '12.50 JPY');
    s.dispose();
  });

  test('the release burns the salted commitment, never the intent, and is read back', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    b.on('POST /consecrate', [burnt()]);
    // The automatic read-back finds nothing yet; the explicit one below does.
    await s.releaseWith(intent);
    final body = b.bodies('/consecrate').single;
    final sent = body['commitment'] as String;
    expect(body['receiptData'], session);
    expect(body['platform'], 'web');
    expect(jsonEncode(body).contains('fear'), isFalse);
    final receipt = s.receipts.single;
    expect(riteCommitment(intent, hexDecode(receipt.saltHex)), sent);
    expect((s.state, s.credits, s.current?.signature), (RiteWitnessState.witnessed, 2, signature));

    b.on('GET /verify', [json(200, {'success': true, 'commitment': sent, 'joules': 1618})]);
    expect(await s.verify(s.current!), isTrue);
    expect(s.current!.verified, isTrue);
    s.dispose();
  });

  test('a pending burn is asked about again with the same commitment', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    b.on('POST /consecrate', [
      json(202, {'success': false, 'pending': true, 'signature': signature}),
      json(502, {'success': false}),
      json(200, {'success': true, 'signature': signature, 'joules': 1618, 'explorerUrl': 'x'}),
    ]);
    await s.releaseWith(intent);
    final commitments = b.bodies('/consecrate').map((m) => m['commitment']).toSet();
    expect(b.bodies('/consecrate'), hasLength(3));
    expect(commitments, hasLength(1));
    expect(s.state, RiteWitnessState.witnessed);
    s.dispose();
  });

  test('an interrupted burn resumes after a reload with the same commitment', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    b.failuresBeforeAnswer = 1000; // Offline for the rest of this session.
    await s.releaseWith(intent);
    expect(s.state, RiteWitnessState.burning);
    s.dispose();

    final b2 = FakeBackend()
      ..on('POST /consecrate', [json(200, {'success': true, 'signature': signature, 'joules': 1618, 'explorerUrl': 'x'})]);
    final resumed = serviceFor(b2);
    await resumed.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final receipt = resumed.receipts.single;
    expect(riteCommitment(intent, hexDecode(receipt.saltHex)), b2.bodies('/consecrate').single['commitment']);
    resumed.dispose();
  });

  test('a refunded payment fails the witness, drops its rites and is not retried', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    b.on('POST /consecrate', [json(402, {'success': false})]);
    await s.releaseWith(intent);
    expect((s.state, s.credits), (RiteWitnessState.failed, 0));
    expect(s.notice, contains('refunded'));
    expect(b.bodies('/consecrate'), hasLength(1));
    s.dispose();
  });

  test('with the witness switched off, the release stays off-chain', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    s.witness = false;
    await s.releaseWith(intent);
    expect((s.state, s.credits, b.bodies('/consecrate').length), (RiteWitnessState.none, 3, 0));
    s.dispose();
  });

  test('checkouts older than a day are forgotten', () async {
    final old = DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'ignosis_rite_pending_checkouts': ['$session|$old'],
    });
    final s = serviceFor(FakeBackend());
    await s.load();
    expect(s.awaitingPayment, isFalse);
    s.dispose();
  });

  group('Android (Google Play)', () {
    test('a Play package is spent one rite per release, then consumed', () async {
      final b = FakeBackend()..on('POST /consecrate', [burnt(remaining: 2), burnt(remaining: 1), burnt(remaining: 0)]);
      final store = FakeStore();
      final s = serviceFor(b)..attachStore(store);
      expect((s.usesStore, s.credits), (true, 0));
      expect([for (final o in s.offers) o.price], [r'$2.99', null, null]);
      await s.buyInStore(pack3);
      expect(s.credits, 3);
      await s.releaseWith(intent);
      final body = b.bodies('/consecrate').single;
      expect((body['platform'], body['receiptData'], body['productId']), ('android', 'play-token-1', pack3.productId));
      expect(riteCommitment(intent, hexDecode(s.receipts.single.saltHex)), body['commitment']);
      expect((s.state, s.credits), (RiteWitnessState.witnessed, 2));
      expect(store.consumed, isEmpty);
      await s.releaseWith('second intent');
      await s.releaseWith('third intent');
      expect(s.credits, 0);
      expect(store.consumed, ['play-token-1']);
      s.dispose();
    });

    test('a refused Play purchase is not consumed; a spent one is', () async {
      final b = FakeBackend()..on('POST /consecrate', [json(402, {'success': false})]);
      final store = FakeStore();
      final s = serviceFor(b)..attachStore(store);
      await s.buyInStore(pack3);
      await s.releaseWith(intent);
      expect((s.state, s.credits), (RiteWitnessState.failed, 3), reason: 'its rite is given back');
      expect(store.consumed, isEmpty);

      b.on('POST /consecrate', [json(409, {'success': false, 'exhausted': true})]);
      await s.releaseWith(intent);
      expect(store.consumed, ['play-token-1'], reason: 'its rites are all used');
      expect(s.credits, 0);
      s.dispose();
    });

    test('a used-up package the store hands back after a restart is consumed then', () async {
      final b = FakeBackend()..on('POST /consecrate', [burnt(remaining: 0)]);
      final store = FakeStore()..loseConsumes = true;
      final s = serviceFor(b)..attachStore(store);
      await s.buyInStore(pack3);
      await s.releaseWith(intent);
      expect((s.state, store.tokens.length, s.credits), (RiteWitnessState.witnessed, 1, 0));
      s.dispose();

      final restarted = serviceFor(FakeBackend());
      await restarted.load();
      final again = FakeStore()..tokens['play-token-1'] = pack3.productId;
      restarted.attachStore(again);
      expect(again.consumed, ['play-token-1']);
      expect(restarted.credits, 0, reason: 'a spent purchase is never offered again');
      restarted.dispose();
    });

    test('the rites left in a package survive a restart', () async {
      final b = FakeBackend()..on('POST /consecrate', [burnt(remaining: 6)]);
      final store = FakeStore();
      final s = serviceFor(b)..attachStore(store);
      await s.buyInStore(pack7);
      await s.releaseWith(intent);
      expect(s.credits, 6);
      s.dispose();

      final restarted = serviceFor(FakeBackend());
      await restarted.load();
      restarted.attachStore(store);
      expect(restarted.credits, 6);
      restarted.dispose();
    });

    test('a spend saved before the Android support reads as a web spend', () {
      final spend = RiteSpend.fromJson({'sessionId': session, 'salt': '00', 'commitment': 'c'})!;
      expect((spend.platform, spend.receipt), ('web', session));
    });

    test('a web credit saved before packages counts as one rite', () async {
      SharedPreferences.setMockInitialValues({
        'ignosis_rite_credits': [session],
      });
      final s = serviceFor(FakeBackend());
      await s.load();
      expect(s.credits, 1);
      s.dispose();
    });
  });

  testWidgets('the witness row offers packages, then a choice once paid', (tester) async {
    final b = FakeBackend()
      ..on('GET /packs', [
        json(200, {
          'success': true,
          'packs': [
            {'id': 'pack3', 'rites': 3, 'amount': 900, 'currency': 'usd'},
          ],
        }),
      ]);
    final s = serviceFor(b);
    final theme = SigilSkinTheme.getSkin(SigilSkinId.vellumDraft);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RiteWitnessRow(theme: theme, service: s))));
    await tester.runAsync(() async {
      await s.load();
      await s.loadOffers();
    });
    await tester.pump();
    expect(find.textContaining('1618 J'), findsWidgets);

    await tester.tap(find.text('ADD RITES'));
    await tester.pumpAndSettle();
    expect(find.text('3 RITES'), findsOneWidget);
    expect(find.text(r'$9'), findsOneWidget);
    expect(find.text('7 RITES'), findsOneWidget);
    expect(find.text('21 RITES'), findsOneWidget);
    expect(find.textContaining('By buying you agree to the Terms'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Refunds'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    b.on('POST /checkout', [json(200, {'success': true, 'sessionId': session, 'url': 'https://checkout.stripe.com/x'})]);
    b.on('GET /credit', [json(200, credit())]);
    await tester.runAsync(() async {
      await s.beginCheckout(pack3);
      await s.checkPayment();
    });
    await tester.pump();
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('3 rites left. Your release will be burnt on-chain.'), findsOneWidget);
    s.dispose();
  });
}
