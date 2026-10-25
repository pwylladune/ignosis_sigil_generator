import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The single motion clock: monotonic time in seconds, driven by one [Ticker].
///
/// Everything on the canvas is a function of [now]. Nothing loops: there is no
/// 0→1 controller to wrap around. The ticker runs only while something is
/// animating ([keepAlive] returns true) and stops by itself once the scene is
/// still, so an idle studio costs no frames.
class MotionClock extends ChangeNotifier {
  MotionClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  double _base = 0;
  double _elapsed = 0;

  /// Queried after each frame; returning false stops the ticker.
  bool Function(double now)? keepAlive;

  /// When true, animations should jump to their final state.
  bool reduceMotion = false;

  /// Current time in seconds. Continuous across ticker stops and restarts.
  double get now => _base + _elapsed;

  bool get isRunning => _ticker.isActive;

  /// Starts frames if they are not already running.
  void wake() {
    if (_ticker.isActive) return;
    _base += _elapsed;
    _elapsed = 0;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / 1e6;
    notifyListeners();
    final alive = keepAlive?.call(now) ?? false;
    if (!alive) _ticker.stop();
  }

  /// Stops frames immediately (for example when the app is backgrounded).
  void sleep() {
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
