import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';
import 'package:ignosis_sigil_generator/src/ui/screens/compendium_screen.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';
import 'package:ignosis_sigil_generator/src/ui/widgets/ritual_exegesis_modal.dart';
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

  testWidgets('the Exegesis dialog and the Compendium carry the mark, and no glyph', (tester) async {
    final theme = SigilSkinTheme.getSkin(SigilSkinId.vellumDraft);
    for (final page in <Widget>[RitualExegesisModal(theme: theme), CompendiumScreen(theme: theme)]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      expect(find.byType(IgnosisMark), findsOneWidget, reason: page.runtimeType.toString());
      expect(find.text('🜂'), findsNothing, reason: page.runtimeType.toString());
    }
  });
}
