import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../motion/clock.dart';
import '../../motion/reduce_motion.dart';
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

  /// Scenes are built once in this square reference space and scaled to the
  /// canvas, so a resize (window drag, keyboard) never rebuilds geometry or
  /// restarts motion.
  static const referenceSize = Size(512, 512);

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
    // Warm the burn shader so the first burn never falls back.
    CombustionShader.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = reduceMotionOf(context);
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
    // A burn, once released, is not interrupted: changes apply afterwards.
    if (_combustion != null) return;
    if (widget.spec != _shownSpec) {
      _debounce?.cancel();
      if (widget.spec.sameSettings(_shownSpec)) {
        // Typing: let the pen wait until the word is finished.
        _debounce = Timer(SigilCanvas.typingDebounce, () => _show(widget.spec));
      } else {
        _show(widget.spec);
      }
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    // iOS Reduce Motion is not part of MediaQuery, so re-read it here.
    if (!mounted) return;
    setState(() {
      _reduceMotion = reduceMotionOf(context);
      _clock.reduceMotion = _reduceMotion;
    });
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
    _combustion?.dispose();
    _combustion = null;
    _version++;
    if (_hasLayout) {
      _scene = buildScene(spec, SigilCanvas.referenceSize, _startTime(), previous: _scene);
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
    // A keystroke still waiting on the typing debounce must not fire mid-burn
    // (it would replace the scene and the burn would never report). Show the
    // latest spec now, so what burns is what the user sees.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _show(widget.spec);
    }
    final scene = _scene;
    if (scene == null || scene.geometry.isEmpty || !_hasLayout) {
      widget.onIncinerated();
      return;
    }
    _combustion = Combustion(
      scene: scene,
      size: SigilCanvas.referenceSize,
      startTime: _clock.now,
      reduceMotion: _reduceMotion,
      seed: _stableSeed(widget.spec),
    );
    _version++;
    _clock.wake();
  }

  void _onBreath() => _clock.wake();

  /// Seed that is the same on every run for the same sigil (unlike hashCode).
  static int _stableSeed(SigilSpec spec) {
    var h = spec.system.index + 1;
    for (final c in spec.kernel.normalized.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h;
  }

  bool _keepAlive(double now) {
    final c = _combustion;
    if (c != null) {
      if (c.isDone(now)) {
        c.dispose();
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

  bool get _hasLayout => !(_size?.isEmpty ?? true);

  void _onLayout(Size size) {
    _size = size;
    // Resizes only rescale at paint time. The first real layout writes it out.
    if (_scene == null && _hasLayout) {
      _scene = buildScene(_shownSpec, SigilCanvas.referenceSize, _startTime(), previous: _scene);
      _clock.wake();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.burn.removeListener(_onBurnRequested);
    widget.breath?.removeListener(_onBreath);
    WidgetsBinding.instance.removeObserver(this);
    _combustion?.dispose();
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
    paintPlate(canvas, size, skin: skin, scene: scene(), combustion: combustion(), now: clock.now, breath: breath?.value);
  }

  @override
  bool shouldRepaint(covariant _SigilPlatePainter old) => old.version != version || old.skin != skin || old.breath != breath;
}

/// Paints the plate (paper, guides, the scene or its burn, the bind point) at
/// clock time [now], scaled from the reference space to [size]. Used both on
/// screen and for offscreen export, so the two always match.
void paintPlate(
  Canvas canvas,
  Size size, {
  required SigilSkinTheme skin,
  required SigilScene? scene,
  Combustion? combustion,
  required double now,
  double? breath,
}) {
  if (size.isEmpty) return;
  const ref = SigilCanvas.referenceSize;
  final scale = math.min(size.width, size.height) / ref.width;
  canvas.save();
  canvas.translate((size.width - ref.width * scale) / 2, (size.height - ref.height * scale) / 2);
  canvas.scale(scale);
  final style = SceneStyle.fromSkin(skin, breath: breath, scale: scale);
  final center = ref.center(Offset.zero);
  final radius = ref.width * 0.44;

  // The paper itself, so captures and exports carry the skin's ground
  // (light ink on a dark skin is otherwise invisible on white).
  canvas.drawCircle(center, ref.width / 2, Paint()..color = style.paper);

  // Drafting guides: three rings and quadrant ticks (outer ring only when the
  // scene draws its own construction).
  final guide = style.guidePaint();
  canvas.drawCircle(center, radius, guide);
  if (!(scene?.ownsGuides ?? false)) {
    canvas.drawCircle(center, radius * 0.70, guide);
    canvas.drawCircle(center, radius * 0.35, guide);
  }
  final tick = style.guidePaint(width: 0.8);
  for (var i = 0; i < 4; i++) {
    final a = i * math.pi / 2;
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(center + d * (radius - style.px(8)), center + d * (radius + style.px(8)), tick);
  }

  if (combustion != null) {
    combustion.paint(canvas, ref, now, style);
  } else if (scene != null) {
    scene.paint(canvas, ref, now, style);
  }

  // Vermilion bind point.
  canvas.drawCircle(center, style.px(2.5), Paint()..color = style.seal);
  canvas.restore();
}

/// Renders the settled seal for [spec] offscreen, independent of what the
/// canvas is showing (no half-written strokes, no burn in progress).
Future<ui.Image> renderSettledSeal(SigilSpec spec, SigilSkinTheme skin, {int pixels = 1536}) {
  final scene = buildScene(spec, SigilCanvas.referenceSize, -1e6);
  final recorder = ui.PictureRecorder();
  final size = Size.square(pixels.toDouble());
  final canvas = Canvas(recorder, Offset.zero & size);
  paintPlate(canvas, size, skin: skin, scene: scene, now: 0);
  return recorder.endRecording().toImage(pixels, pixels);
}
