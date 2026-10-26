import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/infinite_engine.dart';
import 'package:ignosis_sigil_generator/src/engines/kamea_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/models/sigil_state.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_canvas.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_spec.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';

void main() {
  final kernel = IntentKernel.fromText('I COMMAND RADIANT CLARITY');
  SigilSpec spec({InfiniteView? view, SigilSystem system = SigilSystem.infinite}) => SigilSpec(
        kernel: kernel,
        system: system,
        kameaType: PlanetaryKameaType.sol,
        symmetryFolds: 4,
        symmetryGroup: SymmetryGroup.cyclic,
        view: view,
      );

  /// A 512×512 canvas, so widget and reference coordinates coincide.
  Future<List<InfiniteView?>> pumpCanvas(WidgetTester tester, {SigilSystem system = SigilSystem.infinite}) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reported = <InfiniteView?>[];
    await tester.pumpWidget(MaterialApp(
      home: SigilCanvas(
        spec: spec(system: system),
        skin: SigilSkinTheme.getSkin(SigilSkinId.vellumDraft),
        burn: SigilBurnController(),
        onIncinerated: () {},
        onViewChanged: reported.add,
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    return reported;
  }

  testWidgets('a double tap zooms ×2 onto the point tapped', (tester) async {
    final reported = await pumpCanvas(tester);
    final home = JuliaParams.fromKernel(kernel).home;
    const at = Offset(300, 200);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(reported, hasLength(1));
    final v = reported.single!;
    expect(v.halfWidth, closeTo(home.halfWidth / 2, 1e-12));
    // Zooming ×2 about a point keeps that point fixed, so the new centre is
    // halfway between the old centre and the point tapped.
    final (re, im) = InfiniteEngine.toComplex(const Offset(278, 228), home, const Offset(256, 256), 512 * 0.44);
    expect(v.cx, closeTo(re, 1e-9));
    expect(v.cy, closeTo(im, 1e-9));
  });

  testWidgets('scrolling zooms, and backing out past the whole set returns home', (tester) async {
    final reported = await pumpCanvas(tester);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(256, 256)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -400)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(reported.last!.halfWidth, lessThan(JuliaParams.fromKernel(kernel).homeHalfWidth));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 1200)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(reported.last, isNull, reason: 'zoomed out beyond the whole set: home');
  });

  testWidgets('other systems do not zoom', (tester) async {
    final reported = await pumpCanvas(tester, system: SigilSystem.ringCipher);
    await tester.tapAt(const Offset(300, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(300, 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(reported, isEmpty);
  });

  test('a new window differs only in view; a new intent does not', () {
    const v = InfiniteView(0.1, 0.2, 0.3);
    expect(spec(view: v).differsOnlyInView(spec()), isTrue);
    expect(spec(view: v) == spec(), isFalse);
    expect(spec().differsOnlyInView(spec()), isFalse);
  });
}
