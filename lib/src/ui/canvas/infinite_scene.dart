import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Picture, PictureRecorder, PointMode;
import 'package:flutter/material.dart';
import '../../engines/infinite_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/ductus.dart';
import '../../motion/easing.dart';
import 'scene.dart';

/// The Infinite. Forward: the rings are written from the outside in, each
/// a little finer, as the pen closes on a boundary it never reaches.
/// Inverted: the square roots unfold the set, depth by depth. Then stillness.
class InfiniteScene extends SigilScene {
  InfiniteScene(this.sigil, {required super.startTime})
      : timeline = DuctusTimeline(
          sigil.geometry,
          // However long the rings are, they are written in a few seconds:
          // the curves lengthen without limit as they near the set.
          penSpeed: math.max(340, sigil.geometry.totalLength / 6),
          minStrokeDuration: 0.05,
          liftPause: 0.04,
        );

  final InfiniteSigil sigil;
  final DuctusTimeline timeline;

  static const _unfolding = 4.0;

  ui.Picture? _settled;
  (int, double)? _settledKey;

  @override
  SigilGeometry get geometry => sigil.geometry;

  @override
  bool get ownsGuides => true;

  @override
  double get settleTime => sigil.inverted ? (sigil.pointCount == 0 ? 0 : _unfolding) : timeline.duration;

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final t = now - startTime;
    if (sigil.inverted) {
      _paintInverse(canvas, style, t);
      return;
    }
    final fractions = timeline.fractionsAt(t);
    final strokes = geometry.strokes;
    for (var i = 0; i < strokes.length; i++) {
      if (fractions[i] <= 0) continue;
      final level = sigil.strokeLevels[i];
      // A fine pen, finer toward the set, where the rings crowd together; only
      // the outer rings carry a wash.
      final width = style.weight * 0.55 * (1.0 - 0.04 * level);
      final path = strokes[i].partial(fractions[i]);
      final wash = 0.5 - 0.1 * level;
      if (wash > 0) canvas.drawPath(path, style.washPaint(opacity: wash));
      canvas.drawPath(path, style.inkPaint(width: width));
    }
  }

  void _paintPoints(Canvas canvas, SceneStyle style, int count) {
    if (count <= 0) return;
    final paint = Paint()
      ..color = style.ink.withValues(alpha: 0.42)
      ..strokeWidth = style.px(style.strokeWidth) * 0.6
      ..strokeCap = StrokeCap.round;
    final pts = count >= sigil.pointCount ? sigil.points : Float32List.sublistView(sigil.points, 0, count * 2);
    canvas.drawRawPoints(ui.PointMode.points, pts, paint);
  }

  void _paintInverse(Canvas canvas, SceneStyle style, double t) {
    if (t < _unfolding) {
      // Points are stored shallowest first, and each depth doubles them, so a
      // linear count over time shows the tree of roots branching out.
      _paintPoints(canvas, style, (sigil.pointCount * minimumJerk(t / _unfolding)).round());
      return;
    }
    final key = (style.ink.toARGB32(), style.px(1));
    if (_settled == null || _settledKey != key) {
      _settled?.dispose();
      final recorder = ui.PictureRecorder();
      _paintPoints(Canvas(recorder), style, sigil.pointCount);
      _settled = recorder.endRecording();
      _settledKey = key;
    }
    canvas.drawPicture(_settled!);
  }

  @override
  void paintUnwritten(Canvas canvas, Size size, double inkLength, SceneStyle style) {
    if (!sigil.inverted) {
      super.paintUnwritten(canvas, size, inkLength, style);
      return;
    }
    final total = geometry.totalLength;
    final f = total <= 0 ? 0.0 : (inkLength / total).clamp(0.0, 1.0);
    _paintPoints(canvas, style, (sigil.pointCount * f).round());
  }
}
