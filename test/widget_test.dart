import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';
import 'package:ignosis_sigil_generator/src/models/revenue_schema.dart';
import 'package:ignosis_sigil_generator/src/models/sigil_state.dart';
import 'package:ignosis_sigil_generator/src/services/iap_service.dart';
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

  testWidgets('Circumlocution is the default system and comes first', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnosisApp());
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect(chips.first.selected, isTrue);
    expect(find.text('Circumlocution'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'I COMMAND RADIANT CLARITY');
    await tester.pump();
    expect(find.text('Drawn from'), findsOneWidget);
    expect(find.text('I · C · O · M · M · A · N · D · R · A · D · I · A · N · T · C · L · A · R · I · T · Y'),
        findsOneWidget);
  });

  testWidgets('the intent starts empty: an example seal, a helper, and no rite yet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('Example · write your own'), findsOneWidget);
    expect(find.text('Write your intent first'), findsOneWidget);
    final charge = find.widgetWithText(ElevatedButton, 'III · Charge the seal');
    expect(tester.widget<ElevatedButton>(charge).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'THIS MY WISH TO SLEEP');
    await tester.pump();
    expect(find.text('Example · write your own'), findsNothing);
    expect(find.text('Write your intent first'), findsNothing);
    expect(tester.widget<ElevatedButton>(charge).onPressed, isNotNull);
  });

  testWidgets('the four steps show on the first visit until dismissed, then live behind "?"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('The rite, in four steps'), findsOneWidget);
    Color? circumlocutionInk() => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Circumlocution')).labelStyle?.color;
    final accent = SigilSkinTheme.getSkin(SigilSkinId.vellumDraft).accent;
    expect(find.text('START HERE'), findsNothing);
    expect(find.text('I. Write what you will. Set your intention.'), findsOneWidget);
    expect(circumlocutionInk(), accent);
    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(find.text('The rite, in four steps'), findsNothing);
    expect(circumlocutionInk(), isNot(accent));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ignosis_intro_seen'), isTrue);
    await tester.tap(find.byTooltip('How it works'));
    await tester.pumpAndSettle();
    expect(find.text('The rite, in four steps'), findsOneWidget);
    expect(find.textContaining('IGNOSIS transforms intent into a sigil meant for consumption.'), findsOneWidget);
  });

  testWidgets('a returning visitor does not see the card', (tester) async {
    SharedPreferences.setMockInitialValues({'ignosis_intro_seen': true});
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('The rite, in four steps'), findsNothing);
    expect(find.text('I · Intent'), findsOneWidget);
    expect(find.text('II · System'), findsOneWidget);
  });

  testWidgets('the main page states what the selected system does and its ritual', (tester) async {
    SharedPreferences.setMockInitialValues({'ignosis_intro_seen': true});
    await tester.pumpWidget(const IgnosisApp());
    await tester.enterText(find.byType(TextField), 'I COMMAND RADIANT CLARITY');
    await tester.pump();
    expect(find.text(SigilSystem.ringCipher.howTo), findsOneWidget);
    expect(find.text(SigilSystem.ringCipher.ritual), findsOneWidget);
    // Choosing another ritual changes the line under the chips.
    final chip = find.widgetWithText(ChoiceChip, 'Cyber Chaos');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(SigilSystem.cyberChaos.ritual), findsOneWidget);
    expect(find.text(SigilSystem.ringCipher.ritual), findsNothing);
    // Every system has its own line.
    expect(SigilSystem.values.map((s) => s.ritual).toSet(), hasLength(SigilSystem.values.length));
    expect(SigilSystem.values.map((s) => s.howTo).toSet(), hasLength(SigilSystem.values.length));
    // Both stay through the rite; only the spelled-out kernel is hidden then.
    expect(find.text('Drawn from'), findsOneWidget);
    await tester.tap(find.text('III · Charge the seal'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(SigilSystem.cyberChaos.howTo), findsOneWidget);
    expect(find.text(SigilSystem.cyberChaos.ritual), findsOneWidget);
    expect(find.text('Drawn from'), findsNothing);
    // The rite says what to do and how long it takes; the breath patterns are folded.
    expect(find.textContaining('Seven breaths, about 1¼ min. Then release.'), findsOneWidget);
    expect(find.text('Box'), findsNothing);
    await tester.tap(find.text('Change the breath · Slow paced'));
    await tester.pump();
    expect(find.text('Box'), findsOneWidget);
    expect(find.text('Release the seal'), findsOneWidget);
  });

  testWidgets('the intent field has a name, and the step labels are headings', (tester) async {
    SharedPreferences.setMockInitialValues({'ignosis_intro_seen': true});
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getSemantics(find.byType(TextField)).label, contains('Intent'));
    expect(find.bySemanticsLabel(RegExp('I · Intent')), findsOneWidget);
    final heading = tester.getSemantics(find.text('II · System'));
    expect(heading.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  testWidgets('a wide window keeps the studio to a readable measure; the bar spans it', (tester) async {
    SharedPreferences.setMockInitialValues({'ignosis_intro_seen': true});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getSize(find.byType(TextField)).width, lessThanOrEqualTo(720));
    final field = tester.getRect(find.byType(TextField));
    expect(field.center.dx, closeTo(720, 1));
    final charge = tester.getRect(find.widgetWithText(ElevatedButton, 'III · Charge the seal'));
    expect(charge.right, closeTo(field.right, 1), reason: 'the bar aligns with the studio');
  });

  testWidgets('the first visit shows the steps and the example together', (tester) async {
    // The test font is wider than any real one, so the smallest phones are
    // checked with real fonts in test/visual/studio_screenshot_test.dart.
    for (final size in const [Size(390, 844), Size(412, 915), Size(430, 932)]) {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const IgnosisApp());
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      expect(error, isNull, reason: 'at $size: $error');
      expect(find.text('The rite, in four steps'), findsOneWidget);
      expect(find.text('Example · write your own'), findsOneWidget);
      if (size.height >= 700) {
        // The card sits above the plate, not over it.
        final card = tester.getRect(find.text('The rite, in four steps'));
        final example = tester.getRect(find.text('Example · write your own'));
        expect(card.bottom, lessThan(example.top));
      }
    }
  });

  testWidgets('"Free and paid" sells no skin while skins are free', (tester) async {
    IapService.instance.resetForTest();
    SharedPreferences.setMockInitialValues({'ignosis_intro_seen': true});
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Skins'), findsNothing, reason: 'one entry, not two');
    await tester.tap(find.text('Free and paid'));
    await tester.pumpAndSettle();
    expect(find.text('Free for now'), findsOneWidget);
    expect(find.textContaining('Unlock'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
  });

  testWidgets('every skin is free while none are sold', (tester) async {
    IapService.instance.resetForTest();
    SharedPreferences.setMockInitialValues({'ignosis_selected_skin': 'chaos'});
    expect(IapService.instance.sellSkins, isFalse);
    expect(SigilSkinId.values.every((s) => IapService.instance.isSkinUnlocked(s.key)), isTrue);
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Chaos'), findsOneWidget, reason: 'a saved premium skin is restored without a purchase');
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    expect(find.text('All skins are free for now'), findsOneWidget);
    expect(find.text('Restore purchases'), findsNothing);
    expect(find.textContaining('Unlock'), findsNothing);
  });

  testWidgets('a saved premium skin is not applied without an entitlement', (tester) async {
    IapService.instance.resetForTest();
    IapService.instance.sellSkins = true;
    SharedPreferences.setMockInitialValues({'ignosis_selected_skin': 'chaos'});
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Vellum & Ink'), findsOneWidget);
    expect(find.text('Chaos'), findsNothing);
  });

  testWidgets('an entitled saved skin is restored on launch', (tester) async {
    IapService.instance.resetForTest();
    IapService.instance.sellSkins = true;
    SharedPreferences.setMockInitialValues({
      'ignosis_selected_skin': 'chaos',
      'ignosis_unlocked_skins': [RevenueSchemaConfig.skinChaosId],
    });
    // Real async: the store probe and preferences are platform calls.
    await tester.runAsync(() => IapService.instance.initialize().timeout(const Duration(seconds: 5)));
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Chaos'), findsOneWidget);
  });

  testWidgets('tapping a locked skin previews it and buys nothing', (tester) async {
    IapService.instance.resetForTest();
    IapService.instance.sellSkins = true;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IgnosisApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cosmic'));
    await tester.pump();
    // An explicit unlock button appears; the skin is not applied or bought.
    expect(find.textContaining('Unlock Cosmic'), findsOneWidget);
    expect(IapService.instance.isSkinUnlocked('cosmic'), isFalse);
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
