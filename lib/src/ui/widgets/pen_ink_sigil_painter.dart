import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engines/chladni_engine.dart';
import '../../engines/cyber_chaos_engine.dart';
import '../../engines/kamea_engine.dart';
import '../../engines/rose_cross_engine.dart';
import '../../engines/spare_monogram_engine.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';
import '../theme/ignosis_theme.dart';

/// Renders the sigil in an exquisite Pen-and-Ink drafting aesthetic on archival parchment.
class PenInkSigilPainter extends CustomPainter {
  final SigilState state;
  final IntentKernel kernel;
  final double animationPhase;

  static final _spareEngine = SpareMonogramEngine();
  static final _kameaEngine = KameaEngine();
  static final _roseCrossEngine = RoseCrossEngine();
  static final _chladniEngine = ChladniEngine();
  static final _cyberEngine = CyberChaosEngine();

  PenInkSigilPainter({
    required this.state,
    required this.kernel,
    required this.animationPhase,
  });

  Path _resolvePath(Size size) {
    switch (state.system) {
      case SigilSystem.spare:
        return _spareEngine.generatePath(
          kernel,
          size,
          symmetry: state.symmetryFolds,
          animationPhase: animationPhase,
        );
      case SigilSystem.kamea:
        return _kameaEngine.generatePath(
          kernel,
          state.kameaType,
          size,
        );
      case SigilSystem.roseCross:
        return _roseCrossEngine.generatePath(
          kernel,
          size,
        );
      case SigilSystem.chladni:
        return _chladniEngine.generatePath(
          kernel,
          size,
          animationPhase: animationPhase,
        );
      case SigilSystem.cyberChaos:
        return _cyberEngine.generatePath(
          kernel,
          size,
          symmetryFolds: state.symmetryFolds,
          animationPhase: animationPhase,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (state.isIncinerated) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.44;

    // 1. Subtle Architectural Drafting Guides (Pen & Ink grid & polar rings)
    final guidePaint = Paint()
      ..color = IgnosisTheme.parchmentSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric guide rings
    canvas.drawCircle(center, radius, guidePaint);
    canvas.drawCircle(center, radius * 0.70, guidePaint);
    canvas.drawCircle(center, radius * 0.35, guidePaint);

    // Cross-hair quadrant ticks
    final tickPaint = Paint()
      ..color = IgnosisTheme.wash.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(center.dx - radius - 8, center.dy), Offset(center.dx - radius + 8, center.dy), tickPaint);
    canvas.drawLine(Offset(center.dx + radius - 8, center.dy), Offset(center.dx + radius + 8, center.dy), tickPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius - 8), Offset(center.dx, center.dy - radius + 8), tickPaint);
    canvas.drawLine(Offset(center.dx, center.dy + radius - 8), Offset(center.dx, center.dy + radius + 8), tickPaint);

    final path = _resolvePath(size);

    // Breathing pulse during Gnosis focus
    final pulseScale = state.isGnosisMode
        ? 1.0 + 0.02 * math.sin(animationPhase * 2 * math.pi)
        : 1.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulseScale, pulseScale);
    canvas.translate(-center.dx, -center.dy);

    // 2. Ink bleed / wash shadow layer (mimicking fountain pen ink absorption into rag paper)
    final inkWashPaint = Paint()
      ..color = IgnosisTheme.sumiInk.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.strokeWidth * 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, inkWashPaint);

    // 3. Primary Sumi Ink Stroke (crisp, elegant, ultra-clean black)
    final mainInkPaint = Paint()
      ..color = state.primaryColor == const Color(0xFF00E5FF) ? IgnosisTheme.sumiInk : state.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, mainInkPaint);

    // 4. Vermilion Alchemical Center Bind Point
    final sealPointPaint = Paint()
      ..color = IgnosisTheme.vermilion
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, sealPointPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PenInkSigilPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.kernel != kernel ||
        oldDelegate.animationPhase != animationPhase;
  }
}
