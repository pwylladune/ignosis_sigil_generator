import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../motion/breath.dart';
import '../../motion/reduce_motion.dart';
import '../theme/sigil_skins.dart';

/// The rite's length for [cycles] breaths of [p], to the nearest quarter
/// minute: "about 1¼ min".
String riteLengthLabel(BreathPattern p, int cycles) {
  final quarters = math.max(1, (p.period * cycles / 15).round());
  final whole = quarters ~/ 4;
  final part = const ['', '¼', '½', '¾'][quarters % 4];
  return 'about ${whole == 0 ? part : '$whole$part'} min';
}

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

  /// Optional, folded below the release (the on-chain witness, when enabled):
  /// after the release, so it never reads as a step of the rite.
  final Widget? witness;

  const PenInkRitualBurnDialog({
    super.key,
    required this.theme,
    required this.onBurnComplete,
    this.breath,
    this.targetCycles = 7,
    this.witness,
  });

  @override
  State<PenInkRitualBurnDialog> createState() => _PenInkRitualBurnDialogState();
}

class _PenInkRitualBurnDialogState extends State<PenInkRitualBurnDialog> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  BreathPattern _pattern = BreathPattern.resonance;
  double _patternStart = 0;

  /// The pattern chips are folded away: the default needs no decision.
  bool _showPatterns = false;

  /// Seconds since the dialog opened. Only the ring repaints from this;
  /// labels and buttons rebuild when the phase or cycle actually changes.
  final _time = ValueNotifier<double>(0);
  final _phase = ValueNotifier<BreathPhase>(BreathPhase.inhale);
  final _cycle = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      _time.value = t;
      final sample = _pattern.sample(t - _patternStart);
      widget.breath?.value = sample.volume;
      if (sample.phase != _phase.value) {
        _phase.value = sample.phase;
        // A tick at each turn of the breath, for eyes-closed practice.
        HapticFeedback.selectionClick();
      }
      _cycle.value = sample.cycle;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _phase.dispose();
    _cycle.dispose();
    // Clear after this frame: the notifier's listeners may be mid-build.
    final breath = widget.breath;
    WidgetsBinding.instance.addPostFrameCallback((_) => breath?.value = null);
    super.dispose();
  }

  void _selectPattern(BreathPattern p) {
    setState(() {
      _pattern = p;
      _patternStart = _time.value;
    });
  }

  String _phaseLabel(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale:
        return 'INHALE';
      case BreathPhase.holdIn:
        return 'HOLD';
      case BreathPhase.exhale:
        return 'EXHALE · LET GO';
      case BreathPhase.holdOut:
        return 'HOLD · EMPTY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final reduceMotion = reduceMotionOf(context);

    // A compact sheet low on the screen: the plate above stays the single
    // point of focus, and its outer ring carries the breath.
    return Dialog(
      alignment: Alignment.bottomCenter,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'III · CHARGE',
                    style: TextStyle(
                        color: theme.inkPrimary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: theme.inkTertiary),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Rest your eyes on the seal and breathe with its ring. ${_cycleWord(widget.targetCycles)} breaths, '
                    '${riteLengthLabel(_pattern, widget.targetCycles)}. Then release.',
                    style: TextStyle(color: theme.inkPrimary, fontSize: 14, height: 1.4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    // Breath ring: radius and ink follow b(t); repaints alone.
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CustomPaint(
                        painter: _BreathRingPainter(
                          theme: theme,
                          time: _time,
                          pattern: _pattern,
                          patternStart: _patternStart,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<BreathPhase>(
                            valueListenable: _phase,
                            builder: (context, phase, _) => Semantics(
                              liveRegion: true,
                              child: Text(
                                _phaseLabel(phase),
                                style: TextStyle(
                                    color: theme.inkPrimary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    fontSize: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          ValueListenableBuilder<int>(
                            valueListenable: _cycle,
                            builder: (context, cycle, _) => Text(
                              'Breath ${math.min(cycle + 1, widget.targetCycles)} of ${widget.targetCycles}',
                              style: TextStyle(color: theme.inkSecondary, fontSize: 12),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: theme.inkSecondary,
                              minimumSize: const Size(44, 44),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => setState(() => _showPatterns = !_showPatterns),
                            iconAlignment: IconAlignment.end,
                            icon: Icon(_showPatterns ? Icons.expand_less : Icons.expand_more, size: 18),
                            label: Text('Change the breath · ${_pattern.label}', style: const TextStyle(fontSize: 12)),
                          ),
                          if (_showPatterns)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: BreathPattern.values.map((p) {
                                final selected = p == _pattern;
                                return ChoiceChip(
                                  label: Text(p.label),
                                  tooltip: p.description,
                                  selected: selected,
                                  showCheckmark: false,
                                  selectedColor: theme.background,
                                  backgroundColor: theme.surface,
                                  side: BorderSide(color: selected ? theme.inkPrimary : theme.hairlineStrong),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                    color: selected ? theme.inkPrimary : theme.inkTertiary,
                                  ),
                                  onSelected: (_) => _selectPattern(p),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'Breathe comfortably; stop if you feel dizzy or short of breath. A focus exercise, not medical advice.',
                  style: TextStyle(color: theme.inkSecondary, fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              // Release: always available, emphasised once the breaths are done.
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ValueListenableBuilder<int>(
                  valueListenable: _cycle,
                  builder: (context, cycle, _) {
                    final peaked = cycle >= widget.targetCycles;
                    const label = Text(
                      'IV · RELEASE THE SEAL',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
                    );
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: peaked
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.inkPrimary,
                                foregroundColor: theme.surface,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _release,
                              child: label,
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.inkPrimary,
                                side: BorderSide(color: theme.hairlineStrong),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _release,
                              child: label,
                            ),
                    );
                  },
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _cycle,
                builder: (context, cycle, _) => cycle >= widget.targetCycles
                    ? const SizedBox(height: 4)
                    : Padding(
                        padding: const EdgeInsets.only(top: 6, right: 12),
                        child: Text(
                          'You can release whenever you are ready.',
                          style: TextStyle(color: theme.inkSecondary, fontSize: 12),
                        ),
                      ),
              ),
              if (widget.witness != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: Divider(height: 1, color: theme.hairline),
                ),
                Padding(padding: const EdgeInsets.only(right: 12), child: widget.witness),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _cycleWord(int n) => n == 7 ? 'Seven' : '$n';

  void _release() {
    // Close first so the burn is watched on the plate itself.
    Navigator.of(context).pop();
    widget.onBurnComplete();
  }
}

class _BreathRingPainter extends CustomPainter {
  _BreathRingPainter({
    required this.theme,
    required this.time,
    required this.pattern,
    required this.patternStart,
    required this.reduceMotion,
  }) : super(repaint: time);

  final SigilSkinTheme theme;
  final ValueListenable<double> time;
  final BreathPattern pattern;
  final double patternStart;

  /// With reduced motion the ring stays still and a thin arc shows progress.
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value - patternStart;
    final volume = pattern.value(t);
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.36 * (reduceMotion ? 1.0 : 0.85 + volume * 0.3);
    canvas.drawCircle(c, r, Paint()..color = theme.canvasBackground);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = theme.inkPrimary.withValues(alpha: 0.2 + volume * 0.5),
    );
    if (reduceMotion) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: size.shortestSide * 0.36 + 5),
        -math.pi / 2,
        2 * math.pi * ((t % pattern.period) / pattern.period),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = theme.seal.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BreathRingPainter old) =>
      old.theme != theme ||
      old.pattern != pattern ||
      old.patternStart != patternStart ||
      old.reduceMotion != reduceMotion;
}
