/// Bit-reproducible sin, cos and log.
///
/// `dart:math` defers to the platform libm (or JS `Math.*` on the web), which
/// may differ in the last bit between iOS, Android, the Dart VM and browsers.
/// That is harmless for most drawing, but a chaotic map amplifies a 1-ulp
/// difference into a different attractor within ~50 iterations. These
/// versions use only +, −, ×, ÷ and rounding, which IEEE 754 requires to be
/// correctly rounded everywhere, so the same input gives the same bits on
/// every platform. Accuracy is within a few ulp for |x| ≲ 1e5 (fdlibm kernels).
library;

// π/2 split for Cody–Waite reduction (fdlibm): pio2_1 has 33 significant bits,
// so k·pio2_1 is exact for |k| < 2^20.
const double _pio2_1 = 1.57079632673412561417e+00;
const double _pio2_2 = 6.07710050630396597660e-11;
const double _pio2_2t = 2.02226624879595063154e-21;
const double _invpio2 = 6.36619772367581382433e-01;

const double _s1 = -1.66666666666666324348e-01;
const double _s2 = 8.33333333332248946124e-03;
const double _s3 = -1.98412698298579493134e-04;
const double _s4 = 2.75573137070700676789e-06;
const double _s5 = -2.50507602534068634195e-08;
const double _s6 = 1.58969099521155010221e-10;

const double _c1 = 4.16666666666666019037e-02;
const double _c2 = -1.38888888888741095749e-03;
const double _c3 = 2.48015872894767294178e-05;
const double _c4 = -2.75573143513906633035e-07;
const double _c5 = 2.08757232129817482790e-09;
const double _c6 = -1.13596475577881948265e-11;

double _kSin(double x) {
  final z = x * x;
  return x + x * z * (_s1 + z * (_s2 + z * (_s3 + z * (_s4 + z * (_s5 + z * _s6)))));
}

double _kCos(double x) {
  final z = x * x;
  return 1.0 - 0.5 * z + z * z * (_c1 + z * (_c2 + z * (_c3 + z * (_c4 + z * (_c5 + z * _c6)))));
}

/// Reduces x to r ∈ [−π/4, π/4] and returns (r, quadrant).
(double, int) _reduce(double x) {
  final k = (x * _invpio2).roundToDouble();
  final r = ((x - k * _pio2_1) - k * _pio2_2) - k * _pio2_2t;
  final q = (k % 4).toInt(); // Dart's % is non-negative for a positive divisor
  return (r, q);
}

double detSin(double x) {
  final (r, q) = _reduce(x);
  switch (q) {
    case 0:
      return _kSin(r);
    case 1:
      return _kCos(r);
    case 2:
      return -_kSin(r);
    default:
      return -_kCos(r);
  }
}

double detCos(double x) {
  final (r, q) = _reduce(x);
  switch (q) {
    case 0:
      return _kCos(r);
    case 1:
      return -_kSin(r);
    case 2:
      return -_kCos(r);
    default:
      return _kSin(r);
  }
}

/// sin and cos of the same argument with one reduction. Returns exactly the
/// same bits as [detSin] and [detCos] (same operations, shared work).
(double, double) detSinCos(double x) {
  final (r, q) = _reduce(x);
  final s = _kSin(r), c = _kCos(r);
  switch (q) {
    case 0:
      return (s, c);
    case 1:
      return (c, -s);
    case 2:
      return (-s, -c);
    default:
      return (-c, s);
  }
}

const double _ln2Hi = 6.93147180369123816490e-01;
const double _ln2Lo = 1.90821492927058770002e-10;
const double _sqrt2 = 1.41421356237309514547;

/// Natural log for x > 0 (returns −∞ for 0 and NaN for negatives).
double detLog(double x) {
  if (x.isNaN || x < 0) return double.nan;
  if (x == 0) return double.negativeInfinity;
  if (x.isInfinite) return x;
  var m = x;
  var e = 0;
  // Scaling by 2 is exact, so this is reproducible.
  while (m >= 2) {
    m *= 0.5;
    e++;
  }
  while (m < 1) {
    m *= 2;
    e--;
  }
  if (m > _sqrt2) {
    m *= 0.5;
    e++;
  }
  // log(m) = 2·atanh(s), s = (m − 1)/(m + 1), |s| ≤ 0.172.
  final s = (m - 1) / (m + 1);
  final s2 = s * s;
  var term = s;
  var sum = 0.0;
  for (var k = 1; k <= 23; k += 2) {
    sum += term / k;
    term *= s2;
  }
  return e * _ln2Hi + (2 * sum + e * _ln2Lo);
}
