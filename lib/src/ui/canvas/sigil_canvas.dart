import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../engines/infinite_engine.dart';
import '../../motion/clock.dart';
import '../../motion/reduce_motion.dart';
import '../theme/sigil_skins.dart';
import 'combustion.dart';
import 'infinite_scene.dart';
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

/// A zoom in progress, in reference coordinates: a point p is drawn at
/// `to + scale·(p − from)`.
typedef PlateLens = ({double scale, Offset from, Offset to});

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
    this.onViewChanged,
  });

  final SigilSpec spec;

  /// Set for The Infinite: pinch, scroll and double-tap zoom the plate, and
  /// the new window is reported here when a gesture ends (null = whole set).
  final ValueChanged<InfiniteView?>? onViewChanged;
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

  /// The zoom being dragged, drawn as a transform until it is committed.
  PlateLens? _lens;
  Offset? _gestureFrom;
  Offset? _doubleTapAt;
  Timer? _scrollCommit;

  @override
  void initState() {
    super.initState();
    _clock = MotionClock(this)..keepAlive = _keepAlive;
    _shownSpec = widget.spec;
    _burnGeneration = widget.burn.generation;
    widget.burn.addListener(_onBurnRequested);
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
    // A new zoom window appears at once; only new sigils are written out.
    final viewOnly = spec.differsOnlyInView(_shownSpec);
    _shownSpec = spec;
    _lens = null;
    _combustion?.dispose();
    _combustion = null;
    _version++;
    if (_hasLayout) {
      _scene = buildScene(spec, SigilCanvas.referenceSize, viewOnly ? _clock.now - 1e6 : _startTime(), previous: _scene);
      _clock.wake();
    } else {
      _scene = null;
    }
    setState(() {});
  }

  // ── Zoom (The Infinite) ───────────────────────────────────────────────

  bool get _zoomable => widget.onViewChanged != null && _combustion == null && _scene is InfiniteScene;

  /// Widget-local point to reference coordinates.
  Offset _toRef(Offset local) {
    final size = _size ?? Size.zero;
    const ref = SigilCanvas.referenceSize;
    final scale = math.min(size.width, size.height) / ref.width;
    final origin = Offset((size.width - ref.width * scale) / 2, (size.height - ref.height * scale) / 2);
    return (local - origin) / scale;
  }

  void _setLens(PlateLens? lens) => setState(() {
        _lens = lens;
        _version++;
      });

  /// Zooms by [factor] about the reference point [at], on top of any lens.
  void _zoomAbout(Offset at, double factor) {
    final l = _lens ?? (scale: 1.0, from: at, to: at);
    _setLens((scale: l.scale * factor, from: l.from, to: at + (l.to - at) * factor));
  }

  /// Turns the lens into a new view and reports it.
  void _commitLens() {
    _scrollCommit?.cancel();
    final lens = _lens;
    final scene = _scene;
    if (lens == null || scene is! InfiniteScene) return;
    final s = scene.sigil;
    final home = s.params.home;
    // The point that the lens brings to the plate's centre becomes the new centre.
    final p = lens.from + (s.center - lens.to) / lens.scale;
    final (re, im) = InfiniteEngine.toComplex(p, s.view, s.center, s.radius);
    final half = math.max(s.view.halfWidth / lens.scale, InfiniteView.minHalfWidth);
    widget.onViewChanged!(half >= home.halfWidth * 0.98 ? null : InfiniteView(re, im, half));
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureFrom = _toRef(d.localFocalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final from = _gestureFrom;
    if (from == null) return;
    _setLens((scale: d.scale, from: from, to: _toRef(d.localFocalPoint)));
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _gestureFrom = null;
    final l = _lens;
    if (l == null || (l.scale == 1 && (l.to - l.from).distance < 2)) {
      _setLens(null);
      return;
    }
    _commitLens();
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_zoomable) return;
    _zoomAbout(_toRef(e.localPosition), math.exp(-e.scrollDelta.dy / 400));
    _scrollCommit?.cancel();
    _scrollCommit = Timer(const Duration(milliseconds: 280), _commitLens);
  }

  void _onDoubleTap() {
    final at = _doubleTapAt;
    if (at == null || !_zoomable) return;
    _zoomAbout(_toRef(at), 2);
    _commitLens();
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
    // Breath does not keep the ticker alive: the painter repaints from the
    // breath notifier itself, so held breaths cost no frames.
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
    _scrollCommit?.cancel();
    widget.burn.removeListener(_onBurnRequested);
    WidgetsBinding.instance.removeObserver(this);
    _combustion?.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _onLayout(constraints.biggest);
      final plate = CustomPaint(
        size: constraints.biggest,
        painter: _SigilPlatePainter(
          clock: _clock,
          version: _version,
          scene: () => _scene,
          combustion: () => _combustion,
          lens: () => _lens,
          skin: widget.skin,
          breath: widget.breath,
        ),
      );
      if (!_zoomable) return plate;
      return Semantics(
        label: 'The Infinite: pinch, scroll or double-tap to zoom',
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: _onDoubleTap,
            child: plate,
          ),
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
    required this.lens,
    required this.skin,
    required this.breath,
  }) : super(repaint: breath == null ? clock : Listenable.merge([clock, breath]));

  final MotionClock clock;

  /// Bumped whenever the scene or burn is replaced.
  final int version;
  final SigilScene? Function() scene;
  final Combustion? Function() combustion;
  final PlateLens? Function() lens;
  final SigilSkinTheme skin;
  final ValueListenable<double?>? breath;

  @override
  void paint(Canvas canvas, Size size) {
    paintPlate(canvas, size,
        skin: skin, scene: scene(), combustion: combustion(), lens: lens(), now: clock.now, breath: breath?.value);
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
  PlateLens? lens,
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
  if (breath != null) {
    // During Gnosis the outer ring carries the breath (shared with the dialog).
    canvas.drawCircle(
      center,
      radius * (0.99 + 0.02 * breath),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.px(1 + breath)
        ..color = Color.lerp(style.guide, style.ink, 0.15 + 0.35 * breath)!,
    );
  } else {
    canvas.drawCircle(center, radius, guide);
  }
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
  } else if (scene != null && lens != null) {
    // A zoom in progress: the scene moves under the plate, clipped to it.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.translate(lens.to.dx, lens.to.dy);
    canvas.scale(lens.scale);
    canvas.translate(-lens.from.dx, -lens.from.dy);
    scene.paint(canvas, ref, now, style);
    canvas.restore();
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
