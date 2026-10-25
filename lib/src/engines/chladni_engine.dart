import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:crypto/crypto.dart';
import '../geometry/sigil_geometry.dart';
import '../models/intent_kernel.dart';

/// A vibration mode of a square free plate on `[−1, 1]²`:
///
///   f(x, y) = cos(nπx)·cos(mπy) + σ·cos(mπx)·cos(nπy),  σ = ±1
///
/// Sand gathers on the nodal set `f = 0`, which is the sigil.
class ChladniMode {
  const ChladniMode(this.n, this.m, this.sign);

  final int n;
  final int m;

  /// +1 (symmetric) or −1 (antisymmetric) superposition.
  final int sign;

  /// Modes with `n < m ≤ 8` and `n + m ≥ 4`, so every pattern has structure.
  static final List<(int, int)> pairs = [
    for (var n = 1; n <= 7; n++)
      for (var m = n + 1; m <= 8; m++)
        if (n + m >= 4) (n, m),
  ];

  /// Derives the mode deterministically from the reduced intent.
  factory ChladniMode.fromKernel(IntentKernel kernel) {
    final d = sha256.convert(utf8.encode('chladni:${kernel.reducedConsonants}')).bytes;
    final (n, m) = pairs[((d[0] << 8) | d[1]) % pairs.length];
    return ChladniMode(n, m, d[2].isEven ? -1 : 1);
  }

  double value(double x, double y) {
    final px = math.pi * x, py = math.pi * y;
    return math.cos(n * px) * math.cos(m * py) + sign * math.cos(m * px) * math.cos(n * py);
  }

  /// Gradient `∇f` at (x, y).
  (double, double) gradient(double x, double y) {
    final px = math.pi * x, py = math.pi * y;
    final cnx = math.cos(n * px), snx = math.sin(n * px);
    final cmx = math.cos(m * px), smx = math.sin(m * px);
    final cmy = math.cos(m * py), smy = math.sin(m * py);
    final cny = math.cos(n * py), sny = math.sin(n * py);
    final gx = -n * math.pi * snx * cmy - sign * m * math.pi * smx * cny;
    final gy = -m * math.pi * cnx * smy - sign * n * math.pi * cmx * sny;
    return (gx, gy);
  }

  @override
  bool operator ==(Object other) => other is ChladniMode && other.n == n && other.m == m && other.sign == sign;

  @override
  int get hashCode => Object.hash(n, m, sign);

  @override
  String toString() => '($n, $m, ${sign > 0 ? '+' : '−'})';
}

/// Extracts the zero level set of [f] on `[−1, 1]²` with marching squares.
///
/// Returns line segments as pairs of points in plate coordinates.
List<(Offset, Offset)> marchingSquares(double Function(double x, double y) f, {int resolution = 120}) {
  final r = resolution;
  final h = 2.0 / r;
  final values = List.generate(r + 1, (j) => List.generate(r + 1, (i) => f(-1 + i * h, -1 + j * h)));
  final segments = <(Offset, Offset)>[];

  Offset interp(double x0, double y0, double v0, double x1, double y1, double v1) {
    final t = (v0 - v1).abs() < 1e-12 ? 0.5 : v0 / (v0 - v1);
    return Offset(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
  }

  for (var j = 0; j < r; j++) {
    for (var i = 0; i < r; i++) {
      final x0 = -1 + i * h, y0 = -1 + j * h, x1 = x0 + h, y1 = y0 + h;
      final a = values[j][i], b = values[j][i + 1], c = values[j + 1][i + 1], d = values[j + 1][i];
      final edges = <Offset>[];
      if ((a > 0) != (b > 0)) edges.add(interp(x0, y0, a, x1, y0, b)); // top
      if ((b > 0) != (c > 0)) edges.add(interp(x1, y0, b, x1, y1, c)); // right
      if ((c > 0) != (d > 0)) edges.add(interp(x1, y1, c, x0, y1, d)); // bottom
      if ((d > 0) != (a > 0)) edges.add(interp(x0, y1, d, x0, y0, a)); // left
      if (edges.length == 2) {
        segments.add((edges[0], edges[1]));
      } else if (edges.length == 4) {
        // Saddle: resolve with the centre value.
        final centre = f(x0 + h / 2, y0 + h / 2);
        if ((centre > 0) == (a > 0)) {
          segments
            ..add((edges[0], edges[1]))
            ..add((edges[2], edges[3]));
        } else {
          segments
            ..add((edges[0], edges[3]))
            ..add((edges[1], edges[2]));
        }
      }
    }
  }
  return segments;
}

/// The Chladni sigil: the mode, the plate on the canvas and the nodal lines.
class ChladniSigil {
  ChladniSigil({required this.mode, required this.plate, required this.segments, required this.geometry});

  final ChladniMode mode;

  /// The plate's square on the canvas; plate coordinates map `[−1, 1]²` onto it.
  final Rect plate;

  /// Nodal segments in plate coordinates.
  final List<(Offset, Offset)> segments;
  final SigilGeometry geometry;

  Offset toCanvas(double x, double y) =>
      Offset(plate.center.dx + x * plate.width / 2, plate.center.dy + y * plate.height / 2);
}

/// Solves a square free-plate Chladni mode chosen by the intent and extracts its
/// nodal set (cached; sand physics lives in the scene).
class ChladniEngine {
  ChladniSigil build(IntentKernel kernel, Size size) {
    final side = math.min(size.width, size.height) * 0.6;
    final plate = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    if (kernel.isEmpty) {
      return ChladniSigil(mode: const ChladniMode(1, 3, -1), plate: plate, segments: const [], geometry: SigilGeometry.empty);
    }
    final mode = ChladniMode.fromKernel(kernel);
    final segments = marchingSquares(mode.value);
    final sigil = ChladniSigil(mode: mode, plate: plate, segments: segments, geometry: SigilGeometry.empty);
    final ink = Path();
    for (final (a, b) in segments) {
      final p = sigil.toCanvas(a.dx, a.dy), q = sigil.toCanvas(b.dx, b.dy);
      ink
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
    return ChladniSigil(
      mode: mode,
      plate: plate,
      segments: segments,
      geometry: SigilGeometry(strokes: [
        SigilStroke(Path()..addRect(plate), role: StrokeRole.binding),
        SigilStroke(ink),
      ]),
    );
  }
}
