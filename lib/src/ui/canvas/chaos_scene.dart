import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import '../../engines/cyber_chaos_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/easing.dart';
import 'scene.dart';

/// Accretion: the orbit is iterated into view, so the attractor condenses out
/// of noise over a few seconds and density builds like ink soaking into paper
/// (overdraw of faint points approximates a log-density render). Then stillness.
class ChaosScene extends SigilScene {
  ChaosScene(this.sigil, {required super.startTime});

  final ChaosSigil sigil;
  static const _accretion = 4.0;

  @override
  SigilGeometry get geometry => sigil.geometry;

  @override
  bool get ownsGuides => true;

  @override
  double get settleTime => sigil.count == 0 ? 0 : _accretion;

  void _paintPoints(Canvas canvas, SceneStyle style, int count, {double opacity = 1}) {
    if (count <= 0) return;
    final paint = Paint()
      ..color = style.ink.withValues(alpha: 0.11 * opacity)
      ..strokeWidth = style.weight * 0.55
      ..strokeCap = StrokeCap.round;
    final pts = count >= sigil.count ? sigil.points : Float32List.sublistView(sigil.points, 0, count * 2);
    canvas.drawRawPoints(PointMode.points, pts, paint);
  }

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final t = now - startTime;
    _paintPoints(canvas, style, (sigil.count * minimumJerk(t / _accretion)).round());
  }

  @override
  void paintUnwritten(Canvas canvas, Size size, double inkLength, SceneStyle style) {
    final total = sigil.geometry.totalLength;
    final f = total <= 0 ? 0.0 : (inkLength / total).clamp(0.0, 1.0);
    _paintPoints(canvas, style, (sigil.count * f).round());
  }
}
