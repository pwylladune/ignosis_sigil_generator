import 'package:flutter/material.dart';
import '../../motion/easing.dart';
import 'scene.dart';

/// The burn: dissolves a settled scene. A pure function of time since [startTime].
class Combustion {
  Combustion({required this.scene, required this.startTime, this.reduceMotion = false});

  final SigilScene scene;
  final double startTime;
  final bool reduceMotion;

  /// Total burn time in seconds. Reduce-motion uses a short crossfade instead.
  double get duration => reduceMotion ? 0.8 : 4.0;

  double progress(double now) => ((now - startTime) / duration).clamp(0.0, 1.0);

  bool isDone(double now) => now - startTime >= duration;

  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final p = progress(now);
    if (reduceMotion) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - p));
      scene.paint(canvas, size, double.infinity, style);
      canvas.restore();
      return;
    }
    // Reverse ductus: the last stroke written is the first consumed.
    final remaining = scene.geometry.totalLength * (1 - minimumJerk(p));
    scene.paintUnwritten(canvas, size, remaining, style);
  }
}
