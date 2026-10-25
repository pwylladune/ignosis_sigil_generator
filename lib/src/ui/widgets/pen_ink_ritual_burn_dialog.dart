import 'package:flutter/material.dart';
import '../theme/ignosis_theme.dart';

/// Clean Pen & Ink architectural modal for Gnosis breathing and combustion
class PenInkRitualBurnDialog extends StatefulWidget {
  final VoidCallback onBurnComplete;
  /// Null hides the on-chain option (see kEnableChain).
  final VoidCallback? onBurnOnChainRequested;

  const PenInkRitualBurnDialog({
    super.key,
    required this.onBurnComplete,
    this.onBurnOnChainRequested,
  });

  @override
  State<PenInkRitualBurnDialog> createState() => _PenInkRitualBurnDialogState();
}

class _PenInkRitualBurnDialogState extends State<PenInkRitualBurnDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  int _ritualStep = 0; // 0: Charging / Gnosis, 1: Burning

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                  Text(
                    _ritualStep == 0 ? 'GNOSIS CHARGING RITE' : 'COMBUSTION IN PROGRESS',
                    style: const TextStyle(
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

              if (_ritualStep == 0) ...[
                const Text(
                  'Focus your undivided conscious attention on the center bind-point. '
                  'Inhale will into the geometric lattice. On the expansion, let all words dissolve. '
                  'When your focus peaks, release the seal to the ether.',
                  style: TextStyle(color: IgnosisTheme.charcoal, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Pen & Ink Breath Sphere
                AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, child) {
                    final scale = 0.85 + (_breathController.value * 0.3);
                    final isInhaling = _breathController.status == AnimationStatus.forward;
                    return Column(
                      children: [
                        Container(
                          width: 80 * scale,
                          height: 80 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: IgnosisTheme.paperWhite,
                            border: Border.all(
                              color: IgnosisTheme.sumiInk.withValues(alpha: 0.2 + (_breathController.value * 0.5)),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: IgnosisTheme.vermilion.withValues(alpha: 0.08 * _breathController.value),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: IgnosisTheme.vermilion,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isInhaling ? 'INHALE · DRAW GNOSIS' : 'EXHALE · RELEASE ATTACHMENT',
                          style: const TextStyle(
                            color: IgnosisTheme.sumiInk,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: IgnosisTheme.sumiInk,
                          side: const BorderSide(color: IgnosisTheme.parchmentSubtle),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          setState(() => _ritualStep = 1);
                          widget.onBurnComplete();
                          await Future.delayed(const Duration(milliseconds: 3800));
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text(
                          'FREE LOCAL BURN',
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
              ] else ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: IgnosisTheme.vermilion, strokeWidth: 2),
                const SizedBox(height: 24),
                const Text(
                  'CONSUMING MEDIUM...\n"Does not matter, need not be."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: IgnosisTheme.charcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scrubbing all traces from memory to honor subconscious release.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: IgnosisTheme.pencilGraphite, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
