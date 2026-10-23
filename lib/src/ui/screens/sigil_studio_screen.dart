import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';
import '../../services/universal_export_service.dart';
import '../widgets/ember_particle_painter.dart';
import '../widgets/ritual_burn_dialog.dart';
import '../widgets/sigil_painter.dart';

class SigilStudioScreen extends StatefulWidget {
  const SigilStudioScreen({super.key});

  @override
  State<SigilStudioScreen> createState() => _SigilStudioScreenState();
}

class _SigilStudioScreenState extends State<SigilStudioScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _textController;
  late final AnimationController _phaseController;
  late final AnimationController _burnController;

  final GlobalKey _canvasKey = GlobalKey();

  SigilState _state = const SigilState();
  IntentKernel _kernel = IntentKernel.fromText('I COMMAND RADIANT CLARITY');

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _state.rawIntent);

    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _burnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _burnController.addListener(() {
      setState(() {
        _state = _state.copyWith(burnProgress: _burnController.value);
        if (_burnController.isCompleted) {
          _state = _state.copyWith(
            isIncinerated: true,
            rawIntent: '',
          );
          _textController.clear();
          _kernel = IntentKernel.fromText('');
        }
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _phaseController.dispose();
    _burnController.dispose();
    super.dispose();
  }

  void _onIntentChanged(String value) {
    setState(() {
      _state = _state.copyWith(
        rawIntent: value,
        isIncinerated: false,
        burnProgress: 0.0,
      );
      _kernel = IntentKernel.fromText(value);
      _burnController.reset();
    });
  }

  Future<void> _exportSigil() async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final bytes = await UniversalExportService.capturePng(boundary);
    if (bytes != null) {
      await UniversalExportService.shareSigilPng(bytes, 'ignosis_sigil');
    }
  }

  void _triggerLocalBurn() {
    _burnController.forward(from: 0.0);
  }

  void _showBurnModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RitualBurnDialog(
        onBurnComplete: _triggerLocalBurn,
        onBurnOnChainRequested: () {
          // Trigger on-chain burn
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connecting to Solana RPC for \$IGNOSIS consecration...'),
              backgroundColor: Color(0xFF1A1A24),
            ),
          );
          _triggerLocalBurn();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amberAccent, width: 1.5),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'IGNOSIS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 4.0,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white70),
            tooltip: 'Export Consecrated Sigil',
            onPressed: _state.isIncinerated ? null : _exportSigil,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top: Statement of Intent input + Kernel status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _textController,
                    onChanged: _onIntentChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter Statement of Intent (e.g. MY WILL IS UNBREAKABLE)',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF121218),
                      prefixIcon: const Icon(Icons.fingerprint, color: Colors.amberAccent, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amberAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_kernel.reducedConsonants.isNotEmpty)
                    Row(
                      children: [
                        const Text(
                          'SPARE REDUCED KERNEL: ',
                          style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.2),
                        ),
                        Text(
                          _kernel.reducedConsonants.split('').join(' · '),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Middle: Interactive Sigil Canvas with Particle Combustion Layer
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0F),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _state.isIncinerated
                            ? Colors.red.shade900.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _state.primaryColor.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: RepaintBoundary(
                      key: _canvasKey,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_phaseController, _burnController]),
                        builder: (context, child) {
                          if (_state.isIncinerated) {
                            return const Center(
                              child: Text(
                                'SEAL DISSOLVED INTO CHAOS\n"Does not matter, need not be."',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            );
                          }

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // The Sacred Geometry Path
                              CustomPaint(
                                painter: SigilPainter(
                                  state: _state,
                                  kernel: _kernel,
                                  animationPhase: _phaseController.value,
                                ),
                              ),
                              // Rising Embers during Burn
                              CustomPaint(
                                painter: EmberParticlePainter(
                                  progress: _state.burnProgress,
                                  time: _phaseController.value * 10,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // System Selector Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: SigilSystem.values.map((sys) {
                  final isSelected = _state.system == sys;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(sys.title),
                      selected: isSelected,
                      selectedColor: Colors.amberAccent.withValues(alpha: 0.2),
                      backgroundColor: const Color(0xFF14141E),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.amberAccent : Colors.white60,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? Colors.amberAccent : Colors.white10,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _state = _state.copyWith(system: sys));
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Secondary Controls (Planetary Kamea selector / Color Palettes / Burn CTA)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F16),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Palette Selector
                  Wrap(
                    spacing: 8,
                    children: [
                      const Color(0xFF00E5FF), // Cyan radiance
                      const Color(0xFFFFD700), // Solar Gold
                      const Color(0xFFFF1744), // Mars Crimson
                      const Color(0xFF76FF03), // Venus Emerald
                      const Color(0xFFE040FB), // Astral Violet
                    ].map((col) {
                      final isSelected = _state.primaryColor == col;
                      return GestureDetector(
                        onTap: () => setState(() => _state = _state.copyWith(primaryColor: col)),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Spacer(),
                  // The Burn Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD84315),
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shadowColor: Colors.deepOrangeAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _state.isIncinerated ? null : _showBurnModal,
                    icon: const Icon(Icons.whatshot, size: 18),
                    label: const Text(
                      'BURN / CONSECRATE',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
