import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/motion/breath.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';
import 'package:ignosis_sigil_generator/src/ui/widgets/pen_ink_ritual_burn_dialog.dart';

void main() {
  test('the rite states its length to the nearest quarter minute', () {
    String of(BreathPattern p) => riteLengthLabel(p, 7);
    expect(of(BreathPattern.resonance), 'about 1¼ min');
    expect(of(BreathPattern.box), 'about 1¾ min');
    expect(of(BreathPattern.relax478), 'about 2¼ min');
  });

  testWidgets('the witness sits after the release, so it never reads as a step', (tester) async {
    final theme = SigilSkinTheme.getSkin(SigilSkinId.vellumDraft);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PenInkRitualBurnDialog(
          theme: theme,
          onBurnComplete: () {},
          witness: const Text('WITNESS-SLOT'),
        ),
      ),
    ));
    await tester.pump();
    final release = tester.getTopLeft(find.text('IV · RELEASE THE SEAL')).dy;
    final witness = tester.getTopLeft(find.text('WITNESS-SLOT')).dy;
    expect(witness, greaterThan(release));
    expect(find.text('You can release whenever you are ready.'), findsOneWidget);
  });
}
