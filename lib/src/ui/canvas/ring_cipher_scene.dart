import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engines/ring_cipher_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/ductus.dart';
import 'scene.dart';

/// Ring Cipher: the pen fills each band at constant speed from one letter's
/// spoke to the next, then steps out a ring and carries on, so the phrase is
/// written outward from the hub. Then stillness.
class RingCipherScene extends SigilScene {
  RingCipherScene(this.sigil, {required super.startTime}) : timeline = DuctusTimeline(sigil.geometry, penSpeed: 420);

  final RingCipherSigil sigil;
  final DuctusTimeline timeline;

  @override
  SigilGeometry get geometry => sigil.geometry;

  @override
  bool get ownsGuides => true;

  @override
  double get settleTime => timeline.duration;

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final c = sigil.center;
    final guide = style.guidePaint(width: 0.6);

    // The wheel: concentric rings at band spacing out to the rim, and the
    // 28 labelled spokes.
    for (var r = sigil.innerRadius; r <= sigil.outerRadius + 0.01; r += sigil.spacing) {
      canvas.drawCircle(c, r, guide);
    }
    canvas.drawCircle(c, sigil.outerRadius, style.guidePaint());
    style.paintLettering(canvas, () {
      for (var i = 0; i < RingCipherEngine.spokeCount; i++) {
        final a = RingCipherEngine.spokeAngle(i);
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * (sigil.innerRadius * 0.4), c + d * (sigil.outerRadius + style.px(6)), guide);
        _drawLabel(canvas, RingCipherEngine.alphabet[i], c + d * (sigil.outerRadius + style.px(16)), style.px(11),
            style.muted);
      }
    });

    // The bands, written inner to outer.
    final t = now - startTime;
    final fractions = timeline.fractionsAt(t);
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = sigil.bandWidth
      ..color = style.ink.withValues(alpha: style.ink.a * 0.94);
    final wash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = sigil.bandWidth + style.px(1.2)
      ..color = style.ink.withValues(alpha: style.washOpacity * 1.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, style.px(0.8));
    final strokes = geometry.strokes;
    for (var i = 0; i < strokes.length; i++) {
      if (fractions[i] <= 0) continue;
      final p = strokes[i].partial(fractions[i]);
      canvas.drawPath(p, wash);
      canvas.drawPath(p, band);
    }
  }

  @override
  void paintUnwritten(Canvas canvas, Size size, double inkLength, SceneStyle style) {
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = sigil.bandWidth
      ..color = style.ink;
    canvas.drawPath(geometry.revealLength(inkLength), band);
  }

  static final _labels = <(String, double, int), TextPainter>{};

  static void _drawLabel(Canvas canvas, String text, Offset at, double size, Color color) {
    if (_labels.isEmpty) onSystemFontsChanged(_labels.clear);
    final tp = _labels[(text, size, color.toARGB32())] ??= TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }
}
