import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../motion/breath.dart';
import '../../motion/reduce_motion.dart';
import '../theme/sigil_skins.dart';

/// Clean Pen & Ink architectural modal for Gnosis breathing and combustion.
///
/// The breath curve `b(t)` from [BreathPattern] is the master rhythm: it scales
/// the guide ring here and is published to [breath] so the sigil on the canvas
/// breathes with it. The dialog never auto-advances; after [targetCycles] the
/// release is offered more prominently.
class PenInkRitualBurnDialog extends StatefulWidget {
  final VoidCallback onBurnComplete;


  /// Shared breath volume, null when not breathing.
  final BreathSignal? breath;

  final int targetCycles;

  /// Active skin, so the rite does not flash a white panel on a dark skin.
  final SigilSkinTheme theme;

  const PenInkRitualBurnDialog({
    super.key,
    required this.theme,
    required this.onBurnComplete,
    this.breath,
    this.targetCycles = 7,
  });

  @override
  State<PenInkRitualBurnDialog> createState() => _PenInkRitualBurnDialogState();
}

class _PenInkRitualBurnDialogState extends State<PenInkRitualBurnDialog> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  BreathPattern _pattern = BreathPattern.resonance;
  double _t = 0;
  double _patternStart = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMicroseconds / 1e6);
      widget.breath?.value = _pattern.value(_t - _patternStart);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Clear after this frame: the notifier's listeners may be mid-build.
    final breath = widget.breath;
    WidgetsBinding.instance.addPostFrameCallback((_) => breath?.value = null);
    super.dispose();
  }

  void _selectPattern(BreathPattern p) {
    setState(() {
      _pattern = p;
      _patternStart = _t;
    });
  }

  String _phaseLabel(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale:
        return 'INHALE · DRAW GNOSIS';
      case BreathPhase.holdIn:
        return 'HOLD · STILLNESS';
      case BreathPhase.exhale:
        return 'EXHALE · RELEASE ATTACHMENT';
      case BreathPhase.holdOut:
        return 'HOLD · EMPTINESS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final reduceMotion = reduceMotionOf(context);
    final sample = _pattern.sample(_t - _patternStart);
    final peaked = sample.cycle >= widget.targetCycles;
    final b = sample.volume;
    final scale = reduceMotion ? 1.0 : 0.85 + b * 0.3;

    return Dialog(
      // Sit low so the breathing seal stays visible above the dialog.
      alignment: Alignment.bottomCenter,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.hairline),
                    ),
                    child: Center(
                      child: Text('🜂', style: TextStyle(color: theme.seal, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'GNOSIS CHARGING RITE',
                    style: TextStyle(
                      color: theme.inkPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: theme.inkTertiary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 24, color: theme.hairline),

              Text(
                'Focus your attention on the centre bind-point. '
                'Breathe with the ring; the seal breathes with you. '
                'When your focus peaks, release the seal.\n'
                'Breathe comfortably and stop if you feel dizzy or short of breath. '
                'This is a focus exercise, not medical advice.',
                style: TextStyle(color: theme.inkSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Breath pattern presets
              Wrap(
                spacing: 6,
                alignment: WrapAlignment.center,
                children: BreathPattern.values.map((p) {
                  final selected = p == _pattern;
                  return ChoiceChip(
                    label: Text(p.label),
                    tooltip: p.description,
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: theme.background,
                    backgroundColor: theme.surface,
                    side: BorderSide(color: selected ? theme.inkPrimary : theme.hairline),
                    labelStyle: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? theme.inkPrimary : theme.inkTertiary,
                    ),
                    onSelected: (_) => _selectPattern(p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Pen & Ink breath sphere: radius and ink follow b(t).
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _BreathRingPainter(
                    theme: theme,
                    volume: b,
                    scale: scale,
                    cycleFraction: reduceMotion ? ((_t - _patternStart) % _pattern.period) / _pattern.period : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _phaseLabel(sample.phase),
                style: TextStyle(
                  color: theme.inkPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'BREATH ${math.min(sample.cycle + 1, widget.targetCycles)} / ${widget.targetCycles}',
                style: TextStyle(color: theme.inkTertiary, letterSpacing: 1.4, fontSize: 9),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: peaked
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.inkPrimary,
                              foregroundColor: theme.surface,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _release,
                            child: const Text(
                              'RELEASE THE SEAL',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                            ),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.inkPrimary,
                              side: BorderSide(color: theme.hairline),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _release,
                            child: const Text(
                              'RELEASE THE SEAL',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _release() {
    // Close first so the burn is watched on the plate itself.
    Navigator.of(context).pop();
    widget.onBurnComplete();
  }
}

class _BreathRingPainter extends CustomPainter {
  _BreathRingPainter({required this.theme, required this.volume, required this.scale, this.cycleFraction});

  final SigilSkinTheme theme;

  final double volume;
  final double scale;

  /// With reduced motion the ring stays still and a thin arc shows progress.
  final double? cycleFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = 40 * scale;
    canvas.drawCircle(c, r, Paint()..color = theme.canvasBackground);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = theme.inkPrimary.withValues(alpha: 0.2 + volume * 0.5),
    );
    final f = cycleFraction;
    if (f != null) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + 6),
        -math.pi / 2,
        2 * math.pi * f,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = theme.seal.withValues(alpha: 0.6),
      );
    }
    canvas.drawCircle(c, 4, Paint()..color = theme.seal);
  }

  @override
  bool shouldRepaint(covariant _BreathRingPainter old) =>
      old.volume != volume || old.scale != scale || old.cycleFraction != cycleFraction || old.theme != theme;
}
