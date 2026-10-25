import 'dart:math' as math;
import 'dart:ui';
import '../geometry/sigil_geometry.dart';
import '../models/hebrew_letters.dart';
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

/// Geometry of a centred, square kamea grid on the canvas.
class KameaLayout {
  KameaLayout(this.n, Size size)
      : square = Rect.fromCenter(
          center: size.center(Offset.zero),
          // Fits inside the plate's guide circle (radius 0.44·w): side ≤ 0.62·w.
          width: math.min(size.width, size.height) * 0.6,
          height: math.min(size.width, size.height) * 0.6,
        );

  final int n;
  final Rect square;

  double get cell => square.width / n;

  Offset cellCenter(int index) =>
      Offset(square.left + (index % n + 0.5) * cell, square.top + (index ~/ n + 0.5) * cell);

  Rect cellRect(int index) => Rect.fromLTWH(square.left + (index % n) * cell, square.top + (index ~/ n) * cell, cell, cell);
}

/// A traced kamea sigil: which numbers and cells the letters visit, and the
/// written geometry (start circle, traversal, terminal crossbar).
class KameaSigil {
  KameaSigil({
    required this.type,
    required this.layout,
    required this.letters,
    required this.numbers,
    required this.cells,
    required this.geometry,
    required this.visitFractions,
  });

  final PlanetaryKameaType type;
  final KameaLayout layout;
  final String letters;

  /// Aiq Bekar–reduced gematria value of each letter, in `[1, n²]`.
  final List<int> numbers;

  /// Row-major cell index of each number in the square.
  final List<int> cells;
  final SigilGeometry geometry;

  /// Fraction of the traversal stroke's length at which each node is reached.
  final List<double> visitFractions;

  /// Index of the traversal stroke in [geometry], or null for a single node.
  int? get traversalStroke => geometry.strokes.length >= 2 ? 1 : null;
}

/// Planetary Kamea sigils with classical grammar:
/// - each letter → Hebrew gematria (see [latinToHebrew]) → Aiq Bekar reduction
///   into the square's range `[1, n²]`, so no two letters collide by accident
///   of the alphabet index;
/// - a hollow circle where the pen starts, straight traversal from cell to
///   cell, a loop on an immediate repeat, and a perpendicular crossbar at the end.
class KameaEngine {
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

  /// The square for [type] as row-major numbers.
  static List<int> square(PlanetaryKameaType type) => _squares[type]!;

  /// Magic constant `M = n(n² + 1) / 2`: every row, column and diagonal sums to it.
  static int magicConstant(int n) => n * (n * n + 1) ~/ 2;

  /// Gematria value of a Latin letter reduced into `[1, n²]`.
  static int letterNumber(String letter, int n) {
    final hebrew = latinToHebrew[letter] ?? HebrewLetter.aleph;
    return aiqBekarReduce(hebrew.value, n * n);
  }

  KameaSigil build(IntentKernel kernel, PlanetaryKameaType type, Size size) {
    final n = type.size;
    final layout = KameaLayout(n, size);
    final sq = square(type);
    final letters = kernel.reducedConsonants;
    final numbers = [for (var i = 0; i < letters.length; i++) letterNumber(letters[i], n)];
    final cells = [for (final v in numbers) sq.indexOf(v)];
    final nodes = [for (final c in cells) layout.cellCenter(c)];

    final strokes = <SigilStroke>[];
    final cumulative = <double>[];
    if (nodes.isNotEmpty) {
      final cell = layout.cell;
      final startRadius = (cell * 0.14).clamp(3.0, 7.0);
      strokes.add(SigilStroke(Path()..addOval(Rect.fromCircle(center: nodes.first, radius: startRadius)), role: StrokeRole.startMark));

      if (nodes.length > 1) {
        final trace = Path()..moveTo(nodes.first.dx, nodes.first.dy);
        final loopR = (cell * 0.2).clamp(4.0, 10.0);
        cumulative.add(0);
        for (var i = 1; i < nodes.length; i++) {
          final p = nodes[i];
          cumulative.add(cumulative.last + (p - nodes[i - 1]).distance);
          if (cells[i] == cells[i - 1]) {
            // Immediate repeat: a small loop above the node, back to the node.
            trace.arcTo(Rect.fromCircle(center: p.translate(0, -loopR), radius: loopR), math.pi / 2, 2 * math.pi - 0.01, false);
            trace.lineTo(p.dx, p.dy);
            cumulative.last += 2 * math.pi * loopR;
          } else {
            trace.lineTo(p.dx, p.dy);
          }
        }
        strokes.add(SigilStroke(trace));

        // Terminal crossbar perpendicular to the last distinct segment.
        var j = nodes.length - 2;
        while (j > 0 && cells[j] == cells.last) {
          j--;
        }
        final d = nodes.last - nodes[j];
        if (d.distance > 0) {
          final half = (cell * 0.24).clamp(5.0, 12.0);
          final normal = Offset(-d.dy, d.dx) / d.distance * half;
          strokes.add(SigilStroke(
            Path()
              ..moveTo(nodes.last.dx - normal.dx, nodes.last.dy - normal.dy)
              ..lineTo(nodes.last.dx + normal.dx, nodes.last.dy + normal.dy),
            role: StrokeRole.terminal,
          ));
        }
      }
    }

    final total = cumulative.isEmpty ? 0.0 : cumulative.last;
    return KameaSigil(
      visitFractions: [for (final c in cumulative) total > 0 ? c / total : 0.0],
      type: type,
      layout: layout,
      letters: letters,
      numbers: numbers,
      cells: cells,
      geometry: SigilGeometry(strokes: strokes, nodes: nodes),
    );
  }
}
