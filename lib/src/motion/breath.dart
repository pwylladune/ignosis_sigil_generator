import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// A breathing pattern expressed as phase durations in seconds.
///
/// The breath curve `b(t)` is the master rhythm during Gnosis: it drives the
/// dialog's guide and the sigil on the canvas, so the two stay in sync.
enum BreathPattern {
  /// Slow paced breathing at 5.5 breaths/min (about 0.1 Hz, near the
  /// "resonance frequency" of Lehrer & Vaschillo): inhale 5.45 s, exhale 5.45 s.
  resonance('Slow paced', '5.5 breaths / min', inhale: 60 / 5.5 / 2, holdIn: 0, exhale: 60 / 5.5 / 2, holdOut: 0),

  /// Box breathing 4-4-4-4.
  box('Box', '4 · 4 · 4 · 4', inhale: 4, holdIn: 4, exhale: 4, holdOut: 4),

  /// 4-7-8 relaxation breathing.
  relax478('4-7-8', 'Inhale 4 · hold 7 · exhale 8', inhale: 4, holdIn: 7, exhale: 8, holdOut: 0);

  final String label;
  final String description;
  final double inhale;
  final double holdIn;
  final double exhale;
  final double holdOut;

  const BreathPattern(
    this.label,
    this.description, {
    required this.inhale,
    required this.holdIn,
    required this.exhale,
    required this.holdOut,
  });

  /// Length of one full breath cycle in seconds.
  double get period => inhale + holdIn + exhale + holdOut;

  /// Lung volume `b(t)` in [0, 1] at time [t] seconds.
  ///
  /// Inhale and exhale use a raised cosine so the turnarounds are smooth.
  double value(double t) => sample(t).volume;

  /// Full state of the breath at time [t].
  BreathSample sample(double t) {
    final p = period;
    final cycle = (t / p).floor();
    var local = t - cycle * p;
    if (local < inhale) {
      return BreathSample(BreathPhase.inhale, _rise(local / inhale), cycle);
    }
    local -= inhale;
    if (local < holdIn) return BreathSample(BreathPhase.holdIn, 1, cycle);
    local -= holdIn;
    if (local < exhale) {
      return BreathSample(BreathPhase.exhale, 1 - _rise(local / exhale), cycle);
    }
    return BreathSample(BreathPhase.holdOut, 0, cycle);
  }

  static double _rise(double x) => 0.5 - 0.5 * math.cos(math.pi * x.clamp(0.0, 1.0));
}

enum BreathPhase { inhale, holdIn, exhale, holdOut }

class BreathSample {
  final BreathPhase phase;

  /// Lung volume in [0, 1].
  final double volume;

  /// Number of completed cycles.
  final int cycle;

  const BreathSample(this.phase, this.volume, this.cycle);
}

/// The shared breath value: volume in [0, 1] while Gnosis breathing runs,
/// null otherwise. Writes after [dispose] are ignored, so a dialog torn down in
/// the same frame as its owner cannot touch a disposed notifier.
class BreathSignal extends ValueNotifier<double?> {
  BreathSignal() : super(null);

  bool _disposed = false;

  @override
  set value(double? v) {
    if (_disposed) return;
    super.value = v;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
