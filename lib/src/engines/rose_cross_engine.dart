import 'dart:math' as math;
import 'dart:ui';
import '../geometry/sigil_geometry.dart';
import '../models/hebrew_letters.dart';
import '../models/intent_kernel.dart';

/// A petal of the rose: one Hebrew letter on one of the three rings.
class RosePetal {
  const RosePetal(this.letter, this.ring, this.index, this.count, this.angle);

  final HebrewLetter letter;

  /// 0 = inner (3 mothers), 1 = middle (7 doubles), 2 = outer (12 simples).
  final int ring;

  /// Position in the ring's sequence (see [RoseCrossEngine.rings]).
  final int index;
  final int count;

  /// Rest angle on the canvas (radians; 0 = 3 o'clock, y down).
  final double angle;
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
/// doubles, outer 12 simples), arranged as on the lamen (Crowley, The
/// Equinox I:3, 1910, Diagram 63; Regardie, The Golden Dawn):
/// - inner: Aleph at the top (under the arm of Air), then Shin and Mem
///   clockwise;
/// - outer: the zodiac from Aries (He) at the top, running anticlockwise
///   He, Vav, Zayin, Cheth, Teth, Yod, Lamed, Nun, Samekh, Ayin, Tzaddi, Qoph;
/// - middle: the planets anticlockwise in King-scale spectral order
///   Pe, Resh, Beth, Daleth, Gimel, Tav, Kaph, the top falling between Pe
///   (11 o'clock) and Kaph (1 o'clock). Secondary sources disagree on the
///   Kaph/Tav order; check against the plate before relying on it.
/// The typed text reaches the rose through [transliterate].
class RoseCrossEngine {
  /// Ring radii as fractions of the rose radius.
  static const ringRadii = [0.30, 0.60, 0.90];

  /// Relative angular speeds of the rings: 3 : 7 : 12 (the letters they hold).
  static const ringRatios = [3, 7, 12];

  /// Each ring's letters in the order they run around the lamen.
  static const List<List<HebrewLetter>> rings = [
    [HebrewLetter.aleph, HebrewLetter.shin, HebrewLetter.mem],
    [
      HebrewLetter.pe, HebrewLetter.resh, HebrewLetter.beth, HebrewLetter.daleth, //
      HebrewLetter.gimel, HebrewLetter.tav, HebrewLetter.kaph,
    ],
    [
      HebrewLetter.he, HebrewLetter.vav, HebrewLetter.zayin, HebrewLetter.heth, //
      HebrewLetter.teth, HebrewLetter.yod, HebrewLetter.lamed, HebrewLetter.nun,
      HebrewLetter.samekh, HebrewLetter.ayin, HebrewLetter.tzaddi, HebrewLetter.qoph,
    ],
  ];

  /// Ring direction on screen (+1 clockwise, −1 anticlockwise) and the angle
  /// of the first letter (offset from the top in units of one petal step).
  static const _direction = [1, -1, -1];
  static const _startOffset = [0.0, -0.5, 0.0];

  static double _angle(int ring, int index) {
    final step = 2 * math.pi / rings[ring].length;
    // Screen angles grow clockwise (y points down).
    return -math.pi / 2 + _startOffset[ring] * step + _direction[ring] * step * index;
  }

  /// Every petal on the rose.
  static final List<RosePetal> allPetals = [
    for (var r = 0; r < 3; r++)
      for (var i = 0; i < rings[r].length; i++) RosePetal(rings[r][i], r, i, rings[r].length, _angle(r, i)),
  ];

  /// The petal that holds a Hebrew letter.
  static RosePetal petalOf(HebrewLetter letter) => allPetals.firstWhere((p) => p.letter == letter);

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
    final petals = [for (final l in transliterate(kernel.normalized)) petalOf(l)];
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
