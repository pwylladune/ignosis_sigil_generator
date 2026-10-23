import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Painter that draws active ascending embers and sparks during the ritual burn.
class EmberParticlePainter extends CustomPainter {
  final double progress;
  final double time;
  final Color emberColor;

  EmberParticlePainter({
    required this.progress,
    required this.time,
    this.emberColor = const Color(0xFFFF6D00),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    // Number of sparks increases with burn intensity
    final particleCount = (progress * 90).toInt();

    for (int i = 0; i < particleCount; i++) {
      // Deterministic pseudo-random seed per particle
      final seed = (i * 9301 + 49297) % 233280;
      final randX = (seed / 233280.0);
      final randY = ((seed * 7) % 233280) / 233280.0;
      final speed = 0.4 + (seed % 100) / 100.0;

      // Particles rise up and drift horizontally
      final currentY = size.height * (1.0 - ((progress * speed + randY) % 1.0));
      final driftX = (size.width * randX) + 25 * ui.lerpDouble(-1, 1, ((time * speed + i) % 2.0) / 2.0)!;

      final sparkAlpha = (1.0 - (1.0 - (currentY / size.height))).clamp(0.0, 1.0);
      final radius = 1.0 + (i % 3) * 1.2;

      paint.color = emberColor.withValues(alpha: sparkAlpha * (1.0 - progress * 0.3));
      canvas.drawCircle(Offset(driftX % size.width, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EmberParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.time != time;
  }
}
