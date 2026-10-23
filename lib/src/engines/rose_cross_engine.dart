import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/intent_kernel.dart';

/// Implements the Rosicrucian / Golden Dawn Rose Cross Lamen Dial.
///
/// Letters of the alphabet are mapped to concentric petal tiers:
/// - Inner tier (3 Mother elements: Air, Water, Fire)
/// - Middle tier (7 Planetary paths)
/// - Outer tier (12 Zodiacal signs)
/// Total: 22 paths of the Hebrew Tree of Life / expanded 26-letter Latin Rose.
class RoseCrossEngine {
  /// Standard 26-letter Latin distribution on the Rose Cross petals
  static const List<String> _petalOrder = [
    'A', 'L', 'P', 'H', 'A', 'B', 'E', 'T', 'O', 'S',
    'C', 'D', 'F', 'G', 'I', 'J', 'K', 'M', 'N', 'Q',
    'R', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  /// Computes petal polar coordinates for a given letter
  static Offset getPetalPosition(String char, Offset center, double maxRadius) {
    // 3 Concentric rings
    final index = _petalOrder.indexOf(char);
    final posIndex = index != -1 ? index : (char.codeUnitAt(0) - 65) % 26;

    // Distribute into 3 concentric tiers
    final tier = posIndex % 3; // 0, 1, 2
    final ringRadius = maxRadius * (0.35 + (tier * 0.30));

    // Radial angle (golden angle distribution for organic balance)
    final angle = (posIndex / 26.0) * 2 * math.pi - (math.pi / 2);

    return Offset(
      center.dx + ringRadius * math.cos(angle),
      center.dy + ringRadius * math.sin(angle),
    );
  }

  /// Generates the Rose Cross sigil path from an intent kernel
  Path generatePath(IntentKernel kernel, Size size, {bool drawBackgroundPetals = false}) {
    final path = Path();
    if (kernel.isEmpty) return path;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.42;

    final nodes = <Offset>[];
    for (int i = 0; i < kernel.reducedConsonants.length; i++) {
      final char = kernel.reducedConsonants[i];
      nodes.add(getPetalPosition(char, center, maxRadius));
    }

    if (nodes.isEmpty) return path;

    // Start node: Traditional circle
    final start = nodes.first;
    const startRadius = 5.0;
    path.addOval(Rect.fromCircle(center: start, radius: startRadius));

    if (nodes.length == 1) return path;

    // Connect petal nodes with continuous Bézier splines
    path.moveTo(start.dx, start.dy);
    for (int i = 1; i < nodes.length; i++) {
      final prev = nodes[i - 1];
      final curr = nodes[i];

      // Pull toward center slightly for organic curved flower petal flow
      final controlX = (prev.dx + curr.dx) / 2 + (center.dx - (prev.dx + curr.dx) / 2) * 0.2;
      final controlY = (prev.dy + curr.dy) / 2 + (center.dy - (prev.dy + curr.dy) / 2) * 0.2;

      path.quadraticBezierTo(controlX, controlY, curr.dx, curr.dy);
    }

    // Termination crossbar
    if (nodes.length >= 2) {
      final last = nodes.last;
      final secondLast = nodes[nodes.length - 2];
      final dx = last.dx - secondLast.dx;
      final dy = last.dy - secondLast.dy;
      final len = math.sqrt(dx * dx + dy * dy);

      if (len > 0) {
        const barHalf = 8.0;
        final nx = (-dy / len) * barHalf;
        final ny = (dx / len) * barHalf;
        path.moveTo(last.dx - nx, last.dy - ny);
        path.lineTo(last.dx + nx, last.dy + ny);
      }
    }

    return path;
  }
}
