import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/intent_kernel.dart';

/// Cyber-Chaos engine using cryptographic hash functions (SHA-256 / Keccak-256)
/// to project entropy bytes onto polar multi-fold coordinate planes.
class CyberChaosEngine {
  /// Generates a complex cryptographic cyber-sigil path
  Path generatePath(
    IntentKernel kernel,
    Size size, {
    int symmetryFolds = 4,
    double animationPhase = 0.0,
  }) {
    final path = Path();
    if (kernel.isEmpty) return path;

    // Cryptographic entropy digest of the intent
    final bytes = utf8.encode(kernel.normalized);
    final digest = sha256.convert(bytes).bytes;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = math.min(size.width, size.height) * 0.40;

    // Extract coordinate waypoints from digest
    final waypoints = <Offset>[];
    for (int i = 0; i < digest.length - 2; i += 2) {
      final rByte = digest[i];
      final thetaByte = digest[i + 1];

      final r = (rByte / 255.0) * maxRadius;
      final theta = (thetaByte / 255.0) * 2 * math.pi + (animationPhase * 2 * math.pi);

      waypoints.add(Offset(
        r * math.cos(theta),
        r * math.sin(theta),
      ));
    }

    if (waypoints.isEmpty) return path;

    // Project with rotational symmetry folds (e.g. 4-fold or 8-fold)
    final foldAngle = (2 * math.pi) / symmetryFolds;

    for (int fold = 0; fold < symmetryFolds; fold++) {
      final rot = fold * foldAngle;
      final cosRot = math.cos(rot);
      final sinRot = math.sin(rot);

      bool isFirst = true;
      for (final pt in waypoints) {
        // Rotate point
        final rx = pt.dx * cosRot - pt.dy * sinRot;
        final ry = pt.dx * sinRot + pt.dy * cosRot;

        final px = centerX + rx;
        final py = centerY + ry;

        if (isFirst) {
          path.moveTo(px, py);
          isFirst = false;
        } else {
          path.lineTo(px, py);
        }
      }
    }

    // Central core focal ring
    path.addOval(Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: maxRadius * 0.12,
    ));

    return path;
  }
}
