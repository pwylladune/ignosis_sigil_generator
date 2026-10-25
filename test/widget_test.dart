import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';
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
}
