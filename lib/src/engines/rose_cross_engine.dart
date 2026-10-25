import 'dart:math' as math;
import 'dart:ui';
import '../geometry/sigil_geometry.dart';
import '../models/hebrew_letters.dart';
import '../models/intent_kernel.dart';

/// A petal of the rose: one Hebrew letter on one of the three rings.
class RosePetal {
  const RosePetal(this.letter, this.ring, this.index, this.count);

  final HebrewLetter letter;

  /// 0 = inner (3 mothers), 1 = middle (7 doubles), 2 = outer (12 simples).
  final int ring;
  final int index;
  final int count;

  /// Rest angle on its ring, starting at the top and running clockwise.
  double get angle => -math.pi / 2 + 2 * math.pi * index / count;
}

/// The traced rose sigil for a given ring rotation.
class RoseSigil {
  RoseSigil({required this.center, required this.radius, required this.petals, required this.geometry});

  final Offset center;

  /// Outer radius of the rose; ring k sits at [RoseCrossEngine.ringRadii][k]·radius.
  final double radius;

  /// Petal visited by each letter, in order.
  final List<RosePetal> petals;
  final SigilGeometry geometry;
}

/// The Golden Dawn Rose Cross lamen: three concentric rings of petals holding
/// the 22 Hebrew letters by Sepher Yetzirah class (inner 3 mothers, middle 7
/// doubles, outer 12 simples). Latin letters reach the rose through the
/// published table in [latinToHebrew], so all 26 land deterministically.
class RoseCrossEngine {
  /// Ring radii as fractions of the rose radius.
  static const ringRadii = [0.30, 0.60, 0.90];

  /// Relative angular speeds of the rings: 3 : 7 : 12 (the letters they hold).
  static const ringRatios = [3, 7, 12];

  static final List<List<HebrewLetter>> rings = [
    HebrewLetter.ofClass(LetterClass.mother),
    HebrewLetter.ofClass(LetterClass.double),
    HebrewLetter.ofClass(LetterClass.simple),
  ];

  /// Every petal on the rose.
  static final List<RosePetal> allPetals = [
    for (var r = 0; r < 3; r++)
      for (var i = 0; i < rings[r].length; i++) RosePetal(rings[r][i], r, i, rings[r].length),
  ];

  /// The petal a Latin letter lands on.
  static RosePetal petalFor(String latin) {
    final hebrew = latinToHebrew[latin] ?? HebrewLetter.aleph;
    return allPetals.firstWhere((p) => p.letter == hebrew);
  }

  static double roseRadius(Size size) => math.min(size.width, size.height) * 0.42;

  /// Position of [petal] with ring k turned by `ringRotation[k]` radians.
  static Offset petalPosition(RosePetal petal, Offset center, double radius, [List<double> ringRotation = const [0, 0, 0]]) {
    final a = petal.angle + ringRotation[petal.ring];
    final r = radius * ringRadii[petal.ring];
    return Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
  }

  /// Builds the sigil; [ringRotation] turns each ring (used by the astrolabe lock).
  RoseSigil build(IntentKernel kernel, Size size, {List<double> ringRotation = const [0, 0, 0]}) {
    final center = size.center(Offset.zero);
    final radius = roseRadius(size);
    final letters = kernel.reducedConsonants;
    final petals = [for (var i = 0; i < letters.length; i++) petalFor(letters[i])];
    final nodes = [for (final p in petals) petalPosition(p, center, radius, ringRotation)];

    final strokes = <SigilStroke>[];
    if (nodes.isNotEmpty) {
      strokes.add(SigilStroke(Path()..addOval(Rect.fromCircle(center: nodes.first, radius: 5)), role: StrokeRole.startMark));
      if (nodes.length > 1) {
        final trace = Path()..moveTo(nodes.first.dx, nodes.first.dy);
        for (var i = 1; i < nodes.length; i++) {
          final prev = nodes[i - 1], cur = nodes[i];
          if (petals[i] == petals[i - 1]) {
            // Same petal twice (e.g. C then K): a small loop outward.
            final out = cur - center;
            final dir = out.distance == 0 ? const Offset(0, -1) : out / out.distance;
            trace.arcTo(Rect.fromCircle(center: cur + dir * 7, radius: 7), math.atan2(-dir.dy, -dir.dx), 2 * math.pi - 0.01, false);
            trace.lineTo(cur.dx, cur.dy);
            continue;
          }
          // Petal flow: curves bow gently toward the centre of the rose.
          final mid = (prev + cur) / 2;
          final control = mid + (center - mid) * 0.2;
          trace.quadraticBezierTo(control.dx, control.dy, cur.dx, cur.dy);
        }
        strokes.add(SigilStroke(trace));

        var j = nodes.length - 2;
        while (j > 0 && petals[j] == petals.last) {
          j--;
        }
        final mid = (nodes[j] + nodes.last) / 2;
        final control = mid + (center - mid) * 0.2;
        final d = nodes.last - control; // tangent at the end of the last curve
        if (d.distance > 0) {
          final normal = Offset(-d.dy, d.dx) / d.distance * 8;
          strokes.add(SigilStroke(
            Path()
              ..moveTo(nodes.last.dx - normal.dx, nodes.last.dy - normal.dy)
              ..lineTo(nodes.last.dx + normal.dx, nodes.last.dy + normal.dy),
            role: StrokeRole.terminal,
          ));
        }
      } else {
        // A single letter: no curve to follow, so seal it with a bar across
        // the radial direction, just outside the start circle.
        final out = nodes.first - center;
        final dir = out.distance == 0 ? const Offset(0, -1) : out / out.distance;
        final at = nodes.first + dir * 10;
        final normal = Offset(-dir.dy, dir.dx) * 8;
        strokes.add(SigilStroke(
          Path()
            ..moveTo(at.dx - normal.dx, at.dy - normal.dy)
            ..lineTo(at.dx + normal.dx, at.dy + normal.dy),
          role: StrokeRole.terminal,
        ));
      }
    }
    return RoseSigil(center: center, radius: radius, petals: petals, geometry: SigilGeometry(strokes: strokes, nodes: nodes));
  }
}
