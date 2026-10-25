import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../geometry/burn_field.dart';
import '../../motion/easing.dart';
import '../../motion/noise.dart';
import 'scene.dart';

/// Loads and caches the level-set burn shader. Null when unavailable (tests,
/// unsupported renderers); the burn then falls back to reverse ductus.
class CombustionShader {
  static Future<ui.FragmentProgram?>? _program;

  static Future<ui.FragmentProgram?> load() => _program ??= ui.FragmentProgram.fromAsset('assets/shaders/combustion.frag')
      .then<ui.FragmentProgram?>((p) => p)
      .catchError((Object e) {
        debugPrint('[combustion] shader unavailable, using reverse ductus: $e');
        return null;
      });
}

/// The burn: dissolves a settled scene. A pure function of time since
/// [startTime] (embers integrate forward in fixed steps).
///
/// 1. Reverse ductus: ignition at the end of the last stroke; the front runs
///    backward along the ink by arc length, then across the paper.
/// 2. Level-set front in the shader over a baked [BurnField], with a
///    blackbody rim and noise-perturbed edge.
/// 3. Embers spawn on the front and are advected by curl noise plus buoyancy,
///    so they curl like smoke instead of sliding diagonally.
class Combustion {
  Combustion({required this.scene, required this.size, required this.startTime, this.reduceMotion = false, int seed = 0})
      : _rnd = SeededRandom(seed),
        _seed = seed {
    if (reduceMotion) {
      duration = 0.8;
      return;
    }
    field = BurnField.compute(scene.geometry, size);
    // Longer sigils take a little longer to consume, within 4–7 s.
    duration = (3.5 + scene.geometry.totalLength / 2500).clamp(4.0, 7.0);
    CombustionShader.load().then((program) async {
      if (program == null || _disposed) return;
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(field!.toRgba(), field!.resolution, field!.resolution, ui.PixelFormat.rgba8888, completer.complete);
      final image = await completer.future;
      if (_disposed) {
        image.dispose();
        return;
      }
      _fieldImage = image;
      _shader = program.fragmentShader();
    });
  }

  final SigilScene scene;
  final Size size;
  final double startTime;
  final bool reduceMotion;
  final SeededRandom _rnd;
  final int _seed;

  BurnField? field;
  ui.FragmentShader? _shader;
  ui.Image? _fieldImage;
  bool _disposed = false;

  /// Releases the field texture and shader instance; a load still in flight
  /// is discarded when it completes.
  void dispose() {
    _disposed = true;
    _fieldImage?.dispose();
    _shader?.dispose();
    _fieldImage = null;
    _shader = null;
  }

  /// Burn time in seconds. Reduce-motion uses a short crossfade instead.
  late final double duration;

  /// Width of the glowing band in field units.
  static const band = 0.07;

  // Embers: x, y, vx, vy, age, life per particle.
  static const _maxEmbers = 1400;
  final _embers = Float64List(_maxEmbers * 6);
  int _emberCount = 0;
  double _emberTime = 0;
  static const _dt = 1 / 60;
  static const _emberLife = 2.2;

  /// Front position in field units: −band → 1 + 2·band with minimum-jerk pacing,
  /// so the rim fully clears the farthest point before the burn ends.
  double front(double now) => lerp(-band, 1 + band * 2, minimumJerk((now - startTime) / duration));

  bool isDone(double now) => now - startTime >= duration + (reduceMotion ? 0 : _emberLife);

  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final t = now - startTime;
    if (reduceMotion) {
      final p = (t / duration).clamp(0.0, 1.0);
      canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - p));
      scene.paint(canvas, size, double.infinity, style);
      canvas.restore();
      return;
    }

    final f = front(now);
    final shader = _shader, image = _fieldImage;
    if (shader != null && image != null) {
      scene.paint(canvas, size, double.infinity, style);
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, f)
        ..setFloat(3, band)
        ..setFloat(4, t)
        ..setFloat(5, (_seed % 1000) / 1000)
        ..setFloat(6, style.paper.r)
        ..setFloat(7, style.paper.g)
        ..setFloat(8, style.paper.b)
        ..setFloat(9, 1)
        ..setFloat(10, style.burn.r)
        ..setFloat(11, style.burn.g)
        ..setFloat(12, style.burn.b)
        ..setFloat(13, 1)
        ..setImageSampler(0, image, filterQuality: FilterQuality.low);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } else {
      // Fallback: unwrite in reverse ductus as the front passes along the ink.
      final remaining = _inkRemaining(f);
      scene.paintUnwritten(canvas, size, remaining, style);
    }
    _stepEmbers(t, f);
    _paintEmbers(canvas, style);
  }

  /// Ink length not yet reached by the front.
  double _inkRemaining(double f) {
    final fld = field;
    final total = scene.geometry.totalLength;
    if (fld == null || fld.samples.isEmpty) return total * (1 - f).clamp(0.0, 1.0);
    var burned = 0;
    for (final d in fld.sampleDistances) {
      if (d < f) burned++;
    }
    return total * (1 - burned / fld.sampleDistances.length);
  }

  void _stepEmbers(double t, double frontNow) {
    final fld = field;
    if (fld == null) return;
    var steps = ((t - _emberTime) / _dt).floor();
    if (steps > 30) steps = 30;
    for (var s = 0; s < steps; s++) {
      _emberTime += _dt;
      final f = front(startTime + _emberTime);
      // Spawn on the front: ink samples first, then paper cells in the band.
      if (f < 1 + band) {
        for (var k = 0; k < 4 && _emberCount < _maxEmbers; k++) {
          final p = _spawnPoint(fld, f);
          if (p == null) break;
          final o = _emberCount * 6;
          _embers[o] = p.dx;
          _embers[o + 1] = p.dy;
          _embers[o + 2] = 0;
          _embers[o + 3] = 0;
          _embers[o + 4] = 0;
          _embers[o + 5] = _rnd.range(0.9, _emberLife);
          _emberCount++;
        }
      }
      // Advect: v = curl ψ + buoyancy, then age and cull.
      var i = 0;
      while (i < _emberCount) {
        final o = i * 6;
        final x = _embers[o], y = _embers[o + 1];
        final (cx, cy) = curlNoise(x * 0.012, y * 0.012, _emberTime * 0.3, _seed);
        final vx = cx * 55, vy = cy * 55 - 38;
        _embers[o + 2] = vx;
        _embers[o + 3] = vy;
        _embers[o] = x + vx * _dt;
        _embers[o + 1] = y + vy * _dt;
        _embers[o + 4] += _dt;
        if (_embers[o + 4] >= _embers[o + 5]) {
          // Swap-remove.
          final last = (_emberCount - 1) * 6;
          for (var q = 0; q < 6; q++) {
            _embers[o + q] = _embers[last + q];
          }
          _emberCount--;
        } else {
          i++;
        }
      }
    }
  }

  Offset? _spawnPoint(BurnField fld, double f) {
    final inkCandidates = <int>[];
    // Ink samples near the front (cheap: probe a few at random).
    for (var tries = 0; tries < 12; tries++) {
      if (fld.samples.isEmpty) break;
      final k = (_rnd.nextDouble() * fld.samples.length).floor();
      final d = fld.sampleDistances[k];
      if (d <= f && d > f - band) inkCandidates.add(k);
    }
    if (inkCandidates.isNotEmpty) return fld.samples[inkCandidates.first];
    final centre = fld.size.center(Offset.zero);
    final r = math.min(fld.size.width, fld.size.height) / 2;
    for (var tries = 0; tries < 16; tries++) {
      final p = Offset(_rnd.range(0, fld.size.width), _rnd.range(0, fld.size.height));
      if ((p - centre).distance > r) continue;
      final d = fld.at(p);
      if (d <= f && d > f - band) return p;
    }
    return null;
  }

  void _paintEmbers(Canvas canvas, SceneStyle style) {
    if (_emberCount == 0) return;
    // Two passes: bright young sparks and dimmer, cooling ones.
    for (final young in [true, false]) {
      final pts = <double>[];
      for (var i = 0; i < _emberCount; i++) {
        final o = i * 6;
        final life = _embers[o + 4] / _embers[o + 5];
        if ((life < 0.4) != young) continue;
        pts
          ..add(_embers[o])
          ..add(_embers[o + 1]);
      }
      if (pts.isEmpty) continue;
      final paint = Paint()
        ..color = style.burn.withValues(alpha: young ? 0.85 : 0.4)
        ..strokeWidth = style.px(young ? 2.2 : 1.6)
        ..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(ui.PointMode.points, Float32List.fromList(pts), paint);
    }
  }
}
