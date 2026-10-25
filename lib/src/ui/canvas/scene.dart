import 'package:flutter/material.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/ductus.dart';
import '../theme/sigil_skins.dart';

/// Visual parameters for one frame, derived from the active skin.
class SceneStyle {
  final Color ink;
  final Color guide;
  final Color accent;
  final Color burn;
  final Color paper;
  final double strokeWidth;
  final double washOpacity;

  /// Breath volume in [0, 1] while Gnosis breathing is active, else null.
  final double? breath;

  const SceneStyle({
    required this.ink,
    required this.guide,
    required this.accent,
    required this.burn,
    required this.paper,
    required this.strokeWidth,
    required this.washOpacity,
    this.breath,
  });

  factory SceneStyle.fromSkin(SigilSkinTheme skin, {double? breath}) => SceneStyle(
        ink: skin.inkPrimary,
        guide: skin.guideColor,
        accent: skin.accent,
        burn: skin.burn,
        paper: skin.canvasBackground,
        strokeWidth: skin.strokeWidth,
        washOpacity: skin.inkWashOpacity,
        breath: breath,
      );

  /// Stroke weight, breathing by ±3 % with the Gnosis breath.
  double get weight => breath == null ? strokeWidth : strokeWidth * (0.97 + 0.06 * breath!);

  Paint inkPaint({double opacity = 1, double? width}) => Paint()
    ..color = ink.withValues(alpha: ink.a * opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width ?? weight
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint washPaint({double opacity = 1}) => Paint()
    ..color = ink.withValues(alpha: washOpacity * opacity * (breath == null ? 1 : 0.7 + 0.6 * breath!))
    ..style = PaintingStyle.stroke
    ..strokeWidth = weight * 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint guidePaint({double width = 1}) => Paint()
    ..color = guide
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  /// Draws a path as ink on rag paper: a soft wash under a crisp line.
  void drawInk(Canvas canvas, Path path, {double opacity = 1}) {
    canvas.drawPath(path, washPaint(opacity: opacity));
    canvas.drawPath(path, inkPaint(opacity: opacity));
  }
}

/// A sigil system's motion: a pure function of time since [startTime].
abstract class SigilScene {
  SigilScene({required this.startTime});

  /// Clock time at which this scene began, in seconds.
  final double startTime;

  /// Final, static geometry. The burn and the exports read this.
  SigilGeometry get geometry;

  /// Seconds after [startTime] after which nothing moves.
  double get settleTime;

  bool isSettled(double now) => now - startTime >= settleTime;

  /// Paints the scene at clock time [now].
  void paint(Canvas canvas, Size size, double now, SceneStyle style);

  /// Paints the settled scene with its ink limited to the first [inkLength]
  /// pixels in written order. The burn uses this to unwrite the sigil in
  /// reverse ductus: the last stroke written is the first consumed.
  void paintUnwritten(Canvas canvas, Size size, double inkLength, SceneStyle style) {
    style.drawInk(canvas, geometry.revealLength(inkLength));
  }
}

/// Writes a geometry stroke by stroke with the [DuctusTimeline]. Then stillness.
class DuctusScene extends SigilScene {
  DuctusScene(this.geometry, {required super.startTime}) : timeline = DuctusTimeline(geometry);

  @override
  final SigilGeometry geometry;
  final DuctusTimeline timeline;

  @override
  double get settleTime => timeline.duration;

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final t = now - startTime;
    final path = t >= timeline.duration ? geometry.path : geometry.reveal(timeline.fractionsAt(t));
    style.drawInk(canvas, path);
  }
}
