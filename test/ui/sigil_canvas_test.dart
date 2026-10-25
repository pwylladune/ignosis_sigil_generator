import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/kamea_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/models/sigil_state.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_canvas.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_spec.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';

SigilSpec spec(String intent, SigilSystem system) => SigilSpec(
      kernel: IntentKernel.fromText(intent),
      system: system,
      kameaType: PlanetaryKameaType.sol,
      symmetryFolds: 4,
      symmetryGroup: SymmetryGroup.cyclic,
    );

Widget host(SigilSpec s, SigilBurnController burn, VoidCallback onDone, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduceMotion),
        child: Center(
          child: SizedBox.square(
            dimension: 320,
            child: SigilCanvas(
              spec: s,
              skin: SigilSkinTheme.getSkin(SigilSkinId.vellumDraft),
              burn: burn,
              onIncinerated: onDone,
            ),
          ),
        ),
      ),
    );

void main() {
  for (final system in SigilSystem.values) {
    testWidgets('${system.name}: writes, settles and stops the clock', (tester) async {
      final burn = SigilBurnController();
      await tester.pumpWidget(host(spec('I COMMAND RADIANT CLARITY', system), burn, () {}));
      expect(tester.hasRunningAnimations, isTrue);
      // pumpAndSettle only returns once no frames are scheduled: idle = no ticker.
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('${system.name}: burn completes and reports incineration', (tester) async {
      final burn = SigilBurnController();
      var done = false;
      await tester.pumpWidget(host(spec('PROTECTION AND FORCE', system), burn, () => done = true));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      burn.ignite();
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      expect(done, isTrue);
    });
  }

  testWidgets('reduce motion: settled immediately', (tester) async {
    final burn = SigilBurnController();
    await tester.pumpWidget(host(spec('FOCUS', SigilSystem.spare), burn, () {}, reduceMotion: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
