import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/intent_kernel.dart';

/// The 7 Classical Planetary Magic Squares.
enum PlanetaryKameaType {
  saturn(3, 'Saturn (3x3)', 'Form, Boundaries, Endurance'),
  jupiter(4, 'Jupiter (4x4)', 'Abundance, Expansion, Sovereign Power'),
  mars(5, 'Mars (5x5)', 'Strength, Courage, Decisive Action'),
  sol(6, 'Sol (6x6)', 'Illumination, Radiance, Vitality'),
  venus(7, 'Venus (7x7)', 'Harmony, Attraction, Synthesis'),
  mercury(8, 'Mercury (8x8)', 'Cunning, Speed, Magic & Communication'),
  luna(9, 'Luna (9x9)', 'Subconscious, Dreams, The Deep Waters');

  final int size;
  final String label;
  final String aspect;
  const PlanetaryKameaType(this.size, this.label, this.aspect);
}

/// Generates authentic Planetary Kamea Sigil paths with classical sigil grammar:
/// - Circle starting node (O)
/// - Continuous vector or smooth Bézier spline interconnects
/// - Teardrop or loop reflex on repeats
/// - Orthogonal crossbar termination (T / ⟂)
class KameaEngine {
  /// Precomputed standard magic squares (1-indexed numbers in row-major order)
  static final Map<PlanetaryKameaType, List<int>> _squares = {
    // Saturn 3x3 (Sum = 15)
    PlanetaryKameaType.saturn: [
      4, 9, 2,
      3, 5, 7,
      8, 1, 6,
    ],
    // Jupiter 4x4 (Sum = 34)
    PlanetaryKameaType.jupiter: [
      4, 14, 15, 1,
      9, 7, 6, 12,
      5, 11, 10, 8,
      16, 2, 3, 13,
    ],
    // Mars 5x5 (Sum = 65)
    PlanetaryKameaType.mars: [
      11, 24, 7, 20, 3,
      4, 12, 25, 8, 16,
      17, 5, 13, 21, 9,
      10, 18, 1, 14, 22,
      23, 6, 19, 2, 15,
    ],
    // Sol 6x6 (Sum = 111)
    PlanetaryKameaType.sol: [
      6, 32, 3, 34, 35, 1,
      7, 11, 27, 28, 8, 30,
      19, 14, 16, 15, 23, 24,
      18, 20, 22, 21, 17, 13,
      25, 29, 10, 9, 26, 12,
      36, 5, 33, 4, 2, 31,
    ],
    // Venus 7x7 (Sum = 175)
    PlanetaryKameaType.venus: [
      22, 47, 16, 41, 10, 35, 4,
      5, 23, 48, 17, 42, 11, 29,
      30, 6, 24, 49, 18, 36, 12,
      13, 31, 7, 25, 43, 19, 37,
      38, 14, 32, 1, 26, 44, 20,
      21, 39, 8, 33, 2, 27, 45,
      46, 15, 40, 9, 34, 3, 28,
    ],
    // Mercury 8x8 (Sum = 260)
    PlanetaryKameaType.mercury: [
      8, 58, 59, 5, 4, 62, 63, 1,
      49, 15, 14, 52, 53, 11, 10, 56,
      41, 23, 22, 44, 45, 19, 18, 48,
      32, 34, 35, 29, 28, 38, 39, 25,
      40, 26, 27, 37, 36, 30, 31, 33,
      17, 47, 46, 20, 21, 43, 42, 24,
      9, 55, 54, 12, 13, 51, 50, 16,
      64, 2, 3, 61, 60, 6, 7, 57,
    ],
    // Luna 9x9 (Sum = 369)
    PlanetaryKameaType.luna: [
      37, 78, 29, 70, 21, 62, 13, 54, 5,
      6, 38, 79, 30, 71, 22, 63, 14, 46,
      47, 7, 39, 80, 31, 72, 23, 55, 15,
      16, 48, 8, 40, 81, 32, 64, 24, 56,
      57, 17, 49, 9, 41, 73, 33, 65, 25,
      26, 58, 18, 50, 1, 42, 74, 34, 66,
      67, 27, 59, 10, 51, 2, 43, 75, 35,
      36, 68, 19, 60, 11, 52, 3, 44, 76,
      77, 28, 69, 20, 61, 12, 53, 4, 45,
    ],
  };

  /// Computes the sequence of 2D node coordinates on the canvas for a given intent.
  List<Offset> getNodes(IntentKernel kernel, PlanetaryKameaType type, Size size) {
    if (kernel.isEmpty) return [];

    final n = type.size;
    final square = _squares[type]!;
    final totalCells = n * n;

    final cellWidth = size.width / n;
    final cellHeight = size.height / n;

    final offsets = <Offset>[];

    for (final code in kernel.consonantCodes) {
      // Map character (A-Z) to grid number 1..totalCells
      // Agrippa reduction or mod-mapping
      final rawVal = code - 65; // 0..25
      final gridTarget = (rawVal % totalCells) + 1; // 1..totalCells

      final index = square.indexOf(gridTarget);
      if (index != -1) {
        final row = index ~/ n;
        final col = index % n;
        final x = col * cellWidth + (cellWidth / 2);
        final y = row * cellHeight + (cellHeight / 2);
        offsets.add(Offset(x, y));
      }
    }

    return offsets;
  }

  /// Generates the complete Sigil Path including classical start circle,
  /// connection lines, and termination crossbar.
  Path generatePath(IntentKernel kernel, PlanetaryKameaType type, Size size) {
    final path = Path();
    final nodes = getNodes(kernel, type, size);

    if (nodes.isEmpty) return path;

    // Start node: Traditional hollow circle (radius = 6.0)
    final start = nodes.first;
    const startRadius = 6.0;
    path.addOval(Rect.fromCircle(center: start, radius: startRadius));

    if (nodes.length == 1) return path;

    // Connect nodes
    path.moveTo(start.dx, start.dy);
    for (int i = 1; i < nodes.length; i++) {
      final prev = nodes[i - 1];
      final curr = nodes[i];

      if (prev == curr) {
        // Repeat node: create a small loop / rebound arc
        path.relativeArcToPoint(
          const Offset(10, -10),
          radius: const Radius.circular(8),
        );
        path.relativeArcToPoint(
          const Offset(-10, 10),
          radius: const Radius.circular(8),
        );
      } else {
        // Interpolate smooth curve between nodes
        final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
        path.lineTo(curr.dx, curr.dy);
      }
    }

    // Final node: Traditional perpendicular crossbar (T / ⟂)
    if (nodes.length >= 2) {
      final last = nodes.last;
      final secondLast = nodes[nodes.length - 2];
      final dx = last.dx - secondLast.dx;
      final dy = last.dy - secondLast.dy;
      final len = math.sqrt(dx * dx + dy * dy);

      if (len > 0) {
        // Normal vector (-dy, dx)
        const barHalf = 10.0;
        final nx = (-dy / len) * barHalf;
        final ny = (dx / len) * barHalf;

        path.moveTo(last.dx - nx, last.dy - ny);
        path.lineTo(last.dx + nx, last.dy + ny);
      }
    }

    return path;
  }
}
