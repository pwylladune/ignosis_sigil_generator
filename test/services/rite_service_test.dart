import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ignosis_sigil_generator/src/services/rite/rite_commitment.dart';
import 'package:ignosis_sigil_generator/src/services/rite/rite_service.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';
import 'package:ignosis_sigil_generator/src/ui/widgets/rite_witness.dart';
import 'package:shared_preferences/shared_preferences.dart';

const session = 'cs_test_aaaaaaaaaaaaaaaaaaaa1';
const signature = '3z8AGqQ4erPPkr7V1YvjTbxxoE1pkWqjniZ6UcJZ1VqhNU3cwC6s55QGDqoN6qizior5WiMeep31hQBmjLuBDEVZ';
const intent = 'I am free of the fear of the open road';

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
    final route = '${req.method} ${path.startsWith('/credit/') ? '/credit' : path.startsWith('/consecrate') || path.startsWith('/checkout') ? path : '/verify'}';
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

Map<String, Object?> credit({bool paid = true, bool spent = false}) =>
    {'success': true, 'paid': paid, 'revoked': false, 'spent': spent, 'burnt': spent, 'signature': null};

RiteService serviceFor(FakeBackend b) =>
    RiteService(client: b.client, apiBase: 'https://api.test/', pollInterval: const Duration(milliseconds: 1));

/// A service holding one paid credit.
Future<RiteService> withCredit(FakeBackend b) async {
  b.on('POST /checkout', [json(200, {'success': true, 'sessionId': session, 'url': 'https://checkout.stripe.com/x'})]);
  b.on('GET /credit', [json(200, credit())]);
  final s = serviceFor(b);
  await s.beginCheckout();
  await s.checkPayment();
  expect(s.credits, 1);
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

  test('a paid checkout becomes a credit that survives a reload', () async {
    final b = FakeBackend();
    b.on('POST /checkout', [json(200, {'success': true, 'sessionId': session, 'url': 'https://checkout.stripe.com/x'})]);
    b.on('GET /credit', [json(200, credit(paid: false)), json(200, credit())]);
    final s = serviceFor(b);
    expect(await s.beginCheckout(), Uri.parse('https://checkout.stripe.com/x'));
    expect(s.awaitingPayment, isTrue);
    await s.checkPayment();
    expect(s.credits, 0);
    await s.checkPayment();
    expect((s.awaitingPayment, s.credits), (false, 1));
    s.dispose();

    final reloaded = serviceFor(FakeBackend());
    await reloaded.load();
    expect(reloaded.credits, 1);
    reloaded.dispose();
  });

  test('the release burns the salted commitment, never the intent, and is read back', () async {
    final b = FakeBackend();
    final s = await withCredit(b);
    b.on('POST /consecrate', [
      json(200, {'success': true, 'signature': signature, 'joules': 1618, 'explorerUrl': 'https://explorer.solana.com/tx/$signature'}),
    ]);
    // The automatic read-back finds nothing yet; the explicit one below does.
    await s.releaseWith(intent);
    final body = b.bodies('/consecrate').single;
    final sent = body['commitment'] as String;
    expect(body['receiptData'], session);
    expect(body['platform'], 'web');
    expect(jsonEncode(body).contains('fear'), isFalse);
    final receipt = s.receipts.single;
    expect(riteCommitment(intent, hexDecode(receipt.saltHex)), sent);
    expect((s.state, s.credits, s.current?.signature), (RiteWitnessState.witnessed, 0, signature));

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

  test('a refunded payment fails the witness and is not retried', () async {
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
    expect((s.state, s.credits, b.bodies('/consecrate').length), (RiteWitnessState.none, 1, 0));
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

  testWidgets('the witness row offers a purchase, then a choice once paid', (tester) async {
    final b = FakeBackend();
    final s = serviceFor(b);
    final theme = SigilSkinTheme.getSkin(SigilSkinId.vellumDraft);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RiteWitnessRow(theme: theme, service: s))));
    await tester.runAsync(s.load);
    await tester.pump();
    expect(find.text('ADD'), findsOneWidget);
    expect(find.textContaining('1618 J'), findsWidgets);

    b.on('POST /checkout', [json(200, {'success': true, 'sessionId': session, 'url': 'https://checkout.stripe.com/x'})]);
    b.on('GET /credit', [json(200, credit())]);
    await tester.runAsync(() async {
      await s.beginCheckout();
      await s.checkPayment();
    });
    await tester.pump();
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Your release will be burnt on-chain.'), findsOneWidget);
    s.dispose();
  });
}
