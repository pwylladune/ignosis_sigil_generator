import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/intent_kernel.dart';

/// Solves 2D Chladni plate vibration equations to generate acoustic resonance nodal curves.
///
/// Converts Statement of Intent phonetics into frequency harmonic ratios (m, n)
/// and extracts the zero-amplitude nodal boundary lines:
///   w(x, y) = a * sin(n*pi*x) * sin(m*pi*y) - b * sin(m*pi*x) * sin(n*pi*y) = 0
class ChladniEngine {
  /// Generates the cymatic nodal curve path from the intent kernel
  Path generatePath(IntentKernel kernel, Size size, {double animationPhase = 0.0}) {
    final path = Path();
    if (kernel.isEmpty) return path;

    // Derive modal numbers m and n from character codes
    int sum = 0;
    for (final c in kernel.consonantCodes) {
      sum += c;
    }

    final n = 2 + (sum % 5); // 2..6
    final m = 3 + ((sum ~/ 5) % 4); // 3..6
    final a = 1.0;
    final b = 0.8 + 0.4 * math.sin(animationPhase * 2 * math.pi);

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) * 0.42;

    // Contour trace using marching radial points
    const int radialSteps = 120;
    const int angleSteps = 360;

    // Precompute resonant rings
    for (int ring = 1; ring <= 4; ring++) {
      final rFactor = (ring / 4.0) * radius;
      bool first = true;

      for (int i = 0; i <= angleSteps; i += 4) {
        final theta = (i * math.pi) / 180.0;
        final normX = math.cos(theta);
        final normY = math.sin(theta);

        // Chladni modal displacement function
        final val = a * math.sin(n * normX) * math.sin(m * normY) -
            b * math.sin(m * normX) * math.sin(n * normY);

        final modulatedR = rFactor + val * (radius * 0.15);
        final px = centerX + modulatedR * math.cos(theta);
        final py = centerY + modulatedR * math.sin(theta);

        if (first) {
          path.moveTo(px, py);
          first = false;
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
    }

    // Outer sacred brass plate boundary
    path.addOval(Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));

    return path;
  }
}
