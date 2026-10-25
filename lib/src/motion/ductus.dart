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
    this.liftPause = 0.06,
    this.profileFor,
  }) {
    var t = 0.0;
    final strokes = geometry.strokes;
    for (var i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      final d = s.length / penSpeed;
      final duration = d < minStrokeDuration ? minStrokeDuration : d;
      _starts.add(t);
      _durations.add(duration);
      t += duration;
      if (i + 1 < strokes.length) t += _lift(s, strokes[i + 1]);
    }
    duration = t;
  }

  /// Nominal pen speed in logical pixels per second.
  final double penSpeed;
  final double minStrokeDuration;

  /// Base pause while the pen is lifted between strokes. The actual pause
  /// grows with the pen-up travel (distance / 2·penSpeed), clamped to
  /// [liftPause, 0.22 s], so many short nearby strokes are not staccato and
  /// long jumps read as the hand moving across the page.
  final double liftPause;

  double _lift(SigilStroke from, SigilStroke to) {
    final a = from.pointAt(1), b = to.pointAt(0);
    if (a == null || b == null) return liftPause;
    return ((a - b).distance / (2 * penSpeed)).clamp(liftPause, 0.22);
  }

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
        (i) => _durations[i] <= 0
            ? (t >= _starts[i] ? 1.0 : 0.0)
            : _profile(i)((t - _starts[i]) / _durations[i]).clamp(0.0, 1.0),
        growable: false,
      );

  /// The time at which stroke [i] reaches [fraction] of its length.
  double timeAtFraction(int i, double fraction) {
    final p = profileFor?.call(i);
    return _starts[i] + _durations[i] * (p == null ? inverseMinimumJerk(fraction) : inverseProfile(p, fraction));
  }
}
