import 'dart:math' as math;

/// Golden ratio, used for incommensurate idle frequencies.
const double kPhi = 1.6180339887498949;

/// Minimum-jerk position profile `s(τ) = 10τ³ − 15τ⁴ + 6τ⁵` (Flash & Hogan, 1985).
///
/// Human hand motion between two rest points follows this curve. Velocity and
/// acceleration are zero at both ends, which is what makes a stroke read as
/// written rather than tweened. Input is clamped to [0, 1].
double minimumJerk(double tau) {
  final t = tau.clamp(0.0, 1.0);
  final t3 = t * t * t;
  return t3 * (10 - 15 * t + 6 * t * t);
}

/// Velocity of [minimumJerk]: `30τ²(1 − τ)²`. Peaks at 1.875 when τ = 0.5.
double minimumJerkVelocity(double tau) {
  final t = tau.clamp(0.0, 1.0);
  final u = t * (1 - t);
  return 30 * u * u;
}

/// Inverse of [minimumJerk] by bisection: the τ at which `s(τ) = s`.
double inverseMinimumJerk(double s) {
  final target = s.clamp(0.0, 1.0);
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (minimumJerk(mid) < target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Progress of a segment that starts at [start] seconds and lasts [duration],
/// eased with [minimumJerk]. Returns 0 before the start and 1 after the end.
double minimumJerkBetween(double t, double start, double duration) {
  if (duration <= 0) return t >= start ? 1.0 : 0.0;
  return minimumJerk((t - start) / duration);
}

/// Linear interpolation helper.
double lerp(double a, double b, double t) => a + (b - a) * t;

/// Smooth raised-cosine pulse on [0, 1]: 0 at the ends, 1 in the middle.
double hannPulse(double tau) {
  if (tau <= 0 || tau >= 1) return 0;
  return 0.5 - 0.5 * math.cos(2 * math.pi * tau);
}
