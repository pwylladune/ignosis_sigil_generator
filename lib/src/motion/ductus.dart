import '../geometry/sigil_geometry.dart';
import 'easing.dart';

/// Timing for writing a [SigilGeometry] stroke by stroke.
///
/// The pen moves at a constant nominal speed, so a stroke's duration is its
/// arc length divided by [penSpeed] and longer sigils honestly take longer to
/// write. Within each stroke, progress follows [minimumJerk], as a hand does,
/// unless [profileFor] gives that stroke another profile (for example
/// [cruise] for a constant-speed traversal).
class DuctusTimeline {
  DuctusTimeline(
    SigilGeometry geometry, {
    this.penSpeed = 340,
    this.minStrokeDuration = 0.22,
    this.liftPause = 0.08,
    this.profileFor,
  }) {
    var t = 0.0;
    for (final s in geometry.strokes) {
      final d = s.length / penSpeed;
      final duration = d < minStrokeDuration ? minStrokeDuration : d;
      _starts.add(t);
      _durations.add(duration);
      t += duration + liftPause;
    }
    duration = geometry.strokes.isEmpty ? 0 : t - liftPause;
  }

  /// Nominal pen speed in logical pixels per second.
  final double penSpeed;
  final double minStrokeDuration;

  /// Pause while the pen is lifted between strokes.
  final double liftPause;

  /// Optional per-stroke position profile on [0, 1]; null means [minimumJerk].
  final double Function(double tau)? Function(int stroke)? profileFor;

  double Function(double) _profile(int i) => profileFor?.call(i) ?? minimumJerk;

  final List<double> _starts = [];
  final List<double> _durations = [];

  /// Total time to write every stroke, in seconds.
  late final double duration;

  int get strokeCount => _starts.length;

  double strokeStart(int i) => _starts[i];
  double strokeDuration(int i) => _durations[i];

  /// Per-stroke reveal fractions at [t] seconds after writing began.
  List<double> fractionsAt(double t) => List.generate(
        _starts.length,
        (i) => _durations[i] <= 0 ? (t >= _starts[i] ? 1.0 : 0.0) : _profile(i)((t - _starts[i]) / _durations[i]),
        growable: false,
      );

  /// The time at which stroke [i] reaches [fraction] of its length.
  double timeAtFraction(int i, double fraction) {
    final p = profileFor?.call(i);
    return _starts[i] + _durations[i] * (p == null ? inverseMinimumJerk(fraction) : inverseProfile(p, fraction));
  }
}
