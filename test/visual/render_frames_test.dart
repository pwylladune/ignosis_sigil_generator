@Tags(['visual'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/kamea_engine.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/models/sigil_state.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_canvas.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/sigil_spec.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';

/// Renders preview frames of every engine through its motion, for review.
///
///   VISUAL_OUT=build/visual flutter test --tags visual --run-skipped
Future<void> _loadFont() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final file = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  for (final family in ['Roboto', 'FlutterTest']) {
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  final out = Platform.environment['VISUAL_OUT'] ?? 'build/visual';
  final intent = Platform.environment['VISUAL_INTENT'] ?? 'I COMMAND RADIANT CLARITY';
  final skinName = Platform.environment['VISUAL_SKIN'] ?? 'vellumDraft';
  final skin = SigilSkinTheme.getSkin(SigilSkinId.values.byName(skinName));
  final times = (Platform.environment['VISUAL_TIMES'] ?? '0.4,1.2,2.5,4,8').split(',').map(double.parse).toList();
  final systems = (Platform.environment['VISUAL_SYSTEMS']?.split(',').map(SigilSystem.values.byName) ?? SigilSystem.values).toList();
  final burnAt = Platform.environment['VISUAL_BURN'];

  setUpAll(_loadFont);

  for (final system in systems) {
    testWidgets('frames: ${system.name}', (tester) async {
      final px = double.parse(Platform.environment['VISUAL_PX'] ?? '520');
      tester.view.physicalSize = Size(px, px);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      final burn = SigilBurnController();
      final spec = SigilSpec(
        kernel: IntentKernel.fromText(intent),
        system: system,
        kameaType: PlanetaryKameaType.values.byName(Platform.environment['VISUAL_PLANET'] ?? 'sol'),
        symmetryFolds: int.parse(Platform.environment['VISUAL_FOLDS'] ?? '4'),
        symmetryGroup: SymmetryGroup.values.byName(Platform.environment['VISUAL_GROUP'] ?? 'cyclic'),
      );
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: skin.canvasBackground,
          body: RepaintBoundary(
            key: key,
            child: Container(
              color: skin.canvasBackground,
              child: SigilCanvas(spec: spec, skin: skin, burn: burn, onIncinerated: () {}),
            ),
          ),
        ),
      ));
      Directory(out).createSync(recursive: true);
      var elapsed = 0.0;
      final allTimes = [...times];
      final burnStart = burnAt == null ? null : double.parse(burnAt);
      if (burnStart != null) {
        allTimes.addAll([0.6, 1.4, 2.2, 3.0, 3.8].map((d) => burnStart + d));
      }
      for (final t in allTimes) {
        if (burnStart != null && elapsed < burnStart && t >= burnStart) {
          await tester.pump(Duration(microseconds: ((burnStart - elapsed) * 1e6).round()));
          elapsed = burnStart;
          burn.ignite();
          await tester.pump();
        }
        // Step in frames so per-frame simulations advance as on a device.
        while (elapsed < t) {
          final step = (t - elapsed).clamp(0.0, 1 / 60);
          await tester.pump(Duration(microseconds: (step * 1e6).round()));
          elapsed += step;
        }
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/${system.name}_${t.toStringAsFixed(1).padLeft(4, '0')}s.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
