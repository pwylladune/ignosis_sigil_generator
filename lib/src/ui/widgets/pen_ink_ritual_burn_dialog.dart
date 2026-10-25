import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../motion/breath.dart';
import '../theme/ignosis_theme.dart';

/// Clean Pen & Ink architectural modal for Gnosis breathing and combustion.
///
/// The breath curve `b(t)` from [BreathPattern] is the master rhythm: it scales
/// the guide ring here and is published to [breath] so the sigil on the canvas
/// breathes with it. The dialog never auto-advances; after [targetCycles] the
/// release is offered more prominently.
class PenInkRitualBurnDialog extends StatefulWidget {
  final VoidCallback onBurnComplete;

  /// Null hides the on-chain option (see kEnableChain).
  final VoidCallback? onBurnOnChainRequested;

  /// Shared breath volume, null when not breathing.
  final ValueNotifier<double?>? breath;

  final int targetCycles;

  const PenInkRitualBurnDialog({
    super.key,
    required this.onBurnComplete,
    this.onBurnOnChainRequested,
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
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final sample = _pattern.sample(_t - _patternStart);
    final peaked = sample.cycle >= widget.targetCycles;
    final b = sample.volume;
    final scale = reduceMotion ? 1.0 : 0.85 + b * 0.3;

    return Dialog(
      // Sit low so the breathing seal stays visible above the dialog.
      alignment: Alignment.bottomCenter,
      backgroundColor: IgnosisTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: IgnosisTheme.parchmentSubtle),
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
                      color: IgnosisTheme.bone,
                      shape: BoxShape.circle,
                      border: Border.all(color: IgnosisTheme.parchmentSubtle),
                    ),
                    child: const Center(
                      child: Text('🜂', style: TextStyle(color: IgnosisTheme.vermilion, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'GNOSIS CHARGING RITE',
                    style: TextStyle(
                      color: IgnosisTheme.sumiInk,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: IgnosisTheme.pencilGraphite),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24, color: IgnosisTheme.parchmentSubtle),

              const Text(
                'Focus your undivided attention on the center bind-point. '
                'Breathe with the ring; the seal breathes with you. '
                'When your focus peaks, release the seal.',
                style: TextStyle(color: IgnosisTheme.charcoal, fontSize: 13, height: 1.5),
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
                    selectedColor: IgnosisTheme.bone,
                    backgroundColor: IgnosisTheme.surfaceElevated,
                    side: BorderSide(color: selected ? IgnosisTheme.sumiInk : IgnosisTheme.parchmentSubtle),
                    labelStyle: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? IgnosisTheme.sumiInk : IgnosisTheme.pencilGraphite,
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
                    volume: b,
                    scale: scale,
                    cycleFraction: reduceMotion ? ((_t - _patternStart) % _pattern.period) / _pattern.period : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _phaseLabel(sample.phase),
                style: const TextStyle(
                  color: IgnosisTheme.sumiInk,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'BREATH ${math.min(sample.cycle + 1, widget.targetCycles)} / ${widget.targetCycles}',
                style: const TextStyle(color: IgnosisTheme.pencilGraphite, letterSpacing: 1.4, fontSize: 9),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: peaked
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: IgnosisTheme.sumiInk,
                              foregroundColor: Colors.white,
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
                              foregroundColor: IgnosisTheme.sumiInk,
                              side: const BorderSide(color: IgnosisTheme.parchmentSubtle),
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
                  if (widget.onBurnOnChainRequested != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IgnosisTheme.sumiInk,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onBurnOnChainRequested!();
                        },
                        icon: const Icon(Icons.bolt, size: 16, color: IgnosisTheme.vermilion),
                        label: const Text(
                          'BURN WITH \$IGNOSIS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                        ),
                      ),
                    ),
                  ],
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
  _BreathRingPainter({required this.volume, required this.scale, this.cycleFraction});

  final double volume;
  final double scale;

  /// With reduced motion the ring stays still and a thin arc shows progress.
  final double? cycleFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = 40 * scale;
    canvas.drawCircle(c, r, Paint()..color = IgnosisTheme.paperWhite);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = IgnosisTheme.sumiInk.withValues(alpha: 0.2 + volume * 0.5),
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
          ..color = IgnosisTheme.vermilion.withValues(alpha: 0.6),
      );
    }
    canvas.drawCircle(c, 4, Paint()..color = IgnosisTheme.vermilion);
  }

  @override
  bool shouldRepaint(covariant _BreathRingPainter old) =>
      old.volume != volume || old.scale != scale || old.cycleFraction != cycleFraction;
}
