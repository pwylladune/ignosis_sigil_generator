import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engines/rose_cross_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../models/intent_kernel.dart';
import '../../motion/ductus.dart';
import '../../motion/easing.dart';
import 'scene.dart';

/// Astrolabe lock: the three rings counter-rotate at angular speeds in the
/// ratio 3 : 7 : 12 while the sigil is drawn between the moving petals, and
/// they ease into alignment (phase-locked, like a cryptex) as the last stroke
/// lands. Then stillness.
class RoseScene extends SigilScene {
  RoseScene(this.kernel, this.size, this.sigil, {required super.startTime}) : timeline = DuctusTimeline(sigil.geometry);

  final IntentKernel kernel;
  final Size size;

  /// The locked (rest) sigil.
  final RoseSigil sigil;
  final DuctusTimeline timeline;

  /// Base offset in radians; ring k starts `ratio_k · base` away from rest.
  static const _base = math.pi / 20;
  static const _directions = [1.0, -1.0, 1.0];

  @override
  SigilGeometry get geometry => sigil.geometry;

  @override
  bool get ownsGuides => true;

  @override
  double get settleTime => timeline.duration;

  /// Ring rotations at [t]: (1 − s(t/T)) times the starting offset, so their
  /// angular speeds stay in the 3 : 7 : 12 ratio and all reach zero together.
  List<double> ringRotation(double t) {
    final remaining = 1 - minimumJerk(timeline.duration <= 0 ? 1 : t / timeline.duration);
    return [for (var k = 0; k < 3; k++) _directions[k] * RoseCrossEngine.ringRatios[k] * _base * remaining];
  }

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final t = now - startTime;
    final settled = t >= timeline.duration;
    final rotation = settled ? const [0.0, 0.0, 0.0] : ringRotation(t);
    final c = sigil.center, r = sigil.radius;

    // The rose: ring circles and a petal mark with its letter for every petal.
    final guide = style.guidePaint();
    for (final f in RoseCrossEngine.ringRadii) {
      canvas.drawCircle(c, r * f, guide);
    }
    final visited = sigil.petals.toSet();
    for (final petal in RoseCrossEngine.allPetals) {
      final p = RoseCrossEngine.petalPosition(petal, c, r, rotation);
      final dir = (p - c) / (p - c).distance;
      final isVisited = visited.contains(petal);
      canvas.drawLine(p - dir * 4, p + dir * 4, style.guidePaint(width: isVisited ? 1.4 : 1));
      _drawGlyph(canvas, petal.letter.glyph, p + dir * 13, isVisited ? style.muted : style.muted.withValues(alpha: 0.45));
    }

    // Ink: rebuilt between the moving petals while writing, static once locked.
    final current = settled ? sigil : RoseCrossEngine().build(kernel, size, ringRotation: rotation);
    final path = settled ? current.geometry.path : current.geometry.reveal(timeline.fractionsAt(t));
    style.drawInk(canvas, path);
  }

  static final _glyphs = <(String, int), TextPainter>{};

  static void _drawGlyph(Canvas canvas, String glyph, Offset at, Color color) {
    final tp = _glyphs[(glyph, color.toARGB32())] ??= TextPainter(
      text: TextSpan(text: glyph, style: TextStyle(fontSize: 9, color: color)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }
}
