import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../geometry/sigil_geometry.dart';
import '../models/intent_kernel.dart';
import '../motion/det_math.dart';

/// The window of the complex plane shown on the plate: centre ([cx], [cy])
/// and half the width of the visible square. The home view depends on the
/// set ([JuliaParams.home]); a null view means home.
@immutable
class InfiniteView {
  const InfiniteView(this.cx, this.cy, this.halfWidth);

  final double cx;
  final double cy;
  final double halfWidth;

  /// Deepest zoom: past this, doubles can no longer tell neighbouring pixels apart.
  static const minHalfWidth = 1e-11;

  /// How many times deeper than [home].
  double magnificationFrom(InfiniteView home) => home.halfWidth / halfWidth;

  @override
  bool operator ==(Object other) =>
      other is InfiniteView && other.cx == cx && other.cy == cy && other.halfWidth == halfWidth;

  @override
  int get hashCode => Object.hash(cx, cy, halfWidth);

  @override
  String toString() => 'InfiniteView($cx, $cy, $halfWidth)';
}

/// The constant of the quadratic map z ↦ z² + c, chosen by the intent.
///
/// c is drawn from the SHA-256 of the intent and accepted only on the edge of
/// the Mandelbrot set, outside its main cardioid: its own orbit stays bounded
/// (so the Julia set is connected), a point within [edgeDistance] of it
/// escapes (so the set is intricate), and it lies in a bulb or filament, not
/// the cardioid, whose Julia sets are smooth, nearly round curves (so the set
/// has pinches, spirals and branches). Otherwise the digest is re-hashed,
/// deterministically, as Cyber Chaos does with its seeds.
@immutable
class JuliaParams {
  const JuliaParams(this.cx, this.cy);

  final double cx;
  final double cy;

  static const edgeDistance = 0.004;
  static const _orbit = 600;

  /// Fallback (never needed in practice): the Douady rabbit.
  static const rabbit = JuliaParams(-0.1226, 0.7449);

  static final _memo = <String, JuliaParams>{};

  factory JuliaParams.fromKernel(IntentKernel kernel) {
    final hit = _memo[kernel.normalized];
    if (hit != null) return hit;
    if (_memo.length > 64) _memo.clear();
    var d = sha256.convert(utf8.encode('infinite:${kernel.normalized}')).bytes;
    for (var attempt = 0; attempt < 400; attempt++) {
      final cr = -2.0 + 2.5 * ((d[0] << 8) | d[1]) / 65536;
      final ci = -1.15 + 2.3 * ((d[2] << 8) | d[3]) / 65536;
      if (!inMainCardioid(cr, ci) && onEdge(cr, ci)) return _memo[kernel.normalized] = JuliaParams(cr, ci);
      d = sha256.convert(d).bytes;
    }
    return _memo[kernel.normalized] = rabbit;
  }

  /// True inside the main cardioid, where z² + c has an attracting fixed
  /// point (|μ| < 1, μ = 1 − √(1 − 4c)), or near its rim (|μ| < 1.05): there
  /// escape is so slow that a finite orbit test cannot tell inside from out,
  /// and the sets are smooth, nearly round curves.
  static bool inMainCardioid(double cr, double ci) {
    final (sr, si) = InfiniteEngine.csqrt(1 - 4 * cr, -4 * ci);
    final mr = 1 - sr, mi = -si;
    return mr * mr + mi * mi < 1.05 * 1.05;
  }

  /// True when the orbit of 0 under z² + c stays bounded for [n] steps.
  static bool bounded(double cr, double ci, [int n = _orbit]) {
    var x = 0.0, y = 0.0;
    for (var k = 0; k < n; k++) {
      final x2 = x * x, y2 = y * y;
      if (x2 + y2 > 4) return false;
      y = 2 * x * y + ci;
      x = x2 - y2 + cr;
    }
    return true;
  }

  /// In the Mandelbrot set, with a neighbour within [edgeDistance] outside it.
  static bool onEdge(double cr, double ci) {
    if (!bounded(cr, ci)) return false;
    const e = edgeDistance;
    for (final (dx, dy) in const [(e, 0.0), (-e, 0.0), (0.0, e), (0.0, -e), (e, e), (-e, -e), (e, -e), (-e, e)]) {
      if (!bounded(cr + dx, ci + dy)) return true;
    }
    return false;
  }

  static final _homes = <JuliaParams, double>{};

  /// Half-width of the view that frames the outermost ring with a margin.
  double get homeHalfWidth => _homes[this] ??= _frameOuterRing();

  double _frameOuterRing() {
    var rMax = 0.0;
    const rays = 72;
    for (var k = 0; k < rays; k++) {
      final (s, co) = detSinCos(2 * math.pi * k / rays);
      // G grows outward along a ray from far inside: bisect for G = G₀.
      var lo = 0.0, hi = 4.0;
      for (var it = 0; it < 30; it++) {
        final mid = (lo + hi) / 2;
        if (InfiniteEngine.green(mid * co, mid * s, this, 60) < InfiniteEngine.g0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      rMax = math.max(rMax, hi);
    }
    return rMax * 1.08;
  }

  /// The whole set, as the seal is first written.
  InfiniteView get home => InfiniteView(0, 0, homeHalfWidth);

  @override
  bool operator ==(Object other) => other is JuliaParams && other.cx == cx && other.cy == cy;

  @override
  int get hashCode => Object.hash(cx, cy);

  @override
  String toString() => 'c = ${cx.toStringAsFixed(4)} ${cy < 0 ? '−' : '+'} ${cy.abs().toStringAsFixed(4)}i';
}

/// A built Infinite sigil.
class InfiniteSigil {
  InfiniteSigil({
    required this.params,
    required this.view,
    required this.inverted,
    required this.center,
    required this.radius,
    required this.geometry,
    required this.strokeLevels,
    required this.points,
  });

  final JuliaParams params;
  final InfiniteView view;

  /// Drawn by the inverse map z ↦ ±√(z − c) instead of the forward contours.
  final bool inverted;
  final Offset center;

  /// Plate radius in canvas units: the view's half-width maps onto it.
  final double radius;

  /// Forward: the contours, outermost level first. Inverted: the points as
  /// short marks, for the burn.
  final SigilGeometry geometry;

  /// Forward only: the level of each stroke, 0 = outermost.
  final List<int> strokeLevels;

  /// Inverted only: interleaved x, y canvas points, shallowest preimages first.
  final Float32List points;

  int get pointCount => points.length ~/ 2;
}

/// The Infinite: the Julia set of z ↦ z² + c, with c chosen by the intent.
///
/// Forward, the plate shows equipotentials of the set's Green's function
/// G(z) = lim log|zₙ| / 2ⁿ at the levels G₀/√2ᵏ. Because G(z² + c) = 2·G(z),
/// every second curve is exactly the preimage of the curve two outside it:
/// the pen writes inward ring by ring, each pulled back through the map,
/// closing on a boundary it never reaches.
///
/// Inverted, the set itself is drawn by the square roots: starting from the
/// repelling fixed point (which lies on the Julia set), every point is
/// replaced by its two preimages ±√(z − c), depth by depth.
///
/// Both use only +, −, × , ÷, √ and the deterministic log, so a view renders
/// identically on every platform.
class InfiniteEngine {
  /// Outermost equipotential level (a near-circle of radius about 1.5).
  static const g0 = 0.35;
  static const levels = 12;

  /// The home view starts this many levels in: the first rings are nearly
  /// circles and say little about the set.
  static const homeLevelOffset = 2;

  /// Each level is the one outside it divided by √2, so every second ring is
  /// exactly the preimage of the ring two outside it.
  static double level(int k) => g0 / math.pow(math.sqrt2, k);
  static const escapeRadius2 = 1e6;
  static const gridResolution = 320;

  InfiniteSigil build(IntentKernel kernel, Size size, {InfiniteView? view, bool inverted = false}) {
    final params = JuliaParams.fromKernel(kernel);
    view ??= params.home;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.44;
    if (kernel.isEmpty) {
      return InfiniteSigil(
        params: params,
        view: view,
        inverted: inverted,
        center: center,
        radius: radius,
        geometry: SigilGeometry.empty,
        strokeLevels: const [],
        points: Float32List(0),
      );
    }
    return inverted ? _inverse(params, view, center, radius) : _forward(params, view, center, radius);
  }

  /// Canvas position of the complex number (re, im) in [view].
  static Offset toCanvas(double re, double im, InfiniteView view, Offset center, double radius) =>
      Offset(center.dx + (re - view.cx) / view.halfWidth * radius, center.dy - (im - view.cy) / view.halfWidth * radius);

  /// The complex number shown at canvas point [p] in [view].
  static (double, double) toComplex(Offset p, InfiniteView view, Offset center, double radius) =>
      (view.cx + (p.dx - center.dx) / radius * view.halfWidth, view.cy - (p.dy - center.dy) / radius * view.halfWidth);

  /// G(z) for one point, or 0 if it has not escaped within [maxIter].
  static double green(double zr, double zi, JuliaParams c, int maxIter) {
    var x = zr, y = zi;
    for (var n = 0; n < maxIter; n++) {
      final x2 = x * x, y2 = y * y;
      final m = x2 + y2;
      if (m > escapeRadius2) {
        // log|z| / 2ⁿ = ½·log|z|² / 2ⁿ. A double base: the int 2ⁿ wraps to 0
        // past n = 63 on native platforms (but not on the web).
        return 0.5 * detLog(m) / math.pow(2.0, n);
      }
      y = 2 * x * y + c.cy;
      x = x2 - y2 + c.cx;
    }
    return 0;
  }

  InfiniteSigil _forward(JuliaParams c, InfiniteView view, Offset center, double radius) {
    const n = gridResolution;
    final h = 2 * view.halfWidth / n;
    // Levels G₀/2ᵏ, starting at the first one inside the view: a zoomed view
    // continues the same family of curves deeper in.
    final values = Float64List((n + 1) * (n + 1));
    // Enough iterations to resolve the deepest level drawn (G ≥ log(R)/2ⁿ).
    final kStart = _firstVisibleLevel(c, view, c.home);
    final gMin = level(kStart + levels);
    // detLog, not dart:math: these choose integers that change the drawing.
    final maxIter = (detLog(0.5 * detLog(escapeRadius2) / gMin) / math.ln2).ceil() + 4;
    for (var j = 0; j <= n; j++) {
      final im = view.cy + view.halfWidth - j * h;
      for (var i = 0; i <= n; i++) {
        final re = view.cx - view.halfWidth + i * h;
        final g = green(re, im, c, maxIter);
        values[j * (n + 1) + i] = g;
      }
    }

    final strokes = <SigilStroke>[];
    final strokeLevels = <int>[];
    final minLength = radius * 0.02;
    for (var k = 0; k < levels; k++) {
      final lines = _contours(values, n, level(kStart + k), (i, j) {
        // Grid point (i, j) on the canvas.
        return Offset(center.dx - radius + i / n * 2 * radius, center.dy - radius + j / n * 2 * radius);
      }, center, radius);
      lines.sort((a, b) => b.length.compareTo(a.length));
      for (final line in lines) {
        final stroke = SigilStroke(line.path);
        if (stroke.length < minLength) continue;
        strokes.add(stroke);
        strokeLevels.add(k);
      }
    }
    return InfiniteSigil(
      params: c,
      view: view,
      inverted: false,
      center: center,
      radius: radius,
      geometry: SigilGeometry(strokes: strokes),
      strokeLevels: strokeLevels,
      points: Float32List(0),
    );
  }

  /// The first k whose level G₀/2ᵏ lies below the largest G inside the view,
  /// so the outermost ring drawn is the first one that can appear in it.
  static int _firstVisibleLevel(JuliaParams c, InfiniteView view, InfiniteView home) {
    if (view.halfWidth >= home.halfWidth) return homeLevelOffset;
    var gMax = 0.0;
    const probe = 12;
    for (var j = 0; j <= probe; j++) {
      for (var i = 0; i <= probe; i++) {
        final re = view.cx + view.halfWidth * (2 * i / probe - 1);
        final im = view.cy + view.halfWidth * (2 * j / probe - 1);
        gMax = math.max(gMax, green(re, im, c, 200));
      }
    }
    if (gMax <= 0) return homeLevelOffset;
    // The first k with G₀/√2ᵏ ≤ gMax.
    final k = (2 * detLog(g0 / gMax) / math.ln2).ceil();
    return k < homeLevelOffset ? homeLevelOffset : k;
  }

  /// Contour lines of [values] at [level], clipped to the plate, as polylines.
  /// Crossings are computed once per grid edge and chained by edge, so
  /// neighbouring cells share exact endpoints.
  static List<_Polyline> _contours(
    Float64List values,
    int n,
    double level,
    Offset Function(double i, double j) at,
    Offset center,
    double radius,
  ) {
    final w = n + 1;
    double v(int i, int j) => values[j * w + i] - level;
    // Edge ids: horizontal (i,j)–(i+1,j) = 2·(j·w + i); vertical (i,j)–(i,j+1) = 2·(j·w + i) + 1.
    final crossing = <int, Offset>{};
    Offset point(int id) => crossing[id] ??= () {
          final base = id >> 1, i = base % w, j = base ~/ w;
          final (i1, j1) = id.isEven ? (i + 1, j) : (i, j + 1);
          final a = v(i, j), b = v(i1, j1);
          final t = (a - b).abs() < 1e-300 ? 0.5 : a / (a - b);
          return at(i + (i1 - i) * t, j + (j1 - j) * t);
        }();
    final links = <int, List<int>>{};
    void link(int e1, int e2) {
      (links[e1] ??= []).add(e2);
      (links[e2] ??= []).add(e1);
    }

    final r2 = radius * radius;
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        // Only cells on the plate.
        final mid = at(i + 0.5, j + 0.5) - center;
        if (mid.distanceSquared > r2) continue;
        final a = v(i, j) > 0, b = v(i + 1, j) > 0, cc = v(i + 1, j + 1) > 0, d = v(i, j + 1) > 0;
        final top = 2 * (j * w + i), bottom = 2 * ((j + 1) * w + i);
        final left = 2 * (j * w + i) + 1, right = 2 * (j * w + i + 1) + 1;
        final edges = <int>[
          if (a != b) top,
          if (b != cc) right,
          if (cc != d) bottom,
          if (d != a) left,
        ];
        if (edges.length == 2) {
          link(edges[0], edges[1]);
        } else if (edges.length == 4) {
          // Saddle: the cell centre decides which corners connect.
          final centre = (v(i, j) + v(i + 1, j) + v(i + 1, j + 1) + v(i, j + 1)) / 4 > 0;
          if (centre == a) {
            link(top, right);
            link(bottom, left);
          } else {
            link(top, left);
            link(right, bottom);
          }
        }
      }
    }

    // Walk the links into polylines: open chains from their ends first, then loops.
    final lines = <_Polyline>[];
    final used = <int>{};
    List<int> walk(int start) {
      final chain = [start];
      used.add(start);
      var prev = -1, cur = start;
      while (true) {
        final next = links[cur]!.where((e) => e != prev && !used.contains(e)).firstOrNull;
        if (next == null) {
          // Closed loop: back to the start.
          if (links[cur]!.contains(start) && chain.length > 2) chain.add(start);
          return chain;
        }
        chain.add(next);
        used.add(next);
        prev = cur;
        cur = next;
      }
    }

    final ids = links.keys.toList()..sort();
    for (final id in ids) {
      if (!used.contains(id) && links[id]!.length == 1) lines.add(_Polyline([for (final e in walk(id)) point(e)]));
    }
    for (final id in ids) {
      if (!used.contains(id)) lines.add(_Polyline([for (final e in walk(id)) point(e)]));
    }
    return lines;
  }

  InfiniteSigil _inverse(JuliaParams c, InfiniteView view, Offset center, double radius) {
    // The repelling fixed point z* = (1 + √(1 − 4c)) / 2, with |2z*| > 1,
    // lies on the Julia set; its preimages fill it.
    var (sr, si) = csqrt(1 - 4 * c.cx, -4 * c.cy);
    var zr = (1 + sr) / 2, zi = si / 2;
    if (4 * (zr * zr + zi * zi) <= 1) {
      zr = (1 - sr) / 2;
      zi = -si / 2;
    }
    // Deeper views need more preimages to stay dense.
    final extra = (detLog(view.magnificationFrom(c.home)) / math.ln2).clamp(0, 3).round();
    final depth = 15 + extra;
    var frontier = Float64List.fromList([zr, zi]);
    final xs = <double>[];
    final r2 = radius * radius;
    void keep(double re, double im) {
      final p = toCanvas(re, im, view, center, radius);
      if ((p - center).distanceSquared <= r2) {
        xs
          ..add(p.dx)
          ..add(p.dy);
      }
    }

    keep(zr, zi);
    for (var d = 0; d < depth; d++) {
      final next = Float64List(frontier.length * 2);
      for (var k = 0; k < frontier.length; k += 2) {
        final (qr, qi) = csqrt(frontier[k] - c.cx, frontier[k + 1] - c.cy);
        next[2 * k] = qr;
        next[2 * k + 1] = qi;
        next[2 * k + 2] = -qr;
        next[2 * k + 3] = -qi;
        keep(qr, qi);
        keep(-qr, -qi);
      }
      frontier = next;
    }
    final points = Float32List.fromList(xs);

    // The burn reads ink as geometry: a sample of the points as short marks.
    final marks = Path();
    final count = points.length ~/ 2;
    final step = math.max(1, count ~/ 3000);
    final dot = radius * 0.004;
    for (var k = 0; k < count; k += step) {
      final p = Offset(points[2 * k], points[2 * k + 1]);
      marks
        ..moveTo(p.dx - dot, p.dy)
        ..lineTo(p.dx + dot, p.dy);
    }
    return InfiniteSigil(
      params: c,
      view: view,
      inverted: true,
      center: center,
      radius: radius,
      geometry: count == 0 ? SigilGeometry.empty : SigilGeometry(strokes: [SigilStroke(marks)]),
      strokeLevels: const [],
      points: points,
    );
  }

  /// Principal square root of a + bi, from real square roots only (exactly
  /// rounded on every platform).
  static (double, double) csqrt(double a, double b) {
    final m = math.sqrt(a * a + b * b);
    final re = math.sqrt((m + a) / 2);
    final im = math.sqrt((m - a) / 2);
    return (re, b < 0 ? -im : im);
  }
}

class _Polyline {
  _Polyline(this.points);

  final List<Offset> points;

  late final double length = () {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += (points[i] - points[i - 1]).distance;
    }
    return sum;
  }();

  Path get path {
    final p = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      p.lineTo(points[i].dx, points[i].dy);
    }
    return p;
  }
}
