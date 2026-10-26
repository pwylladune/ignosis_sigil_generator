@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/kamea_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/models/sigil_state.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_canvas.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_spec.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';

/// Settled seals for fixed intents. Regenerate on macOS with:
///   flutter test --tags golden --update-goldens
void main() {
  const intent = 'I COMMAND RADIANT CLARITY';
  final cases = <(String, SigilSystem, SymmetryGroup, int, bool)>[
    ('spare_c4', SigilSystem.spare, SymmetryGroup.cyclic, 4, false),
    ('spare_d5', SigilSystem.spare, SymmetryGroup.dihedral, 5, false),
    ('kamea_sol', SigilSystem.kamea, SymmetryGroup.cyclic, 4, false),
    ('rose_cross', SigilSystem.roseCross, SymmetryGroup.cyclic, 4, false),
    ('chladni', SigilSystem.chladni, SymmetryGroup.cyclic, 4, false),
    ('cyber_chaos_c4', SigilSystem.cyberChaos, SymmetryGroup.cyclic, 4, false),
    ('ring_cipher', SigilSystem.ringCipher, SymmetryGroup.cyclic, 4, false),
    ('infinite', SigilSystem.infinite, SymmetryGroup.cyclic, 4, false),
    ('infinite_inverted', SigilSystem.infinite, SymmetryGroup.cyclic, 4, true),
  ];

  for (final (name, system, group, folds, inverted) in cases) {
    testWidgets('golden: $name', (tester) async {
      tester.view.physicalSize = const Size(360, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final skin = SigilSkinTheme.getSkin(SigilSkinId.vellumDraft);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: skin.canvasBackground,
          child: RepaintBoundary(
            child: SigilCanvas(
              spec: SigilSpec(
                kernel: IntentKernel.fromText(intent),
                system: system,
                kameaType: PlanetaryKameaType.sol,
                symmetryFolds: folds,
                symmetryGroup: group,
                inverted: inverted,
              ),
              skin: skin,
              burn: SigilBurnController(),
              onIncinerated: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      await expectLater(find.byType(SigilCanvas), matchesGoldenFile('goldens/$name.png'));
    });
  }
}
