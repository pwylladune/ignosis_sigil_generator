import 'dart:math' as math;
import 'dart:ui';
import '../geometry/sigil_geometry.dart';
import '../models/intent_kernel.dart';

/// One step of the cipher: an arc on ring [ring] from spoke [from] to spoke
/// [to], swept the short way round ([sweep] in radians, signed: + clockwise).
class RingArc {
  const RingArc(this.ring, this.from, this.to, this.sweep);

  final int ring;
  final int from;
  final int to;
  final double sweep;
}

/// A traced ring cipher: the letters, their arcs, the wheel's layout and the
/// written geometry (one stroke per arc, inner to outer).
class RingCipherSigil {
  RingCipherSigil({
    required this.text,
    required this.arcs,
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.spacing,
    required this.geometry,
  });

  /// The cipher letters traced, in order (A–Z, ',' and '.').
  final String text;
  final List<RingArc> arcs;
  final Offset center;
  final double innerRadius;
  final double outerRadius;

  /// Distance between rings; each arc fills most of its ring's band.
  final double spacing;
  final SigilGeometry geometry;

  /// Width of a filled band.
  double get bandWidth => spacing * 0.82;

  /// Centre radius of ring [k].
  double ringRadius(int k) => innerRadius + (k + 0.5) * spacing;
}

/// The Ring Cipher: a wheel of 28 spokes (A–Z, ',' and '.') and concentric
/// rings. The phrase is traced outward: starting on the innermost ring at the
/// first letter's spoke, each arc fills its ring to the next letter's spoke,
/// the short way round; then the pen steps out one ring and continues from
/// that spoke, until the phrase is complete. An exact half-turn goes
/// clockwise. A doubled letter (no travel) leaves a short notch on its spoke
/// before stepping out, so the repeat stays visible. This system is IGNOSIS's
/// own (after the user's hand-drawn wheel), not a historical method.
class RingCipherEngine {
  /// Spokes in clockwise order.
  static const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ,.';

  static int get spokeCount => alphabet.length;

  /// Angle between neighbouring spokes.
  static double get step => 2 * math.pi / spokeCount;

  /// Screen angle of spoke [i] (0 = 3 o'clock, clockwise positive). The top
  /// falls between G and H, which puts A just above 9 o'clock and N just
  /// above 3 o'clock, as on the drawn wheel.
  static double spokeAngle(int i) => -math.pi / 2 + (i - 6.5) * step;

  /// The cipher letters of [raw]: A–Z plus ',' and '.', in order; spaces and
  /// anything else are skipped.
  static String cipherText(String raw) => raw.toUpperCase().split('').where(alphabet.contains).join();

  /// Signed spoke steps from [from] to [to], the short way (+ clockwise);
  /// an exact half-turn goes clockwise.
  static int shortestSteps(int from, int to) {
    final n = spokeCount;
    final cw = ((to - from) % n + n) % n;
    return cw <= n / 2 ? cw : cw - n;
  }

  /// Arcs for [text]: one per consecutive letter pair, on rings 0, 1, 2, …
  /// A single letter has no next letter: it leaves one notch on ring 0.
  static List<RingArc> arcsFor(String text) => [
        if (text.length == 1) RingArc(0, alphabet.indexOf(text[0]), alphabet.indexOf(text[0]), 0),
        for (var k = 0; k + 1 < text.length; k++)
          () {
            final a = alphabet.indexOf(text[k]), b = alphabet.indexOf(text[k + 1]);
            return RingArc(k, a, b, shortestSteps(a, b) * step);
          }(),
      ];

  RingCipherSigil build(IntentKernel kernel, Size size) {
    final text = cipherText(kernel.rawIntent);
    final arcs = arcsFor(text);
    final center = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) * 0.40;
    final inner = outer * 0.10;
    // Rings share the disc between the hub and the rim, but a short phrase
    // stays compact near the centre rather than in a few very fat bands.
    final spacing = arcs.isEmpty ? outer * 0.05 : math.min((outer - inner) / arcs.length, outer * 0.06);

    final strokes = <SigilStroke>[];
    for (final a in arcs) {
      final r = inner + (a.ring + 0.5) * spacing;
      final rect = Rect.fromCircle(center: center, radius: r);
      final start = spokeAngle(a.from);
      final path = Path();
      if (a.sweep == 0) {
        // Doubled letter: a short notch centred on the spoke.
        path.addArc(rect, start - step * 0.18, step * 0.36);
      } else {
        path.addArc(rect, start, a.sweep);
      }
      strokes.add(SigilStroke(path));
    }
    return RingCipherSigil(
      text: text,
      arcs: arcs,
      center: center,
      innerRadius: inner,
      outerRadius: outer,
      spacing: spacing,
      geometry: SigilGeometry(strokes: strokes),
    );
  }
}
