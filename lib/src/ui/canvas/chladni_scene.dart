import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import '../../engines/chladni_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/easing.dart';
import '../../motion/noise.dart';
import 'scene.dart';

/// Chladni sand: particles start spread over the plate and descend the energy
/// `E = f²` toward the nodal lines, with a little thermal noise, the way real
/// sand migrates on a bowed plate. A new intent morphs the mode
/// `(1 − s)·f₁ + s·f₂` with minimum-jerk `s`, and the sand flows between
/// patterns. Once settled the nodal line is inked faintly and nothing moves.
class ChladniScene extends SigilScene {
  ChladniScene(this.sigil, {required super.startTime, ChladniScene? previous}) {
    final prev = previous;
    if (prev != null && prev.sigil.plate == sigil.plate && prev.sigil.mode != sigil.mode) {
      _from = prev._modeAt(double.infinity);
      _xs = Float64List.fromList(prev._xs);
      _ys = Float64List.fromList(prev._ys);
    } else {
      _from = null;
      final rnd = SeededRandom(sigil.mode.stableSeed);
      _xs = Float64List(particleCount);
      _ys = Float64List(particleCount);
      for (var i = 0; i < particleCount; i++) {
        _xs[i] = rnd.range(-1, 1);
        _ys[i] = rnd.range(-1, 1);
      }
    }
    _rnd = SeededRandom(sigil.mode.stableSeed ^ 0x5A5A5A5A);
    _simTime = 0;
  }

  final ChladniSigil sigil;
  static const particleCount = 3600;

  /// Convergence rate toward the nodal set, per second.
  static const _rate = 2.6;
  static const _dt = 1 / 60;
  static const _morphDuration = 1.6;

  /// Thermal noise: strong at first (plate struck), then a faint residue.
  static double _noise(double t) => 0.004 + 0.035 * math.exp(-t / 0.9);

  ChladniMode? _from;
  late Float64List _xs;
  late Float64List _ys;
  late SeededRandom _rnd;
  late double _simTime;
  Float32List? _points;

  @override
  SigilGeometry get geometry => sigil.geometry;

  double get _settleSim => (_from == null ? 0 : _morphDuration) + 3.2;

  @override
  bool get ownsGuides => true;

  @override
  double get settleTime => sigil.geometry.isEmpty ? 0 : _settleSim + 1.2;

  /// The (possibly morphing) mode at time [t] after start, as f and ∇f.
  ChladniMode? _modeAt(double t) => _from == null || t >= _morphDuration ? sigil.mode : null;

  void _advance(double t) {
    final target = math.min(t, _settleSim);
    // Already settled on the first look (reduced motion, or a scene shown
    // without replay): place the sand on the nodal lines directly instead of
    // simulating seconds of physics in one frame.
    if (_simTime == 0 && _from == null && target >= _settleSim) {
      _snapToNodalLines();
      return;
    }
    var steps = ((target - _simTime) / _dt).floor();
    if (steps <= 0) return;
    // Long gaps (reduced motion, backgrounding) jump straight to the end.
    if (steps > 600) steps = 600;
    final to = sigil.mode;
    final from = _from;
    for (var s = 0; s < steps; s++) {
      _simTime += _dt;
      final blend = from == null ? 1.0 : minimumJerk(_simTime / _morphDuration);
      final eps = _noise(_simTime) * math.sqrt(_dt);
      for (var i = 0; i < particleCount; i++) {
        final x = _xs[i], y = _ys[i];
        var f = to.value(x, y);
        var (gx, gy) = to.gradient(x, y);
        if (from != null && blend < 1) {
          final f0 = from.value(x, y);
          final (g0x, g0y) = from.gradient(x, y);
          f = f0 + (f - f0) * blend;
          gx = g0x + (gx - g0x) * blend;
          gy = g0y + (gy - g0y) * blend;
        }
        // Preconditioned descent of E = f²: step ≈ −f∇f / |∇f|², capped.
        final k = _rate * _dt * f / (gx * gx + gy * gy + 1.0);
        var dx = -k * gx, dy = -k * gy;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 0.04) {
          dx *= 0.04 / len;
          dy *= 0.04 / len;
        }
        _xs[i] = (x + dx + eps * _rnd.nextGaussian()).clamp(-1.0, 1.0);
        _ys[i] = (y + dy + eps * _rnd.nextGaussian()).clamp(-1.0, 1.0);
      }
    }
    _points = null;
  }

  void _snapToNodalLines() {
    final segs = sigil.segments;
    _simTime = _settleSim;
    _points = null;
    if (segs.isEmpty) return;
    final rnd = SeededRandom(sigil.mode.stableSeed ^ 0x13579BDF);
    for (var i = 0; i < particleCount; i++) {
      final (a, b) = segs[(i * segs.length) ~/ particleCount];
      final u = rnd.nextDouble();
      // A grain's width of residual scatter, as the settled simulation leaves.
      _xs[i] = (a.dx + (b.dx - a.dx) * u + 0.004 * rnd.nextGaussian()).clamp(-1.0, 1.0);
      _ys[i] = (a.dy + (b.dy - a.dy) * u + 0.004 * rnd.nextGaussian()).clamp(-1.0, 1.0);
    }
  }

  /// Mean |f| over the sand after advancing to [t]: how far it is from the
  /// nodal set (0 = every grain on a nodal line).
  @visibleForTesting
  double residualAt(double t) {
    _advance(t);
    var sum = 0.0;
    for (var i = 0; i < particleCount; i++) {
      sum += sigil.mode.value(_xs[i], _ys[i]).abs();
    }
    return sum / particleCount;
  }

  Float32List _canvasPoints() {
    final cached = _points;
    if (cached != null) return cached;
    final p = Float32List(particleCount * 2);
    final c = sigil.plate.center, hw = sigil.plate.width / 2;
    for (var i = 0; i < particleCount; i++) {
      p[2 * i] = c.dx + _xs[i] * hw;
      p[2 * i + 1] = c.dy + _ys[i] * hw;
    }
    return _points = p;
  }

  void _paintSand(Canvas canvas, SceneStyle style, double opacity) {
    final paint = Paint()
      ..color = style.ink.withValues(alpha: 0.62 * opacity)
      ..strokeWidth = style.px(1.7)
      ..strokeCap = StrokeCap.round;
    canvas.drawRawPoints(PointMode.points, _canvasPoints(), paint);
  }

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    if (sigil.geometry.isEmpty) return;
    final t = now - startTime;
    canvas.drawRect(sigil.plate, style.guidePaint());
    _advance(t.isFinite ? t : _settleSim);

    // Once the sand has found the nodal set, ink it faintly.
    final inkIn = minimumJerk((t - _settleSim + 1.0) / 1.2);
    if (inkIn > 0) {
      canvas.drawPath(sigil.geometry.strokes.last.path, style.inkPaint(opacity: 0.32 * inkIn, width: style.weight * 0.55));
    }
    _paintSand(canvas, style, 1);
  }

  @override
  void paintUnwritten(Canvas canvas, Size size, double inkLength, SceneStyle style) {
    if (sigil.geometry.isEmpty) return;
    final f = (inkLength / sigil.geometry.totalLength).clamp(0.0, 1.0);
    canvas.drawRect(sigil.plate, style.guidePaint());
    final reveal = sigil.geometry.revealLength(inkLength);
    canvas.drawPath(reveal, style.inkPaint(opacity: 0.32, width: style.weight * 0.55));
    _paintSand(canvas, style, f);
  }
}
