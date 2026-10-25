import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engines/kamea_engine.dart';
import '../../geometry/sigil_geometry.dart';
import '../../motion/ductus.dart';
import '../../motion/easing.dart';
import 'scene.dart';

/// Kamea traversal: the pen travels cell to cell at constant arc speed (a
/// [cruise] profile with short ramps, so visits are evenly paced); each
/// visited number glows briefly as it is reached. When the trace completes, the
/// rows, columns and diagonals light in turn, each summing to the magic
/// constant M: the square's invariance is the consecration. Then stillness.
class KameaScene extends SigilScene {
  KameaScene(this.sigil, {required super.startTime})
      : timeline = DuctusTimeline(
          sigil.geometry,
          profileFor: (i) => i == sigil.traversalStroke ? cruise : null,
        ) {
    final trace = sigil.traversalStroke;
    _visitTimes = [
      for (var i = 0; i < sigil.cells.length; i++)
        trace == null ? 0.0 : timeline.timeAtFraction(trace, sigil.visitFractions[i]),
    ];
  }

  final KameaSigil sigil;
  final DuctusTimeline timeline;
  late final List<double> _visitTimes;

  static const _glowDecay = 0.55;
  static const _sumDelay = 0.3;
  static const _sumStagger = 0.07;
  static const _sumPulse = 0.9;

  int get _lineCount => 2 * sigil.type.size + 2;

  @override
  SigilGeometry get geometry => sigil.geometry;

  @override
  bool get ownsGuides => true;

  @override
  double get settleTime => timeline.duration + _sumDelay + (_lineCount - 1) * _sumStagger + _sumPulse;

  @override
  void paint(Canvas canvas, Size size, double now, SceneStyle style) {
    final t = now - startTime;
    final layout = sigil.layout;
    final n = layout.n;
    final sq = KameaEngine.square(sigil.type);

    // The faint square.
    final grid = style.guidePaint();
    for (var i = 0; i <= n; i++) {
      final x = layout.square.left + i * layout.cell;
      final y = layout.square.top + i * layout.cell;
      canvas.drawLine(Offset(x, layout.square.top), Offset(x, layout.square.bottom), grid);
      canvas.drawLine(Offset(layout.square.left, y), Offset(layout.square.right, y), grid);
    }

    // Cell glow as the pen reaches each number.
    final glow = <int, double>{};
    for (var i = 0; i < sigil.cells.length; i++) {
      final dt = t - _visitTimes[i];
      if (dt < 0 || sigil.cells[i] < 0) continue;
      final g = math.exp(-dt / _glowDecay);
      glow[sigil.cells[i]] = math.max(glow[sigil.cells[i]] ?? 0, g);
    }
    glow.forEach((cell, g) {
      if (g < 0.01) return;
      canvas.drawRect(layout.cellRect(cell).deflate(1), Paint()..color = style.accent.withValues(alpha: 0.16 * g));
    });

    // Numbers.
    // Readable on screen whatever the plate size: clamp in screen pixels.
    final fontSize = style.px((layout.cell * 0.3 * style.scale).clamp(6.0, 13.0));
    for (var i = 0; i < n * n; i++) {
      final g = glow[i] ?? 0;
      _drawText(canvas, '${sq[i]}', layout.cellCenter(i), fontSize, style.muted.withValues(alpha: 0.55), style.accent, g);
    }

    // Ink: the traversal, written by the ductus.
    final path = t >= timeline.duration ? geometry.path : geometry.reveal(timeline.fractionsAt(t));
    style.drawInk(canvas, path);

    // Consecration: every row, column and diagonal lights to M in turn.
    final m = KameaEngine.magicConstant(n);
    final tSum = t - timeline.duration - _sumDelay;
    if (tSum > 0 && tSum < (_lineCount - 1) * _sumStagger + _sumPulse) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(style.px(1.0), layout.cell * 0.08);
      for (var k = 0; k < _lineCount; k++) {
        final a = hannPulse((tSum - k * _sumStagger) / _sumPulse);
        if (a <= 0) continue;
        paint.color = style.accent.withValues(alpha: 0.35 * a);
        final (p0, p1) = _line(k);
        canvas.drawLine(p0, p1, paint);
      }
    }

    // Label: planet and magic constant, brightening during the consecration.
    final labelGlow = tSum > 0 ? hannPulse(tSum / ((_lineCount - 1) * _sumStagger + _sumPulse)) : 0.0;
    _drawText(
      canvas,
      '${sigil.type.name.toUpperCase()}  ·  Σ = $m',
      Offset(layout.square.center.dx, layout.square.bottom + fontSize * 1.4),
      style.px((fontSize * style.scale * 0.9).clamp(8.0, 11.0)),
      style.muted,
      style.accent,
      labelGlow,
      letterSpacing: 1.6,
    );
  }

  /// Endpoints of line k: rows, then columns, then the two diagonals.
  (Offset, Offset) _line(int k) {
    final l = sigil.layout;
    final n = l.n;
    if (k < n) return (l.cellCenter(k * n), l.cellCenter(k * n + n - 1));
    if (k < 2 * n) return (l.cellCenter(k - n), l.cellCenter((n - 1) * n + k - n));
    if (k == 2 * n) return (l.cellCenter(0), l.cellCenter(n * n - 1));
    return (l.cellCenter(n - 1), l.cellCenter((n - 1) * n));
  }

  /// Laid-out text, keyed by fixed colours only (base and accent per skin), so
  /// the cache stays small; glows are drawn as an accent layer at opacity.
  static final _textCache = <(String, double, int, double), TextPainter>{};
  static const _textCacheLimit = 600;

  static TextPainter _painter(String text, double size, Color color, double letterSpacing) {
    final key = (text, size, color.toARGB32(), letterSpacing);
    final hit = _textCache[key];
    if (hit != null) return hit;
    if (_textCache.length >= _textCacheLimit) {
      for (final tp in _textCache.values) {
        tp.dispose();
      }
      _textCache.clear();
    }
    return _textCache[key] = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, letterSpacing: letterSpacing, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Draws [text] in [base], with [accent] blended over it at [glow] opacity.
  static void _drawText(Canvas canvas, String text, Offset center, double size, Color base, Color accent, double glow,
      {double letterSpacing = 0}) {
    final tp = _painter(text, size, base, letterSpacing);
    final at = center - Offset(tp.width / 2, tp.height / 2);
    tp.paint(canvas, at);
    if (glow > 0.01) {
      final hot = _painter(text, size, accent, letterSpacing);
      canvas.saveLayer(at & hot.size, Paint()..color = Color.fromRGBO(0, 0, 0, glow.clamp(0.0, 1.0)));
      hot.paint(canvas, at);
      canvas.restore();
    }
  }
}
