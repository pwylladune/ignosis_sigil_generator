import 'package:flutter/material.dart';
import 'brush.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/ductus.dart';
import '../theme/sigil_skins.dart';

/// Visual parameters for one frame, derived from the active skin.
class SceneStyle {
  final Color ink;
  final Color guide;
  final Color muted;

  /// Readable secondary ink (visited labels).
  final Color secondary;
  final Color accent;

  /// The vermilion bind point, constant across skins.
  final Color seal;
  final Color burn;
  final Color paper;
  final double strokeWidth;
  final double washOpacity;

  /// Breath volume in [0, 1] while Gnosis breathing is active, else null.
  final double? breath;

  /// Screen pixels per scene unit. Scenes are built in a fixed reference space
  /// and scaled to the canvas, so on-screen widths are divided by this.
  final double scale;

  /// Converts a width in screen pixels to scene units.
  double px(double screenPixels) => screenPixels / scale;

  /// Opacity of construction lettering (kamea numbers, Hebrew petal glyphs).
  /// The burn fades it out before the flame, so letters are never shown burning.
  final double letterOpacity;

  SceneStyle withLetterOpacity(double opacity) => SceneStyle(
        ink: ink,
        guide: guide,
        muted: muted,
        secondary: secondary,
        accent: accent,
        seal: seal,
        burn: burn,
        paper: paper,
        strokeWidth: strokeWidth,
        washOpacity: washOpacity,
        breath: breath,
        scale: scale,
        letterOpacity: opacity.clamp(0.0, 1.0),
      );

  /// Runs [draw] with construction lettering at [letterOpacity].
  void paintLettering(Canvas canvas, void Function() draw) {
    if (letterOpacity <= 0) return;
    if (letterOpacity >= 1) {
      draw();
      return;
    }
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, letterOpacity));
    draw();
    canvas.restore();
  }

  const SceneStyle({
    required this.ink,
    required this.guide,
    required this.muted,
    required this.secondary,
    required this.accent,
    required this.seal,
    required this.burn,
    required this.paper,
    required this.strokeWidth,
    required this.washOpacity,
    this.breath,
    this.scale = 1,
    this.letterOpacity = 1,
  });

  factory SceneStyle.fromSkin(SigilSkinTheme skin, {double? breath, double scale = 1}) => SceneStyle(
        ink: skin.inkPrimary,
        guide: skin.guideColor,
        muted: skin.inkMuted,
        secondary: skin.inkSecondary,
        seal: skin.seal,
        accent: skin.accent,
        burn: skin.burn,
        paper: skin.canvasBackground,
        strokeWidth: skin.strokeWidth,
        washOpacity: skin.inkWashOpacity,
        breath: breath,
        scale: scale,
      );

  /// Stroke weight, breathing by ±3 % with the Gnosis breath.
  double get weight => px(breath == null ? strokeWidth : strokeWidth * (0.97 + 0.06 * breath!));

  Paint inkPaint({double opacity = 1, double? width}) => Paint()
    ..color = ink.withValues(alpha: ink.a * opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width ?? weight
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint washPaint({double opacity = 1}) => Paint()
    ..color = ink.withValues(alpha: washOpacity * opacity * (breath == null ? 1 : 0.7 + 0.6 * breath!))
    ..style = PaintingStyle.stroke
    ..strokeWidth = weight * 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint guidePaint({double width = 1}) => Paint()
    ..color = guide
    ..style = PaintingStyle.stroke
    ..strokeWidth = px(width);

  /// Nominal sumi-e brush width (scene units): thicker than the pen line,
  /// breathing with it during Gnosis.
  double get brushWidth => weight * 4.2;

  /// Paints strokes with the sumi-e brush, each revealed to its fraction.
  void drawStrokes(Canvas canvas, List<SigilStroke> strokes, List<double> fractions, {double opacity = 1, int? seed}) =>
      paintBrushStrokes(canvas, this, strokes, fractions, opacity: opacity, seed: seed);

  /// Draws a path as ink on rag paper: a soft wash under a crisp line.
  void drawInk(Canvas canvas, Path path, {double opacity = 1}) {
    canvas.drawPath(path, washPaint(opacity: opacity));
    canvas.drawPath(path, inkPaint(opacity: opacity));
  }
}

final _fontListeners = <VoidCallback>{};
bool _fontHooked = false;

/// Registers [clear] to run when system or fallback fonts change, so cached
/// text layouts (laid out before a web fallback font for Hebrew or 🜂 arrived)
/// are rebuilt instead of keeping missing-glyph boxes.
void onSystemFontsChanged(VoidCallback clear) {
  _fontListeners.add(clear);
  if (_fontHooked) return;
  _fontHooked = true;
  PaintingBinding.instance.systemFonts.addListener(() {
    for (final l in _fontListeners) {
      l();
    }
  });
}

/// A sigil system's motion: a pure function of time since [startTime].
abstract class SigilScene {
  SigilScene({required this.startTime});

  /// Clock time at which this scene began, in seconds.
  final double startTime;

  /// Final, static geometry. The burn and the exports read this.
  SigilGeometry get geometry;

  /// Seconds after [startTime] after which nothing moves.
  double get settleTime;

  bool isSettled(double now) => now - startTime >= settleTime;

  /// True when the scene draws its own construction (square, rose, plate), so
  /// the canvas keeps only its outer ring and ticks.
  bool get ownsGuides => false;

  /// Paints the scene at clock time [now].
  void paint(Canvas canvas, Size size, double now, SceneStyle style);

  /// Paints the settled scene with its ink limited to the first [inkLength]
  /// pixels in written order. The burn uses this to unwrite the sigil in
  /// reverse ductus: the last stroke written is the first consumed.
  void paintUnwritten(Canvas canvas, Size size, double inkLength, SceneStyle style) {
    style.drawInk(canvas, geometry.revealLength(inkLength));
  }
}

/// Writes a geometry stroke by stroke with the [DuctusTimeline]. Then stillness.
class DuctusScene extends SigilScene {
  DuctusScene(this.geometry, {required super.startTime}) : timeline = DuctusTimeline(geometry);

  @override
  final SigilGeometry geometry;
  final DuctusTimeline timeline;

  @override
  double get settleTime => timeline.duration;

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final t = now - startTime;
    style.drawStrokes(canvas, geometry.strokes, timeline.fractionsAt(t));
  }
}
