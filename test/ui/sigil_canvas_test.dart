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

Widget host(SigilSpec s, SigilBurnController burn, VoidCallback onDone, {bool reduceMotion = false, double side = 320}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduceMotion),
        child: Center(
          child: SizedBox.square(
            dimension: side,
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

  testWidgets('a burn is not cancelled by a change of system or intent', (tester) async {
    final burn = SigilBurnController();
    var done = 0;
    await tester.pumpWidget(host(spec('FOCUS', SigilSystem.spare), burn, () => done++));
    await tester.pumpAndSettle();
    burn.ignite();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(host(spec('FOCUS', SigilSystem.kamea), burn, () => done++));
    await tester.pumpWidget(host(spec('OTHER', SigilSystem.kamea), burn, () => done++));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    expect(done, 1);
  });

  testWidgets('resizing rescales without rebuilding or replaying', (tester) async {
    final burn = SigilBurnController();
    await tester.pumpWidget(host(spec('CHAOS AND HARMONY', SigilSystem.chladni), burn, () {}));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    for (final side in [300.0, 250.0, 200.0, 0.0, 320.0]) {
      await tester.pumpWidget(host(spec('CHAOS AND HARMONY', SigilSystem.chladni), burn, () {}, side: side));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse, reason: 'side $side');
    }
  });

  testWidgets('a burn started while a keystroke is still debouncing completes', (tester) async {
    final burn = SigilBurnController();
    var done = 0;
    await tester.pumpWidget(host(spec('FOCUS', SigilSystem.spare), burn, () => done++));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(spec('FOCUSED', SigilSystem.spare), burn, () => done++));
    await tester.pump(const Duration(milliseconds: 100)); // debounce still pending
    burn.ignite();
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    expect(done, 1);
  });

  testWidgets('iOS Reduce Motion (accessibility feature, not MediaQuery) is honoured', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final burn = SigilBurnController();
    await tester.pumpWidget(host(spec('FOCUS', SigilSystem.kamea), burn, () {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('settled offscreen render paints the paper (dark skins export visibly)', (tester) async {
    final skin = SigilSkinTheme.getSkin(SigilSkinId.chaos);
    final image = await tester.runAsync(() => renderSettledSeal(spec('FOCUS', SigilSystem.spare), skin, pixels: 64));
    final bytes = await tester.runAsync(() => image!.toByteData());
    // Centre pixel is the bind point; a pixel near the rim is paper, not transparent.
    const i = (32 * 64 + 4) * 4;
    expect(bytes!.getUint8(i + 3), 255);
    image!.dispose();
  });
}
