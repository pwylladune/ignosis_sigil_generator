import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/models/compendium.dart';
import 'package:ignosis_sigil_generator/src/ui/screens/compendium_screen.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';

void main() {
  final c = Compendium.parse(File(Compendium.asset).readAsStringSync());
  final theme = SigilSkinTheme.getSkin(SigilSkinId.vellumDraft);

  test('the compendium is quotations only, each cited and linked', () {
    expect(c.parts, hasLength(9));
    expect(c.quoteCount, greaterThan(250));
    for (final p in c.parts) {
      for (final s in p.sections) {
        for (final q in s.quotes) {
          expect(q.text.trim(), isNotEmpty);
          expect(q.author, isNotEmpty, reason: q.text);
          expect(q.work, isNotEmpty, reason: q.text);
          expect(q.sourceUrl ?? q.learnMoreUrl, isNotNull, reason: q.text);
        }
      }
    }
    expect(c.glossary, isNotEmpty);
    for (final t in c.glossary) {
      expect(t.quotes, isNotEmpty, reason: t.term);
    }
    for (final a in c.authors) {
      expect(Uri.parse(a.website).hasScheme, isTrue, reason: a.name);
    }
  });

  testWidgets('the home lists the nine parts and the reference pages', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CompendiumScreen(theme: theme, compendium: c)));
    expect(find.text('THE COMPENDIUM'), findsOneWidget);
    expect(find.text(c.parts.first.title), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Authors and websites'), 200);
    expect(find.text('Glossary'), findsOneWidget);
  });

  testWidgets('a part opens to its quotations with their citations', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CompendiumScreen(theme: theme, compendium: c)));
    await tester.tap(find.text(c.parts.first.title));
    await tester.pumpAndSettle();
    final q = c.parts.first.sections.first.quotes.first;
    expect(find.text('“${q.text.trim()}”'), findsOneWidget);
    expect(find.textContaining(q.work), findsWidgets);
    expect(find.text('Source'), findsWidgets);
  });
}
