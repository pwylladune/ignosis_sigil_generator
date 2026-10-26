// Renders the "Rise In Power" icon: the Cyber Chaos attractor of
// "Michael Roland" with two-fold symmetry, inside the Circumlocution walk of
// "Rise In Power", painted with the studio's sumi-e brush.
//
//   flutter test brand/rise_in_power_icon_test.dart
//
// Writes brand/rise_in_power_icon.png (1024 px) and brand/rise_in_power_icon_dark.png.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/engines/cyber_chaos_engine.dart';
import 'package:ignosis_sigil_generator/src/engines/ring_cipher_engine.dart';
import 'package:ignosis_sigil_generator/src/geometry/sigil_geometry.dart';
import 'package:ignosis_sigil_generator/src/models/intent_kernel.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/brush.dart';
import 'package:ignosis_sigil_generator/src/ui/canvas/scene.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';

const ref = 512.0;
const brushScale = 0.8;
const centre = Offset(ref / 2, ref / 2);

/// The two-fold Cyber Chaos attractor of the name, fitted inside [radius].
Float32List attractor(String name, double radius) {
  // The engine fits the orbit to 0.40 of its canvas: size it so that is [radius].
  final side = radius / 0.40;
  final sigil = CyberChaosEngine().build(IntentKernel.fromText(name), Size(side, side), symmetryFolds: 2);
  final out = Float32List.fromList(sigil.points);
  for (var i = 0; i < out.length; i += 2) {
    out[i] += centre.dx - side / 2;
    out[i + 1] += centre.dy - side / 2;
  }
  return out;
}

/// The Circumlocution walk of [phrase] on rings from [inner] to [outer].
List<SigilStroke> circumlocution(String phrase, double inner, double outer) {
  final arcs = RingCipherEngine.arcsFor(RingCipherEngine.cipherText(phrase));
  final spacing = (outer - inner) / arcs.length;
  return [
    for (final a in arcs)
      SigilStroke(Path()
        ..addArc(Rect.fromCircle(center: centre, radius: inner + (a.ring + 0.5) * spacing),
            RingCipherEngine.spokeAngle(a.from), a.sweep == 0 ? RingCipherEngine.step * 0.36 : a.sweep)),
  ];
}

/// [content] shrinks the drawing inside the paper: 1 fills it; 0.78 keeps it in
/// the safe zone of Android launcher and PWA "maskable" masks.
Future<void> render(String file, SigilSkinTheme skin, {int pixels = 1024, double content = 1}) async {
  final scale = pixels / ref;
  // A broad brush: brush width = skin stroke ÷ [brushScale] × 4.2, in ref units.
  final style = SceneStyle.fromSkin(skin, scale: brushScale);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  canvas.drawRect(const Rect.fromLTWH(0, 0, ref, ref), Paint()..color = style.paper);
  canvas
    ..translate(centre.dx, centre.dy)
    ..scale(content)
    ..translate(-centre.dx, -centre.dy);

  // The wheel's faint construction: the rim and the 28 spokes between the bands.
  const inner = 98.0, outer = 242.0;
  final guide = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..color = style.guide;
  canvas.drawCircle(centre, outer + 10, guide);
  for (var i = 0; i < RingCipherEngine.spokeCount; i++) {
    final a = RingCipherEngine.spokeAngle(i);
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(centre + d * (inner - 4), centre + d * (outer + 10), guide);
  }

  // The attractor, as ink soaking into paper.
  final pts = attractor('Michael Roland', 86);
  canvas.drawRawPoints(
    ui.PointMode.points,
    pts,
    Paint()
      ..color = style.ink.withValues(alpha: 0.2)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round,
  );

  // The phrase, walked ring by ring with the brush.
  final strokes = circumlocution('Rise In Power', inner, outer);
  paintBrushStrokes(canvas, style, strokes, List.filled(strokes.length, 1.0), seed: 1618);

  // The vermilion seal.
  canvas.drawCircle(centre, 7, Paint()..color = style.seal);

  final image = await recorder.endRecording().toImage(pixels, pixels);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(file).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render the Rise In Power icon', (tester) async {
    await tester.runAsync(() async {
      await render('brand/rise_in_power_icon.png', SigilSkinTheme.getSkin(SigilSkinId.vellumDraft));
      await render('brand/rise_in_power_icon_dark.png', SigilSkinTheme.getSkin(SigilSkinId.chaos));
      // App-icon masters: full bleed (iOS, web), and the safe zone (Android, maskable).
      await render('brand/app_icon_1024.png', SigilSkinTheme.getSkin(SigilSkinId.vellumDraft));
      await render('brand/app_icon_safe_1024.png', SigilSkinTheme.getSkin(SigilSkinId.vellumDraft), content: 0.78);
    });
  });
}
