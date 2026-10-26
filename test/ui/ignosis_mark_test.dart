import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';
import 'package:ignosis_sigil_generator/src/ui/widgets/ignosis_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the title shows the IGNOSIS mark, not a glyph', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const IgnosisApp());
    final bar = find.byType(AppBar);
    expect(find.descendant(of: bar, matching: find.byType(IgnosisMark)), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('🜂')), findsNothing);
    expect(find.descendant(of: bar, matching: find.text('IGNOSIS')), findsOneWidget);
    // Decorative beside the word: the title is read once, not twice.
    expect(find.bySemanticsLabel('IGNOSIS'), findsOneWidget);
    semantics.dispose();
  });
}
