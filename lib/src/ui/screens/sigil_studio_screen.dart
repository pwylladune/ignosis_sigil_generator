import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';
import '../../services/universal_export_service.dart';
import '../theme/ignosis_theme.dart';
import '../widgets/ember_particle_painter.dart';
import '../widgets/pen_ink_ritual_burn_dialog.dart';
import '../widgets/pen_ink_sigil_painter.dart';
import '../widgets/ritual_exegesis_modal.dart';
import '../widgets/wallet_consecration_modal.dart';

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

  SigilState _state = const SigilState(
    primaryColor: IgnosisTheme.sumiInk,
    strokeWidth: 2.0,
  );
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

  void _showExegesisModal() {
    showDialog(
      context: context,
      builder: (context) => const RitualExegesisModal(),
    );
  }

  void _showWalletBankModal() {
    showDialog(
      context: context,
      builder: (context) => WalletConsecrationModal(
        rawIntent: _state.rawIntent,
        onBurnSuccess: (txSig, amount) {
          _triggerLocalBurn();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: IgnosisTheme.sumiInk,
              content: Text('Sacrifice Recorded on Solana: ${txSig.substring(0, 16)}... (Burned $amount \$IGNOSIS)'),
            ),
          );
        },
      ),
    );
  }

  void _showBurnModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PenInkWitualBurnDialog(
        onBurnComplete: _triggerLocalBurn,
        onBurnOnChainRequested: _showWalletBankModal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IgnosisTheme.bone,
      appBar: AppBar(
        backgroundColor: IgnosisTheme.bone,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: IgnosisTheme.sumiInk, width: 1.2),
              ),
              child: const Text('🜂', style: TextStyle(fontSize: 12, color: IgnosisTheme.vermilion)),
            ),
            const SizedBox(width: 8),
            const Text(
              'IGNOSIS',
              style: TextStyle(
                color: IgnosisTheme.sumiInk,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.0,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: IgnosisTheme.charcoal, size: 20),
            tooltip: 'The Ritual & Chaos Philosophy',
            onPressed: _showExegesisModal,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined, color: IgnosisTheme.charcoal, size: 20),
            tooltip: '\$IGNOSIS Solana Bank & Burn',
            onPressed: _showWalletBankModal,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, color: IgnosisTheme.charcoal, size: 20),
            tooltip: 'Export Vector / Seal',
            onPressed: _state.isIncinerated ? null : _exportSigil,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Statement of Intent Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _textController,
                    onChanged: _onIntentChanged,
                    style: const TextStyle(
                      color: IgnosisTheme.sumiInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Statement of Intent (e.g. MY WILL IS UNBREAKABLE)',
                      hintStyle: const TextStyle(color: IgnosisTheme.pencilGraphite, fontSize: 13),
                      filled: true,
                      fillColor: IgnosisTheme.surfaceElevated,
                      prefixIcon: const Icon(Icons.edit_note, color: IgnosisTheme.charcoal, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: IgnosisTheme.parchmentSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: IgnosisTheme.parchmentSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: IgnosisTheme.sumiInk, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_kernel.reducedConsonants.isNotEmpty)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'AUSTIN OSMAN SPARE KERNEL: ',
                          style: TextStyle(
                            color: IgnosisTheme.pencilGraphite,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          _kernel.reducedConsonants.split('').join(' · '),
                          style: const TextStyle(
                            color: IgnosisTheme.vermilion,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                        InkWell(
                          onTap: _showExegesisModal,
                          child: const Text(
                            'Why reduce? 🛈',
                            style: TextStyle(fontSize: 11, color: IgnosisTheme.pencilGraphite, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Archival Parchment Canvas Viewport
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: IgnosisTheme.paperWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _state.isIncinerated
                            ? IgnosisTheme.vermilion.withValues(alpha: 0.3)
                            : IgnosisTheme.parchmentSubtle,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: IgnosisTheme.sumiInk.withValues(alpha: 0.04),
                          blurRadius: 30,
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'SEAL DISSOLVED INTO THE VOID',
                                    style: TextStyle(
                                      color: IgnosisTheme.charcoal,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '"Does not matter, need not be."\nReleased to subconscious execution.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: IgnosisTheme.pencilGraphite,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // The Clean Pen & Ink Sigil Geometry
                              CustomPaint(
                                painter: PenInkSigilPainter(
                                  state: _state,
                                  kernel: _kernel,
                                  animationPhase: _phaseController.value,
                                ),
                              ),
                              // Delicate Rising Cinders / Spark Layer
                              CustomPaint(
                                painter: EmberParticlePainter(
                                  progress: _state.burnProgress,
                                  time: _phaseController.value * 10,
                                  emberColor: IgnosisTheme.cinderAmber,
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

            // System Selector Tabs (Parchment Pill Style)
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
                      selectedColor: IgnosisTheme.surfaceElevated,
                      backgroundColor: IgnosisTheme.paperWhite,
                      labelStyle: TextStyle(
                        color: isSelected ? IgnosisTheme.sumiInk : IgnosisTheme.pencilGraphite,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        letterSpacing: 0.5,
                      ),
                      side: BorderSide(
                        color: isSelected ? IgnosisTheme.sumiInk : IgnosisTheme.parchmentSubtle,
                        width: isSelected ? 1.2 : 1.0,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _state = _state.copyWith(system: sys));
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Bottom Bar: Ink Tones, Stroke Slider, and Burn Trigger
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: IgnosisTheme.surfaceElevated,
                border: Border(top: BorderSide(color: IgnosisTheme.parchmentSubtle)),
              ),
              child: Row(
                children: [
                  // Classic Drafting Inks
                  Wrap(
                    spacing: 8,
                    children: [
                      IgnosisTheme.sumiInk,        // Deep drafting black
                      IgnosisTheme.vermilion,      // Alchemical red
                      IgnosisTheme.lapisBlue,       // Astrological lapis
                      IgnosisTheme.pencilGraphite,  // Drafting pencil
                    ].map((col) {
                      final isSelected = _state.primaryColor == col;
                      return GestureDetector(
                        onTap: () => setState(() => _state = _state.copyWith(primaryColor: col)),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? IgnosisTheme.sumiInk : IgnosisTheme.parchmentSubtle,
                              width: isSelected ? 2.5 : 1.0,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Spacer(),
                  // The Burn Button (Refined minimal vermilion seal)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IgnosisTheme.sumiInk,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _state.isIncinerated ? null : _showBurnModal,
                    icon: const Icon(Icons.whatshot, size: 16, color: IgnosisTheme.vermilion),
                    label: const Text(
                      'RITUAL COMBUSTION',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 11),
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
