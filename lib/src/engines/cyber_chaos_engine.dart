import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import '../geometry/sigil_geometry.dart';
import '../models/intent_kernel.dart';

/// Parameters of a Clifford attractor:
///
///   xₙ₊₁ = sin(a·yₙ) + c·cos(a·xₙ)
///   yₙ₊₁ = sin(b·xₙ) + d·cos(b·yₙ)
class CliffordParams {
  const CliffordParams(this.a, this.b, this.c, this.d);

  final double a, b, c, d;

  /// Reads a, b, c, d ∈ [−2, 2] from 8 bytes of a digest.
  factory CliffordParams.fromDigest(List<int> bytes) {
    double p(int i) => ((bytes[2 * i] << 8) | bytes[2 * i + 1]) / 65535.0 * 4 - 2;
    return CliffordParams(p(0), p(1), p(2), p(3));
  }

  /// Largest Lyapunov exponent along the orbit, from the tangent map.
  /// Positive means chaotic (nearby orbits diverge).
  double lyapunov({int iterations = 4000, int transient = 200}) {
    var x = 0.1, y = 0.1, vx = 1.0, vy = 0.0, sum = 0.0;
    for (var i = 0; i < transient + iterations; i++) {
      final jxx = -a * c * math.sin(a * x), jxy = a * math.cos(a * y);
      final jyx = b * math.cos(b * x), jyy = -b * d * math.sin(b * y);
      final nvx = jxx * vx + jxy * vy, nvy = jyx * vx + jyy * vy;
      final nx = math.sin(a * y) + c * math.cos(a * x);
      final ny = math.sin(b * x) + d * math.cos(b * y);
      x = nx;
      y = ny;
      final len = math.sqrt(nvx * nvx + nvy * nvy);
      if (len == 0) return double.negativeInfinity;
      vx = nvx / len;
      vy = nvy / len;
      if (i >= transient) sum += math.log(len);
    }
    return sum / iterations;
  }

  /// Fraction of a 48×48 grid over the attractor's possible bounds that the
  /// orbit visits. Low fill means it collapsed onto a curve or a few points.
  double fill({int iterations = 20000}) {
    const g = 48;
    final seen = Uint8List(g * g);
    final w = 1 + c.abs(), h = 1 + d.abs();
    var x = 0.1, y = 0.1, count = 0;
    for (var i = 0; i < iterations + 100; i++) {
      final nx = math.sin(a * y) + c * math.cos(a * x);
      final ny = math.sin(b * x) + d * math.cos(b * y);
      x = nx;
      y = ny;
      if (i < 100) continue;
      final gx = ((x + w) / (2 * w) * g).floor().clamp(0, g - 1);
      final gy = ((y + h) / (2 * h) * g).floor().clamp(0, g - 1);
      if (seen[gy * g + gx] == 0) {
        seen[gy * g + gx] = 1;
        count++;
      }
    }
    return count / (g * g);
  }

  bool get isChaotic => lyapunov() > minLyapunov && fill() > minFill;

  static const minLyapunov = 0.08;
  static const minFill = 0.30;

  /// Fallback known to be chaotic, used only if every derived seed fails.
  static const fallback = CliffordParams(-1.4, 1.6, 1.0, 0.7);

  @override
  String toString() => 'Clifford(a: ${a.toStringAsFixed(3)}, b: ${b.toStringAsFixed(3)}, '
      'c: ${c.toStringAsFixed(3)}, d: ${d.toStringAsFixed(3)})';
}

/// A rendered attractor: the orbit as canvas points, folded by symmetry.
class ChaosSigil {
  ChaosSigil({required this.params, required this.points, required this.geometry, required this.attempts});

  final CliffordParams params;

  /// Interleaved x, y canvas coordinates in orbit order.
  final Float32List points;

  /// A subsampled orbit polyline, used by the burn and by exports.
  final SigilGeometry geometry;

  /// How many hash rounds it took to reach a chaotic seed (1 = first try).
  final int attempts;

  int get count => points.length ~/ 2;
}

/// Cyber Chaos: a strange attractor seeded from SHA-256 of the intent.
///
/// Seeds whose orbit is not chaotic (low Lyapunov exponent) or that collapse
/// (low fill) are rejected and the digest is re-hashed, deterministically.
class CyberChaosEngine {
  static const pointCount = 60000;

  /// Finds the first chaotic parameter set in the hash chain of the intent.
  static (CliffordParams, int) seed(IntentKernel kernel) {
    var digest = sha256.convert(utf8.encode(kernel.normalized)).bytes;
    for (var attempt = 1; attempt <= 64; attempt++) {
      final p = CliffordParams.fromDigest(digest);
      if (p.isChaotic) return (p, attempt);
      digest = sha256.convert(digest).bytes;
    }
    return (CliffordParams.fallback, 65);
  }

  ChaosSigil build(IntentKernel kernel, Size size, {int symmetryFolds = 1}) {
    if (kernel.isEmpty) {
      return ChaosSigil(params: CliffordParams.fallback, points: Float32List(0), geometry: SigilGeometry.empty, attempts: 0);
    }
    final (p, attempts) = seed(kernel);
    final raw = Float64List(pointCount * 2);
    var x = 0.1, y = 0.1;
    for (var i = 0; i < 200; i++) {
      final nx = math.sin(p.a * y) + p.c * math.cos(p.a * x);
      y = math.sin(p.b * x) + p.d * math.cos(p.b * y);
      x = nx;
    }
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < pointCount; i++) {
      final nx = math.sin(p.a * y) + p.c * math.cos(p.a * x);
      y = math.sin(p.b * x) + p.d * math.cos(p.b * y);
      x = nx;
      raw[2 * i] = x;
      raw[2 * i + 1] = y;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    // Centre on the bounding box, fold by the symmetry group, fit the plate.
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final folds = symmetryFolds < 1 ? 1 : symmetryFolds;
    var maxR = 1e-9;
    for (var i = 0; i < pointCount; i++) {
      final dx = raw[2 * i] - cx, dy = raw[2 * i + 1] - cy;
      final r = math.sqrt(dx * dx + dy * dy);
      if (r > maxR) maxR = r;
      final a = 2 * math.pi * (i % folds) / folds;
      final ca = math.cos(a), sa = math.sin(a);
      raw[2 * i] = dx * ca - dy * sa;
      raw[2 * i + 1] = dx * sa + dy * ca;
    }
    final centre = size.center(Offset.zero);
    final scale = math.min(size.width, size.height) * 0.40 / maxR;
    final points = Float32List(pointCount * 2);
    for (var i = 0; i < pointCount; i++) {
      points[2 * i] = centre.dx + raw[2 * i] * scale;
      points[2 * i + 1] = centre.dy + raw[2 * i + 1] * scale;
    }

    // The orbit as a polyline (every 60th point of the first fold), for burns.
    final orbit = Path()..moveTo(points[0], points[1]);
    for (var i = folds * 60; i < pointCount; i += folds * 60) {
      orbit.lineTo(points[2 * i], points[2 * i + 1]);
    }
    return ChaosSigil(params: p, points: points, geometry: SigilGeometry(strokes: [SigilStroke(orbit)]), attempts: attempts);
  }
}
