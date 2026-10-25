import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../motion/clock.dart';
import '../theme/sigil_skins.dart';
import 'combustion.dart';
import 'scene.dart';
import 'scene_factory.dart';
import 'sigil_spec.dart';

/// Requests a burn from outside the canvas.
class SigilBurnController extends ChangeNotifier {
  int _generation = 0;
  int get generation => _generation;

  void ignite() {
    _generation++;
    notifyListeners();
  }
}

/// The animated sigil plate. Owns the single [MotionClock]; everything inside
/// is a function of its time, and frames stop once the plate is still.
class SigilCanvas extends StatefulWidget {
  const SigilCanvas({
    super.key,
    required this.spec,
    required this.skin,
    required this.burn,
    required this.onIncinerated,
    this.breath,
  });

  final SigilSpec spec;
  final SigilSkinTheme skin;
  final SigilBurnController burn;
  final VoidCallback onIncinerated;

  /// Breath volume in [0, 1] while Gnosis is active; null otherwise.
  final ValueListenable<double?>? breath;

  /// Delay after the last keystroke before the pen starts writing.
  static const typingDebounce = Duration(milliseconds: 260);

  @override
  State<SigilCanvas> createState() => _SigilCanvasState();
}

class _SigilCanvasState extends State<SigilCanvas> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MotionClock _clock;
  SigilScene? _scene;
  Combustion? _combustion;
  Size? _size;
  late SigilSpec _shownSpec;
  Timer? _debounce;
  int _burnGeneration = 0;
  int _version = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _clock = MotionClock(this)..keepAlive = _keepAlive;
    _shownSpec = widget.spec;
    _burnGeneration = widget.burn.generation;
    widget.burn.addListener(_onBurnRequested);
    widget.breath?.addListener(_onBreath);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _clock.reduceMotion = _reduceMotion;
  }

  @override
  void didUpdateWidget(SigilCanvas old) {
    super.didUpdateWidget(old);
    if (old.burn != widget.burn) {
      old.burn.removeListener(_onBurnRequested);
      widget.burn.addListener(_onBurnRequested);
    }
    if (old.breath != widget.breath) {
      old.breath?.removeListener(_onBreath);
      widget.breath?.addListener(_onBreath);
    }
    if (widget.spec != _shownSpec) {
      _debounce?.cancel();
      if (widget.spec.sameSettings(_shownSpec) && !_reduceMotion) {
        // Typing: let the pen wait until the word is finished.
        _debounce = Timer(SigilCanvas.typingDebounce, () => _show(widget.spec));
      } else {
        _show(widget.spec);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clock.wake();
    } else if (state != AppLifecycleState.inactive) {
      _clock.sleep();
    }
  }

  void _show(SigilSpec spec) {
    if (!mounted) return;
    _shownSpec = spec;
    _combustion = null;
    _version++;
    final size = _size;
    if (size != null) {
      _scene = buildScene(spec, size, _startTime(), previous: _scene);
      _clock.wake();
    } else {
      _scene = null;
    }
    setState(() {});
  }

  /// Scenes start now, or long ago when motion is reduced (already settled).
  double _startTime() => _reduceMotion ? _clock.now - 1e6 : _clock.now;

  void _onBurnRequested() {
    if (widget.burn.generation == _burnGeneration) return;
    _burnGeneration = widget.burn.generation;
    final scene = _scene;
    if (scene == null || scene.geometry.isEmpty) {
      widget.onIncinerated();
      return;
    }
    _combustion = Combustion(scene: scene, startTime: _clock.now, reduceMotion: _reduceMotion);
    _version++;
    _clock.wake();
  }

  void _onBreath() => _clock.wake();

  bool _keepAlive(double now) {
    final c = _combustion;
    if (c != null) {
      if (c.isDone(now)) {
        _combustion = null;
        _scene = null;
        // Report after this frame so the parent can rebuild safely.
        scheduleMicrotask(widget.onIncinerated);
        return false;
      }
      return true;
    }
    if (widget.breath?.value != null) return true;
    final s = _scene;
    return s != null && !s.isSettled(now);
  }

  void _onLayout(Size size) {
    if (_size == size) return;
    final first = _size == null;
    _size = size;
    // On resize, rebuild without replaying; on first layout, write it out.
    final start = first ? _startTime() : _clock.now - 1e6;
    _scene = buildScene(_shownSpec, size, start, previous: _scene);
    if (first) _clock.wake();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.burn.removeListener(_onBurnRequested);
    widget.breath?.removeListener(_onBreath);
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _onLayout(constraints.biggest);
      return CustomPaint(
        size: constraints.biggest,
        painter: _SigilPlatePainter(
          clock: _clock,
          version: _version,
          scene: () => _scene,
          combustion: () => _combustion,
          skin: widget.skin,
          breath: widget.breath,
        ),
      );
    });
  }
}

class _SigilPlatePainter extends CustomPainter {
  _SigilPlatePainter({
    required this.clock,
    required this.version,
    required this.scene,
    required this.combustion,
    required this.skin,
    required this.breath,
  }) : super(repaint: clock);

  final MotionClock clock;

  /// Bumped whenever the scene or burn is replaced.
  final int version;
  final SigilScene? Function() scene;
  final Combustion? Function() combustion;
  final SigilSkinTheme skin;
  final ValueListenable<double?>? breath;

  @override
  void paint(Canvas canvas, Size size) {
    final now = clock.now;
    final style = SceneStyle.fromSkin(skin, breath: breath?.value);
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.44;

    // Drafting guides: three rings and quadrant ticks.
    final guide = style.guidePaint();
    canvas.drawCircle(center, radius, guide);
    canvas.drawCircle(center, radius * 0.70, guide);
    canvas.drawCircle(center, radius * 0.35, guide);
    final tick = style.guidePaint(width: 0.8);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + d * (radius - 8), center + d * (radius + 8), tick);
    }

    final c = combustion();
    final s = scene();
    if (c != null) {
      c.paint(canvas, size, now, style);
    } else if (s != null) {
      s.paint(canvas, size, now, style);
    }

    // Vermilion bind point.
    canvas.drawCircle(center, 2.5, Paint()..color = style.accent);
  }

  @override
  bool shouldRepaint(covariant _SigilPlatePainter old) => old.version != version || old.skin != skin || old.breath != breath;
}
