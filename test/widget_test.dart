import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('IGNOSIS studio smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnosisApp());
    expect(find.text('IGNOSIS'), findsOneWidget);
    // No on-chain surfaces in the v1.0 build.
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
    expect(find.textContaining('\$IGNOSIS'), findsNothing);
  });

  testWidgets('a saved premium skin is not applied without an entitlement', (tester) async {
    SharedPreferences.setMockInitialValues({'ignosis_selected_skin': 'chaos'});
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('VELLUM & INK (DEFAULT)'), findsOneWidget);
    expect(find.text('CHAOS (LIBER NULL)'), findsNothing);
  });

  testWidgets('the intent never enters the keyboard dictionary', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnosisApp());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
  });

  test('every skin: text inks meet WCAG 4.5:1 on background and surface; seal 3:1 on canvas', () {
    double lum(Color c) {
      double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }
    double ratio(Color a, Color b) {
      final la = lum(a), lb = lum(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }
    for (final id in SigilSkinId.values) {
      final s = SigilSkinTheme.getSkin(id);
      for (final ground in [s.background, s.surface]) {
        for (final ink in [s.inkPrimary, s.inkSecondary, s.inkTertiary]) {
          expect(ratio(ink, ground), greaterThanOrEqualTo(4.5), reason: '${id.name} text');
        }
        expect(ratio(s.accent, ground), greaterThanOrEqualTo(3.0), reason: '${id.name} accent');
      }
      expect(ratio(s.seal, s.canvasBackground), greaterThanOrEqualTo(3.0), reason: '${id.name} seal');
      // The burn button's icon (surface on inkPrimary) must be visible.
      expect(ratio(s.surface, s.inkPrimary), greaterThanOrEqualTo(3.0), reason: '${id.name} CTA icon');
    }
  });
}
