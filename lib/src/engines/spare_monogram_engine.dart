import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/intent_kernel.dart';

/// Radical strokes of capital letters A-Z
enum StrokeType { vertical, horizontal, diagonalUp, diagonalDown, loop, arch }

/// Austin Osman Spare monogram solver that breaks characters into geometric radicals,
/// clusters them into a singular connected glyph, and applies user-selected rotational symmetry.
class SpareMonogramEngine {
  /// Maps consonants to fundamental geometric strokes
  static List<StrokeType> _getLetterStrokes(String char) {
    switch (char) {
      case 'B':
        return [StrokeType.vertical, StrokeType.loop];
      case 'C':
        return [StrokeType.arch];
      case 'D':
        return [StrokeType.vertical, StrokeType.arch];
      case 'F':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'G':
        return [StrokeType.arch, StrokeType.horizontal];
      case 'H':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'J':
        return [StrokeType.vertical, StrokeType.arch];
      case 'K':
        return [StrokeType.vertical, StrokeType.diagonalUp, StrokeType.diagonalDown];
      case 'L':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'M':
      case 'W':
        return [StrokeType.vertical, StrokeType.diagonalDown, StrokeType.diagonalUp];
      case 'N':
        return [StrokeType.vertical, StrokeType.diagonalDown];
      case 'P':
        return [StrokeType.vertical, StrokeType.loop];
      case 'R':
        return [StrokeType.vertical, StrokeType.loop, StrokeType.diagonalDown];
      case 'S':
        return [StrokeType.arch];
      case 'T':
        return [StrokeType.vertical, StrokeType.horizontal];
      case 'V':
        return [StrokeType.diagonalDown, StrokeType.diagonalUp];
      case 'X':
        return [StrokeType.diagonalDown, StrokeType.diagonalUp];
      case 'Z':
        return [StrokeType.horizontal, StrokeType.diagonalDown];
      default:
        return [StrokeType.vertical, StrokeType.arch];
    }
  }

  /// Generates the Spare Monogram path
  Path generatePath(
    IntentKernel kernel,
    Size size, {
    int symmetry = 2,
    double animationPhase = 0.0,
  }) {
    final path = Path();
    if (kernel.isEmpty) return path;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = math.min(size.width, size.height) * 0.35;

    final baseGlyph = Path();
    final spineLen = scale * 0.9;

    // Central central axis spine
    baseGlyph.moveTo(0, -spineLen / 2);
    baseGlyph.lineTo(0, spineLen / 2);

    // Iteratively attach radical strokes derived from intent consonants
    double offsetStep = spineLen / (kernel.reducedConsonants.length + 1);

    for (int i = 0; i < kernel.reducedConsonants.length; i++) {
      final char = kernel.reducedConsonants[i];
      final strokes = _getLetterStrokes(char);
      final yAnchor = (-spineLen / 2) + ((i + 1) * offsetStep);

      for (final stroke in strokes) {
        switch (stroke) {
          case StrokeType.horizontal:
            baseGlyph.moveTo(-scale * 0.25, yAnchor);
            baseGlyph.lineTo(scale * 0.25, yAnchor);
            break;
          case StrokeType.diagonalDown:
            baseGlyph.moveTo(0, yAnchor);
            baseGlyph.lineTo(scale * 0.35, yAnchor + scale * 0.25);
            break;
          case StrokeType.diagonalUp:
            baseGlyph.moveTo(0, yAnchor);
            baseGlyph.lineTo(-scale * 0.35, yAnchor - scale * 0.25);
            break;
          case StrokeType.loop:
            baseGlyph.addOval(Rect.fromCircle(
              center: Offset(scale * 0.18, yAnchor),
              radius: scale * 0.15,
            ));
            break;
          case StrokeType.arch:
            baseGlyph.addArc(
              Rect.fromCircle(center: Offset(0, yAnchor), radius: scale * 0.22),
              -math.pi / 2,
              math.pi,
            );
            break;
          case StrokeType.vertical:
            baseGlyph.moveTo(scale * 0.2, yAnchor - scale * 0.15);
            baseGlyph.lineTo(scale * 0.2, yAnchor + scale * 0.15);
            break;
        }
      }
    }

    // Apply Rotational Symmetry around canvas center
    final angleStep = (2 * math.pi) / symmetry;
    for (int s = 0; s < symmetry; s++) {
      final rot = s * angleStep + (animationPhase * 0.2);
      final matrix = Matrix4.identity()
        ..translateByDouble(centerX, centerY, 0.0, 1.0)
        ..rotateZ(rot);

      path.addPath(baseGlyph.transform(matrix.storage), Offset.zero);
    }

    // Outer binding seal circle
    path.addOval(Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: scale * 1.15,
    ));

    return path;
  }
}
