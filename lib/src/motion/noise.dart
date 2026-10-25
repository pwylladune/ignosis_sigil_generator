import 'dart:math' as math;

/// Small deterministic PRNG (xorshift32) that gives identical sequences on the
/// Dart VM and on the web, unlike `math.Random(seed)`.
class SeededRandom {
  SeededRandom(int seed) : _state = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  /// Seeds from the first four bytes of a digest.
  factory SeededRandom.fromBytes(List<int> bytes, [int offset = 0]) {
    var s = 0;
    for (var i = 0; i < 4; i++) {
      s = (s << 8) | (bytes[(offset + i) % bytes.length] & 0xFF);
    }
    return SeededRandom(s & 0xFFFFFFFF);
  }

  int _state;

  int nextUint32() {
    var x = _state;
    x = (x ^ (x << 13)) & 0xFFFFFFFF;
    x = (x ^ (x >> 17)) & 0xFFFFFFFF;
    x = (x ^ (x << 5)) & 0xFFFFFFFF;
    _state = x;
    return x;
  }

  /// Uniform in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform in [a, b).
  double range(double a, double b) => a + (b - a) * nextDouble();

  /// Standard normal sample (Box–Muller).
  double nextGaussian() {
    final u1 = math.max(nextDouble(), 1e-12);
    final u2 = nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

/// Smooth 3D value noise in roughly [0, 1], hashed from integer lattice points.
double valueNoise3(double x, double y, double z, [int seed = 0]) {
  final xi = x.floor(), yi = y.floor(), zi = z.floor();
  final xf = x - xi, yf = y - yi, zf = z - zi;
  final u = _fade(xf), v = _fade(yf), w = _fade(zf);
  double h(int dx, int dy, int dz) => _hash(xi + dx, yi + dy, zi + dz, seed);
  final x00 = _mix(h(0, 0, 0), h(1, 0, 0), u);
  final x10 = _mix(h(0, 1, 0), h(1, 1, 0), u);
  final x01 = _mix(h(0, 0, 1), h(1, 0, 1), u);
  final x11 = _mix(h(0, 1, 1), h(1, 1, 1), u);
  return _mix(_mix(x00, x10, v), _mix(x01, x11, v), w);
}

/// Curl of the scalar potential ψ = [valueNoise3] in the xy-plane.
///
/// The field `(∂ψ/∂y, −∂ψ/∂x)` is divergence-free, so particles advected by it
/// swirl like smoke instead of bunching up or sliding in one direction.
(double, double) curlNoise(double x, double y, double t, [int seed = 0]) {
  const e = 0.01;
  final dpdy = (valueNoise3(x, y + e, t, seed) - valueNoise3(x, y - e, t, seed)) / (2 * e);
  final dpdx = (valueNoise3(x + e, y, t, seed) - valueNoise3(x - e, y, t, seed)) / (2 * e);
  return (dpdy, -dpdx);
}

double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);
double _mix(double a, double b, double t) => a + (b - a) * t;

double _hash(int x, int y, int z, int seed) {
  var h = (_imul(x, 374761393) + _imul(y, 668265263) + _imul(z, 2147483647) + _imul(seed, 144665)) & 0xFFFFFFFF;
  h = _imul(h ^ (h >> 13), 1274126177);
  h = h ^ (h >> 16);
  return (h & 0xFFFFFF) / 16777215.0;
}

/// 32-bit wrapping multiply that stays exact on the web (no >2^53 products).
int _imul(int a, int b) {
  a &= 0xFFFFFFFF;
  b &= 0xFFFFFFFF;
  final lo = (a & 0xFFFF) * b;
  final hi = ((a >> 16) * b) & 0xFFFF;
  return (lo + (hi << 16)) & 0xFFFFFFFF;
}
