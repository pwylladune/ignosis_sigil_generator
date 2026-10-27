import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';
import 'package:ignosis_sigil_generator/src/config/legal_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('each legal page the app links to is published with the web app', () {
    for (final page in LegalPage.values) {
      final file = File('web/${Uri.parse(page.url).pathSegments.last}');
      expect(file.existsSync(), isTrue, reason: page.url);
      final html = file.readAsStringSync();
      expect(html, contains('info@ignosis.net'), reason: page.url);
      expect(html, contains('Michael Roland'), reason: page.url);
      // Every page links to the other two.
      for (final other in LegalPage.values) {
        expect(html, contains('href="${Uri.parse(other.url).pathSegments.last}"'), reason: '${page.url} -> ${other.url}');
      }
    }
  });

  test('the pages state the refund window and that burns are final', () {
    final refunds = File('web/refunds.html').readAsStringSync();
    expect(refunds, contains('14 days'));
    expect(refunds, contains('Burnt rites cannot be refunded'));
    final terms = File('web/terms.html').readAsStringSync();
    expect(terms, contains('State of Florida'));
    expect(terms, contains('not an investment'));
  });

  testWidgets('the menu opens the terms, privacy and refund pages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnosisApp());
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    for (final page in LegalPage.values) {
      expect(find.text(page.label), findsOneWidget);
    }
  });
}
