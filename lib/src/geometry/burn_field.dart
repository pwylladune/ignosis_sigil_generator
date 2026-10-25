import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'sigil_geometry.dart';

/// The ignition-distance field for the burn, baked once on the CPU.
///
/// `d(x)` is how long a flame takes to reach x. It ignites at the end of the
/// last stroke written and spreads over a grid where ink costs 1 and bare
/// paper costs κ = [paperResistance] per unit length: ink is the fuse. So the
/// fire runs back along the last stroke (reverse ductus), branches wherever
/// strokes touch, and only creeps across paper to reach ink that is not
/// connected. It is a shortest-path (Dijkstra) field over a 16-neighbour
/// grid, so it depends only on where the ink is, not on how the strokes or
/// their contours happen to be grouped.
class BurnField {
  BurnField._(this.resolution, this.size, this.values, this.samples, this.sampleDistances);

  final int resolution;
  final Size size;

  /// Row-major normalised distances in [0, 1].
  final Float32List values;

  /// Ink sample points (canvas coordinates) …
  final List<Offset> samples;

  /// … and the normalised time the flame reaches each of them.
  final Float32List sampleDistances;

  /// How much slower fire crosses bare paper than it runs along ink.
  static const paperResistance = 8.0;

  static const _neighbours = [
    (1, 0), (-1, 0), (0, 1), (0, -1), //
    (1, 1), (1, -1), (-1, 1), (-1, -1),
    (2, 1), (2, -1), (-2, 1), (-2, -1),
    (1, 2), (1, -2), (-1, 2), (-1, -2),
  ];

  factory BurnField.compute(SigilGeometry geometry, Size size, {int resolution = 128}) {
    final r = resolution;
    if (size.isEmpty) {
      return BurnField._(r, size, Float32List(r * r), const [], Float32List(0));
    }
    final cw = size.width / r, ch = size.height / r;
    int cellOf(Offset p) {
      final i = (p.dx / cw).floor().clamp(0, r - 1);
      final j = (p.dy / ch).floor().clamp(0, r - 1);
      return j * r + i;
    }

    // Ink mask: sample at most half a cell apart so a stroke's cells are
    // 8-connected and the fuse has no gaps.
    final spacing = math.max(0.5, math.min(cw, ch) / 2);
    final samples = <Offset>[];
    final ink = Uint8List(r * r);
    for (final stroke in geometry.strokes) {
      if (stroke.length <= 0) continue;
      for (final p in stroke.sample(spacing)) {
        samples.add(p);
        ink[cellOf(p)] = 1;
      }
    }

    // Ignition: the end of the last stroke that has ink.
    Offset ignition = size.center(Offset.zero);
    for (final stroke in geometry.strokes.reversed) {
      final end = stroke.length > 0 ? stroke.pointAt(1) : null;
      if (end != null) {
        ignition = end;
        break;
      }
    }

    // Dijkstra over the grid.
    final dist = Float64List(r * r)..fillRange(0, r * r, double.infinity);
    final heap = _MinHeap();
    final start = cellOf(ignition);
    dist[start] = 0;
    heap.push(0, start);
    const kappa = paperResistance;
    while (heap.isNotEmpty) {
      final (d, idx) = heap.pop();
      if (d > dist[idx]) continue;
      final i = idx % r, j = idx ~/ r;
      for (final (di, dj) in _neighbours) {
        final ni = i + di, nj = j + dj;
        if (ni < 0 || nj < 0 || ni >= r || nj >= r) continue;
        final n = nj * r + ni;
        final len = math.sqrt((di * cw) * (di * cw) + (dj * ch) * (dj * ch));
        final inkA = ink[idx] == 1, inkB = ink[n] == 1;
        final cost = inkA && inkB ? 1.0 : (inkA || inkB ? (1 + kappa) / 2 : kappa);
        final nd = d + len * cost;
        if (nd < dist[n]) {
          dist[n] = nd;
          heap.push(nd, n);
        }
      }
    }

    // Normalise over the plate (the inscribed circle) so the front sweeps 0 → 1.
    final centre = size.center(Offset.zero);
    final plateR = math.min(size.width, size.height) / 2;
    var maxD = 1e-9;
    for (var j = 0; j < r; j++) {
      for (var i = 0; i < r; i++) {
        final c = Offset((i + 0.5) * cw, (j + 0.5) * ch);
        if ((c - centre).distance <= plateR && dist[j * r + i] > maxD) maxD = dist[j * r + i];
      }
    }
    final values = Float32List(r * r);
    for (var k = 0; k < r * r; k++) {
      values[k] = (dist[k] / maxD).clamp(0.0, 1.0);
    }
    final sd = Float32List(samples.length);
    for (var k = 0; k < samples.length; k++) {
      sd[k] = values[cellOf(samples[k])];
    }
    return BurnField._(r, size, values, samples, sd);
  }

  /// Field value at a canvas point (nearest cell).
  double at(Offset p) {
    if (size.isEmpty) return 0;
    final i = (p.dx / size.width * resolution).floor().clamp(0, resolution - 1);
    final j = (p.dy / size.height * resolution).floor().clamp(0, resolution - 1);
    return values[j * resolution + i];
  }

  /// RGBA pixels with the distance packed as 16 bits: v = 256·R + G over 65535.
  /// The shader decodes it as `R·65280/65535 + G·255/65535` (R, G in [0, 1]).
  Uint8List toRgba() {
    final out = Uint8List(resolution * resolution * 4);
    for (var k = 0; k < values.length; k++) {
      final v = encode(values[k]);
      out[4 * k] = v >> 8;
      out[4 * k + 1] = v & 0xFF;
      out[4 * k + 2] = 0;
      out[4 * k + 3] = 255;
    }
    return out;
  }

  static int encode(double value) => (value * 65535).round().clamp(0, 65535);

  /// Mirror of the shader's decode, for tests: R and G as sampled in [0, 1].
  static double decode(double r, double g) => r * (65280.0 / 65535.0) + g * (255.0 / 65535.0);
}

/// Binary min-heap of (priority, index) with lazy deletion.
class _MinHeap {
  final _p = <double>[];
  final _v = <int>[];

  bool get isNotEmpty => _p.isNotEmpty;

  void push(double p, int v) {
    _p.add(p);
    _v.add(v);
    var i = _p.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_p[parent] <= _p[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  (double, int) pop() {
    final top = (_p[0], _v[0]);
    final lastP = _p.removeLast(), lastV = _v.removeLast();
    if (_p.isNotEmpty) {
      _p[0] = lastP;
      _v[0] = lastV;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, rr = l + 1;
        var m = i;
        if (l < _p.length && _p[l] < _p[m]) m = l;
        if (rr < _p.length && _p[rr] < _p[m]) m = rr;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final p = _p[a];
    _p[a] = _p[b];
    _p[b] = p;
    final v = _v[a];
    _v[a] = _v[b];
    _v[b] = v;
  }
}
