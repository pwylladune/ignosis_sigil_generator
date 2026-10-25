import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'sigil_geometry.dart';

/// The ignition-distance field for the burn, baked once on the CPU.
///
/// `d(x)` is how far a flame must travel to reach x: it ignites at the end of
/// the last stroke written, runs backward along the ink by arc length (reverse
/// ductus), and spreads across the paper from wherever it is. It is the
/// minimum over ink samples of `s(p) + κ·|x − p|`, propagated over a grid with
/// a two-pass chamfer transform. Ink is the fuse: with κ = [paperResistance]
/// the flame races along the strokes faster than it creeps over bare paper.
class BurnField {
  BurnField._(this.resolution, this.size, this.values, this.samples, this.sampleDistances);

  final int resolution;
  final Size size;

  /// Row-major normalised distances in [0, 1].
  final Float32List values;

  /// Ink sample points (canvas coordinates) in reverse written order …
  final List<Offset> samples;

  /// … and their normalised ignition distance along the ink.
  final Float32List sampleDistances;

  /// How much slower fire crosses bare paper than it runs along ink.
  static const paperResistance = 8.0;

  factory BurnField.compute(SigilGeometry geometry, Size size, {int resolution = 128, int maxSamples = 2400}) {
    const kappa = paperResistance;
    final strokes = geometry.strokes.reversed.where((s) => s.length > 0).toList();
    final spacing = math.max(2.0, geometry.totalLength / maxSamples);
    final samples = <Offset>[];
    final along = <double>[];
    var s = 0.0;
    for (final stroke in strokes) {
      final pts = stroke.sample(spacing).reversed.toList();
      for (var i = 0; i < pts.length; i++) {
        if (i > 0) s += (pts[i] - pts[i - 1]).distance;
        samples.add(pts[i]);
        along.add(s);
      }
    }

    final r = resolution;
    final cw = size.width / r, ch = size.height / r;
    final grid = Float64List(r * r)..fillRange(0, r * r, double.infinity);
    for (var k = 0; k < samples.length; k++) {
      final p = samples[k];
      final ci = (p.dx / cw).floor(), cj = (p.dy / ch).floor();
      for (var dj = -1; dj <= 1; dj++) {
        for (var di = -1; di <= 1; di++) {
          final i = ci + di, j = cj + dj;
          if (i < 0 || j < 0 || i >= r || j >= r) continue;
          final cx = (i + 0.5) * cw, cy = (j + 0.5) * ch;
          final v = along[k] + kappa * math.sqrt((cx - p.dx) * (cx - p.dx) + (cy - p.dy) * (cy - p.dy));
          if (v < grid[j * r + i]) grid[j * r + i] = v;
        }
      }
    }
    if (samples.isEmpty) {
      // No ink: ignite from the centre.
      grid[(r ~/ 2) * r + r ~/ 2] = 0;
    }

    // 5×5 chamfer distance propagation (forward then backward), twice. The
    // knight-move neighbours keep the fronts round rather than octagonal.
    final diag = kappa * math.sqrt(cw * cw + ch * ch);
    final k1 = kappa * math.sqrt(4 * cw * cw + ch * ch), k2 = kappa * math.sqrt(cw * cw + 4 * ch * ch);
    void relax(int i, int j, int ni, int nj, double w) {
      if (ni < 0 || nj < 0 || ni >= r || nj >= r) return;
      final v = grid[nj * r + ni] + w;
      if (v < grid[j * r + i]) grid[j * r + i] = v;
    }

    for (var round = 0; round < 2; round++) {
      for (var j = 0; j < r; j++) {
        for (var i = 0; i < r; i++) {
          relax(i, j, i - 1, j, kappa * cw);
          relax(i, j, i, j - 1, kappa * ch);
          relax(i, j, i - 1, j - 1, diag);
          relax(i, j, i + 1, j - 1, diag);
          relax(i, j, i - 2, j - 1, k1);
          relax(i, j, i + 2, j - 1, k1);
          relax(i, j, i - 1, j - 2, k2);
          relax(i, j, i + 1, j - 2, k2);
        }
      }
      for (var j = r - 1; j >= 0; j--) {
        for (var i = r - 1; i >= 0; i--) {
          relax(i, j, i + 1, j, kappa * cw);
          relax(i, j, i, j + 1, kappa * ch);
          relax(i, j, i + 1, j + 1, diag);
          relax(i, j, i - 1, j + 1, diag);
          relax(i, j, i + 2, j + 1, k1);
          relax(i, j, i - 2, j + 1, k1);
          relax(i, j, i + 1, j + 2, k2);
          relax(i, j, i - 1, j + 2, k2);
        }
      }
    }

    // Normalise over the plate (the inscribed circle) so the front sweeps 0 → 1.
    final centre = size.center(Offset.zero);
    final plateR = math.min(size.width, size.height) / 2;
    var maxD = 1e-9;
    for (var j = 0; j < r; j++) {
      for (var i = 0; i < r; i++) {
        final cx = (i + 0.5) * cw, cy = (j + 0.5) * ch;
        if ((Offset(cx, cy) - centre).distance <= plateR && grid[j * r + i] > maxD) maxD = grid[j * r + i];
      }
    }
    final values = Float32List(r * r);
    for (var k = 0; k < r * r; k++) {
      values[k] = (grid[k] / maxD).clamp(0.0, 1.0);
    }
    final sd = Float32List(along.length);
    for (var k = 0; k < along.length; k++) {
      sd[k] = (along[k] / maxD).clamp(0.0, 1.0);
    }
    return BurnField._(r, size, values, samples, sd);
  }

  /// Field value at a canvas point (nearest cell).
  double at(Offset p) {
    final i = (p.dx / size.width * resolution).floor().clamp(0, resolution - 1);
    final j = (p.dy / size.height * resolution).floor().clamp(0, resolution - 1);
    return values[j * resolution + i];
  }

  /// RGBA pixels with the distance packed as 16 bits (R high, G low).
  Uint8List toRgba() {
    final out = Uint8List(resolution * resolution * 4);
    for (var k = 0; k < values.length; k++) {
      final v = (values[k] * 65535).round().clamp(0, 65535);
      out[4 * k] = v >> 8;
      out[4 * k + 1] = v & 0xFF;
      out[4 * k + 2] = 0;
      out[4 * k + 3] = 255;
    }
    return out;
  }
}
