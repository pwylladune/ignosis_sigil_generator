import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engines/chladni_engine.dart';
import '../../engines/cyber_chaos_engine.dart';
import '../../engines/kamea_engine.dart';
import '../../engines/rose_cross_engine.dart';
import '../../engines/spare_monogram_engine.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';

/// Renders the generated chaos sigil with esoteric glow layers,
/// bounding circles, and energy field pulsations.
class SigilPainter extends CustomPainter {
  final SigilState state;
  final IntentKernel kernel;
  final double animationPhase;

  static final _spareEngine = SpareMonogramEngine();
  static final _kameaEngine = KameaEngine();
  static final _roseCrossEngine = RoseCrossEngine();
  static final _chladniEngine = ChladniEngine();
  static final _cyberEngine = CyberChaosEngine();

  SigilPainter({
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
    if (state.isIncinerated) return; // Purged from reality

    final path = _resolvePath(size);

    // Gnosis pulse scaling
    final pulseScale = state.isGnosisMode
        ? 1.0 + 0.03 * math.sin(animationPhase * 2 * math.pi)
        : 1.0;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(pulseScale, pulseScale);
    canvas.translate(-size.width / 2, -size.height / 2);

    // 1. Ambient outer glow layer
    final glowPaint = Paint()
      ..color = state.primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.strokeWidth * 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawPath(path, glowPaint);

    // 2. High-intensity inner core stroke
    final corePaint = Paint()
      ..color = state.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, corePaint);

    // 3. Incandescent white-hot center trace
    final centerTracePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, state.strokeWidth * 0.4)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, centerTracePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SigilPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.kernel != kernel ||
        oldDelegate.animationPhase != animationPhase;
  }
}
