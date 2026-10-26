import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../geometry/sigil_geometry.dart';
import '../../motion/easing.dart';
import '../../motion/noise.dart';
import 'scene.dart';

/// Sumi-e brush rendering for sigil strokes (the look of a painted
/// "celestial brush" stroke rather than a uniform pen line).
///
/// The brush is still driven by the stroke's mathematics:
/// - width follows a calligraphic pressure profile along the arc: the brush
///   presses in (tome, with a small swell), runs a living belly and sweeps out
///   (harai); terminal crossbars flick (hane) and start circles close like an
///   ensō;
/// - the belly thins where the minimum-jerk pen moves fastest, so the same
///   velocity curve that writes the stroke also shapes it;
/// - dry-brush streaks (kasure) open up as the ink load runs out along the
///   stroke; edges pool darker and bleed softly into the paper; a few droplets
///   splatter where the brush lands.
/// Everything is seeded from the stroke's own geometry, so the same sigil is
/// always painted the same way.
class BrushStroke {
  BrushStroke._(this.stroke, this._contours, this.seed);

  /// Brush data for [stroke], computed once per stroke and cached.
  factory BrushStroke.of(SigilStroke stroke) => _cache[stroke] ??= BrushStroke._build(stroke);

  static final _cache = Expando<BrushStroke>('brush');

  final SigilStroke stroke;
  final List<_Contour> _contours;
  final int seed;

  /// Sample spacing along the stroke, in scene units.
  static const _spacing = 1.6;

  factory BrushStroke._build(SigilStroke stroke) {
    final contours = <_Contour>[];
    var seed = 0x2545F491;
    for (final m in stroke.path.computeMetrics()) {
      if (m.length <= 0) continue;
      final n = math.max(2, (m.length / _spacing).ceil());
      final pts = <Offset>[], normals = <Offset>[];
      for (var i = 0; i <= n; i++) {
        final t = m.getTangentForOffset(m.length * i / n);
        if (t == null) continue;
        pts.add(t.position);
        normals.add(Offset(-t.vector.dy, t.vector.dx));
      }
      if (pts.length < 2) continue;
      // Stable seed from the geometry (no hashCode, which varies per run).
      seed = (seed * 31 + (pts.first.dx * 7 + pts.first.dy * 13 + m.length).round()) & 0x7FFFFFFF;
      // A calligrapher re-presses the brush at a sharp turn: split the contour
      // there, so each segment gets its own landing, belly and release (and a
      // polyline's outline never folds over itself at a corner).
      var start = 0;
      for (var i = 1; i < pts.length - 1; i++) {
        final a = normals[i - 1], b = normals[i + 1];
        final cos = a.dx * b.dx + a.dy * b.dy;
        if (cos < 0.8 && i - start >= 2) {
          contours.add(_segment(pts, normals, start, i));
          start = i;
        }
      }
      contours.add(_segment(pts, normals, start, pts.length - 1, closed: start == 0 && m.isClosed));
    }
    return BrushStroke._(stroke, contours, seed);
  }

  static _Contour _segment(List<Offset> pts, List<Offset> normals, int from, int to, {bool closed = false}) {
    final p = pts.sublist(from, to + 1);
    var length = 0.0;
    for (var i = 1; i < p.length; i++) {
      length += (p[i] - p[i - 1]).distance;
    }
    return _Contour(p, normals.sublist(from, to + 1), length, closed);
  }

  /// Pressure (width factor, 0..~1.1) at arc fraction [u] of a contour.
  double _pressure(double u, int contourSeed) {
    final role = stroke.role;
    // Minimum-jerk speed at this point of the stroke (0 at rest, 1.875 peak):
    // the brush lifts slightly as the hand speeds up.
    final speed = minimumJerkVelocity(inverseMinimumJerk(u)) / 1.875;
    final belly = 0.9 + 0.1 * (valueNoise3(u * 5, 0.3, 0, contourSeed) * 2 - 1);
    double attack, release;
    switch (role) {
      case StrokeRole.terminal:
        // Hane: a firm press and a quick flick.
        attack = 0.55 + 0.6 * _smooth(0, 0.18, u);
        release = math.pow(1 - _smooth(0.45, 1, u), 1.4).toDouble();
      case StrokeRole.startMark:
        // Ensō: heavy at the start, thinning as it comes round.
        attack = 0.7 + 0.45 * _smooth(0, 0.1, u);
        release = 0.25 + 0.75 * (1 - _smooth(0.55, 1, u));
      case StrokeRole.binding:
        attack = 0.5 + 0.5 * _smooth(0, 0.05, u);
        release = math.pow(1 - _smooth(0.82, 1, u), 0.9).toDouble();
      case StrokeRole.ink:
        // Tome: the brush lands, swells, then runs; harai: a long sweep out.
        final swell = 0.18 * hannPulse(u / 0.12);
        attack = 0.5 + 0.55 * _smooth(0, 0.07, u) + swell;
        release = math.pow(1 - _smooth(0.72, 1, u), 0.85).toDouble();
    }
    return math.max(0.04, attack * release * belly * (1 - 0.22 * speed));
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Number of brush segments (contours split at sharp turns).
  @visibleForTesting
  int get segmentCount => _contours.length;

  /// Pressure at arc fraction [u] of segment [segment], for tests.
  @visibleForTesting
  double pressureAt(double u, {int segment = 0}) => _pressure(u, (seed + segment * 7919) & 0x7FFFFFFF);

  /// Paints the first [fraction] of the stroke (by arc length) with a brush
  /// of nominal width [width] (scene units).
  void paint(Canvas canvas, SceneStyle style, double fraction, double width, {double opacity = 1}) {
    if (fraction <= 0 || _contours.isEmpty) return;
    final total = _contours.fold(0.0, (s, c) => s + c.length);
    var remaining = total * fraction.clamp(0.0, 1.0);
    for (var ci = 0; ci < _contours.length; ci++) {
      if (remaining <= 0) break;
      final c = _contours[ci];
      final f = (remaining / c.length).clamp(0.0, 1.0);
      remaining -= c.length;
      _paintContour(canvas, style, c, ci, f, width, opacity);
    }
  }

  void _paintContour(Canvas canvas, SceneStyle style, _Contour c, int ci, double f, double width, double opacity) {
    final cSeed = (seed + ci * 7919) & 0x7FFFFFFF;
    final n = c.points.length;
    final upto = math.max(2, (f * (n - 1)).round() + 1);
    final key = (cSeed, upto, width);
    // Completed contours reuse their outline; the one being written is rebuilt.
    final shape = c.cacheKey == key ? c.cached! : _outline(c, cSeed, upto, width, f);
    if (upto == n) {
      c.cacheKey = key;
      c.cached = shape;
    }

    final ink = style.ink;
    final a = ink.a * opacity;
    // 1. Bleed: a soft halo where the ink wicks into the paper fibres.
    canvas.drawPath(
      shape.body,
      Paint()
        ..color = ink.withValues(alpha: a * (style.washOpacity * 2.2).clamp(0.08, 0.5))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, style.px(2.2)),
    );
    // 2. Body: slightly translucent sumi.
    canvas.drawPath(shape.body, Paint()..color = ink.withValues(alpha: a * 0.9));
    // 3. Pooled edge: ink gathers darker where the brush hair meets paper.
    canvas.drawPath(
      shape.body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.px(0.7)
        ..strokeJoin = StrokeJoin.round
        ..color = ink.withValues(alpha: a),
    );
    // 4. Kasure: paper showing through where bristles ran dry.
    if (shape.streaks != null) {
      canvas.drawPath(
        shape.streaks!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(style.px(0.6), width * 0.07)
          ..color = style.paper.withValues(alpha: 0.85 * opacity),
      );
    }
    // 5. Splatter where the brush landed.
    for (final d in shape.droplets) {
      canvas.drawCircle(d.$1, d.$2, Paint()..color = ink.withValues(alpha: a * 0.85));
    }
  }

  _Shape _outline(_Contour c, int cSeed, int upto, double width, double f) {
    final pts = c.points, nrm = c.normals;
    final n = pts.length;
    final left = <Offset>[], right = <Offset>[];
    final widths = <double>[];
    for (var i = 0; i < upto; i++) {
      final u = i / (n - 1);
      final w = width * _pressure(u, cSeed);
      widths.add(w);
      left.add(pts[i] + nrm[i] * (w / 2));
      right.add(pts[i] - nrm[i] * (w / 2));
    }
    final body = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      body.lineTo(p.dx, p.dy);
    }
    // Round the wet tip of the stroke being written.
    final tip = pts[upto - 1];
    body.arcToPoint(right.last, radius: Radius.circular(math.max(0.1, widths.last / 2)));
    for (final p in right.reversed.skip(1)) {
      body.lineTo(p.dx, p.dy);
    }
    body.close();
    // Round landing of the brush.
    body.addOval(Rect.fromCircle(center: pts.first, radius: widths.first / 2));
    if (upto < n) body.addOval(Rect.fromCircle(center: tip, radius: widths.last / 2));

    // Kasure: a few bristles lose ink along the stroke and break up.
    Path? streaks;
    if (stroke.role != StrokeRole.startMark && c.length > 40) {
      final rnd = SeededRandom(cSeed);
      streaks = Path();
      const bristles = 5;
      for (var b = 0; b < bristles; b++) {
        // Bristles run dry toward the edges of the brush, not down its middle.
        final side = rnd.nextDouble() < 0.5 ? -1.0 : 1.0;
        final offset = side * rnd.range(0.2, 0.42);
        final dryFrom = rnd.range(0.55, 0.85); // where this bristle starts running dry
        final grain = rnd.range(2.0, 5.0);
        var drawing = false;
        for (var i = 0; i < upto; i++) {
          final u = i / (n - 1);
          final dryness = ((u - dryFrom) / (1 - dryFrom)).clamp(0.0, 1.0);
          final gap = valueNoise3(u * c.length / (grain * 6), b * 3.1, 0, cSeed) < 0.25 + 0.55 * dryness;
          final on = dryness > 0 && widths[i] > width * 0.25 && gap;
          final p = pts[i] + nrm[i] * (widths[i] * offset);
          if (on && !drawing) {
            streaks.moveTo(p.dx, p.dy);
            drawing = true;
          } else if (on) {
            streaks.lineTo(p.dx, p.dy);
          } else {
            drawing = false;
          }
        }
      }
    }

    // Splatter: 2–5 droplets thrown forward and aside where the brush lands.
    final droplets = <(Offset, double)>[];
    if (stroke.role == StrokeRole.ink || stroke.role == StrokeRole.startMark) {
      final rnd = SeededRandom(cSeed ^ 0x5bd1e995);
      final count = 2 + (rnd.nextDouble() * 4).floor();
      final dir = (pts[math.min(4, n - 1)] - pts.first);
      final d = dir.distance == 0 ? const Offset(1, 0) : dir / dir.distance;
      final side = Offset(-d.dy, d.dx);
      for (var k = 0; k < count; k++) {
        final along = rnd.range(-0.6, 1.4) * width;
        final across = rnd.range(-1.6, 1.6) * width;
        droplets.add((pts.first + d * along + side * across, rnd.range(0.08, 0.22) * width));
      }
    }
    return _Shape(body, streaks, droplets);
  }
}

class _Contour {
  _Contour(this.points, this.normals, this.length, this.closed);

  final List<Offset> points;
  final List<Offset> normals;
  final double length;
  final bool closed;
  (int, int, double)? cacheKey;
  _Shape? cached;
}

class _Shape {
  _Shape(this.body, this.streaks, this.droplets);

  final Path body;
  final Path? streaks;
  final List<(Offset, double)> droplets;
}

/// Paints strokes with the brush, each revealed to its fraction.
void paintBrushStrokes(Canvas canvas, SceneStyle style, List<SigilStroke> strokes, List<double> fractions,
    {double opacity = 1}) {
  final width = style.brushWidth;
  for (var i = 0; i < strokes.length && i < fractions.length; i++) {
    if (fractions[i] <= 0) continue;
    BrushStroke.of(strokes[i]).paint(canvas, style, fractions[i], width, opacity: opacity);
  }
}
