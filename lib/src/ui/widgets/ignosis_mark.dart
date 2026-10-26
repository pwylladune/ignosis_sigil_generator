import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../engines/cyber_chaos_engine.dart';
import '../../engines/ring_cipher_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../models/intent_kernel.dart';
import '../canvas/brush.dart';
import '../canvas/scene.dart';
import '../theme/sigil_skins.dart';

/// The IGNOSIS mark, "Rise In Power": the Cyber Chaos attractor of
/// "Michael Roland" with two-fold symmetry, inside the Circumlocution walk of
/// "Rise In Power", painted with the studio's sumi-e brush (see brand/README.md).
/// The app icons and the title mark are both drawn by [paintIgnosisMark].
class IgnosisMark extends StatelessWidget {
  const IgnosisMark({super.key, required this.skin, this.size = 32, this.semanticLabel});

  final SigilSkinTheme skin;
  final double size;

  /// Read by screen readers; null when the mark is decorative (next to the
  /// word IGNOSIS, say).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = RepaintBoundary(
      child: CustomPaint(size: Size.square(size), painter: _IgnosisMarkPainter(skin)),
    );
    final label = semanticLabel;
    return label == null ? ExcludeSemantics(child: mark) : Semantics(label: label, image: true, child: mark);
  }
}

class _IgnosisMarkPainter extends CustomPainter {
  _IgnosisMarkPainter(this.skin);

  final SigilSkinTheme skin;

  @override
  void paint(Canvas canvas, Size size) {
    // Small marks drop the faint construction and keep the seal visible.
    final small = size.shortestSide < 96;
    paintIgnosisMark(canvas, size.shortestSide, skin, guides: !small, minSealPixels: small ? 1.2 : 0);
  }

  @override
  bool shouldRepaint(covariant _IgnosisMarkPainter old) => old.skin != skin;
}

const _ref = 512.0;
const _centre = Offset(_ref / 2, _ref / 2);

/// Brush width = skin stroke ÷ this × 4.2, in reference units: a broad brush.
const _brushScale = 0.8;
const _inner = 98.0, _outer = 242.0;

Float32List? _points;
List<SigilStroke>? _arcs;

/// The two-fold Cyber Chaos attractor of the name, fitted inside [radius].
Float32List _attractor(String name, double radius) {
  // The engine fits the orbit to 0.40 of its canvas: size it so that is [radius].
  final side = radius / 0.40;
  final sigil = CyberChaosEngine().build(IntentKernel.fromText(name), Size(side, side), symmetryFolds: 2);
  final out = Float32List.fromList(sigil.points);
  for (var i = 0; i < out.length; i += 2) {
    out[i] += _centre.dx - side / 2;
    out[i + 1] += _centre.dy - side / 2;
  }
  return out;
}

/// The Circumlocution walk of [phrase] on rings from [inner] to [outer].
List<SigilStroke> _circumlocution(String phrase, double inner, double outer) {
  final arcs = RingCipherEngine.arcsFor(RingCipherEngine.cipherText(phrase));
  final spacing = (outer - inner) / arcs.length;
  return [
    for (final a in arcs)
      SigilStroke(Path()
        ..addArc(Rect.fromCircle(center: _centre, radius: inner + (a.ring + 0.5) * spacing),
            RingCipherEngine.spokeAngle(a.from), a.sweep == 0 ? RingCipherEngine.step * 0.36 : a.sweep)),
  ];
}

/// Paints the mark into a [pixels]-wide square at the canvas origin, in
/// [skin]'s ink. [paper] fills the square with the skin's paper (the app
/// icons); [content] shrinks the drawing within it (0.78 keeps it inside the
/// safe zone of round launcher and maskable masks); [guides] draws the wheel's
/// faint rim and spokes; [minSealPixels] keeps the seal visible when small.
void paintIgnosisMark(
  Canvas canvas,
  double pixels,
  SigilSkinTheme skin, {
  bool paper = false,
  bool guides = true,
  double content = 1,
  double minSealPixels = 0,
}) {
  final scale = pixels / _ref;
  final style = SceneStyle.fromSkin(skin, scale: _brushScale);
  canvas.save();
  canvas.scale(scale);
  if (paper) canvas.drawRect(const Rect.fromLTWH(0, 0, _ref, _ref), Paint()..color = style.paper);
  canvas
    ..translate(_centre.dx, _centre.dy)
    ..scale(content)
    ..translate(-_centre.dx, -_centre.dy);

  // The wheel's faint construction: the rim and the 28 spokes between the bands.
  if (guides) {
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = style.guide;
    canvas.drawCircle(_centre, _outer + 10, guide);
    for (var i = 0; i < RingCipherEngine.spokeCount; i++) {
      final a = RingCipherEngine.spokeAngle(i);
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(_centre + d * (_inner - 4), _centre + d * (_outer + 10), guide);
    }
  }

  // The attractor, as ink soaking into paper.
  canvas.drawRawPoints(
    ui.PointMode.points,
    _points ??= _attractor('Michael Roland', 86),
    Paint()
      ..color = style.ink.withValues(alpha: 0.2)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round,
  );

  // The phrase, walked ring by ring with the brush.
  final strokes = _arcs ??= _circumlocution('Rise In Power', _inner, _outer);
  paintBrushStrokes(canvas, style, strokes, List.filled(strokes.length, 1.0), seed: 1618);

  // The vermilion seal.
  canvas.drawCircle(_centre, math.max(7, minSealPixels / (scale * content)), Paint()..color = style.seal);
  canvas.restore();
}
