import 'package:flutter/material.dart';

/// Interactive modal for executing the Gnosis Charging Trance & The Ritual Burn
class RitualBurnDialog extends StatefulWidget {
  final VoidCallback onBurnComplete;
  final VoidCallback onBurnOnChainRequested;
  final bool isWalletConnected;

  const RitualBurnDialog({
    super.key,
    required this.onBurnComplete,
    required this.onBurnOnChainRequested,
    this.isWalletConnected = false,
  });

  @override
  State<RitualBurnDialog> createState() => _RitualBurnDialogState();
}

class _RitualBurnDialogState extends State<RitualBurnDialog>
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade700.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrange.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.deepOrangeAccent),
                const SizedBox(width: 8),
                Text(
                  _ritualStep == 0 ? 'GNOSIS CHARGING RITE' : 'COMBUSTION IN PROGRESS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_ritualStep == 0) ...[
              const Text(
                'Direct undivided focus into the sigil. Inhale energy on the expansion, exhale intention on the contraction. When your focus peaks, release the seal to the ether.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _breathController,
                builder: (context, child) {
                  final scale = 0.85 + (_breathController.value * 0.3);
                  final isInhaling = _breathController.status == AnimationStatus.forward;
                  return Column(
                    children: [
                      Container(
                        width: 90 * scale,
                        height: 90 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.deepOrangeAccent.withOpacity(0.8),
                              Colors.amberAccent.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isInhaling ? 'INHALE GNOSIS' : 'EXHALE WILL',
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ABORT', style: TextStyle(color: Colors.white38)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () async {
                      setState(() => _ritualStep = 1);
                      widget.onBurnComplete();
                      await Future.delayed(const Duration(milliseconds: 3800));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.whatshot, size: 18),
                    label: const Text('LOCAL RITUAL BURN'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: BorderSide(color: Colors.amber.shade700),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onBurnOnChainRequested();
                },
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('CONSECRATE WITH \$IGNOSIS'),
              ),
            ] else ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.deepOrangeAccent),
              const SizedBox(height: 20),
              const Text(
                'Consuming form...\nPurging attachment...\n"Does not matter, need not be."',
                style: TextStyle(color: Colors.amber, fontStyle: FontStyle.italic, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
