import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';
import '../../services/sigil_print_service.dart';
import '../../services/universal_export_service.dart';
import '../theme/sigil_skins.dart';
import '../widgets/ember_particle_painter.dart';
import '../widgets/pay_schema_modal.dart';
import '../widgets/pen_ink_ritual_burn_dialog.dart';
import '../widgets/pen_ink_sigil_painter.dart';
import '../widgets/ritual_exegesis_modal.dart';
import '../widgets/skin_selector_modal.dart';
import '../widgets/wallet_consecration_modal.dart';
import 'chaos_wiki_screen.dart';

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

  SigilSkinId _currentSkinId = SigilSkinId.vellumDraft;
  SigilSkinTheme get _skinTheme => SigilSkinTheme.getSkin(_currentSkinId);

  SigilState _state = const SigilState(
    primaryColor: Color(0xFF141416),
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

  Future<void> _printPhysicalSheet() async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final bytes = await UniversalExportService.capturePng(boundary);
    if (bytes != null) {
      await SigilPrintService.printPhysicalBurnSheet(
        pngBytes: bytes,
        rawIntent: _state.rawIntent,
        reducedKernel: _kernel.reducedConsonants,
        systemTitle: _state.system.title,
      );
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

  void _showSkinModal() {
    showDialog(
      context: context,
      builder: (context) => SkinSelectorModal(
        currentSkinId: _currentSkinId,
        theme: _skinTheme,
        onSkinSelected: (newSkin) {
          setState(() {
            _currentSkinId = newSkin;
            _state = _state.copyWith(
              primaryColor: SigilSkinTheme.getSkin(newSkin).inkPrimary,
            );
          });
        },
      ),
    );
  }

  void _showPayModal() {
    showDialog(
      context: context,
      builder: (context) => PaySchemaModal(theme: _skinTheme),
    );
  }

  void _openWikiScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChaosWikiScreen(theme: _skinTheme),
      ),
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
              backgroundColor: _skinTheme.inkPrimary,
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
    final theme = _skinTheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.inkPrimary, width: 1.2),
              ),
              child: Text('🜂', style: TextStyle(fontSize: 12, color: theme.accent)),
            ),
            const SizedBox(width: 8),
            Text(
              'IGNOSIS',
              style: TextStyle(
                color: theme.inkPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.0,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.palette_outlined, color: theme.inkSecondary, size: 20),
            tooltip: 'Aesthetic Skins (${_currentSkinId.label})',
            onPressed: _showSkinModal,
          ),
          IconButton(
            icon: Icon(Icons.print_outlined, color: theme.inkSecondary, size: 20),
            tooltip: 'Print Archival Burn Sheet',
            onPressed: _state.isIncinerated ? null : _printPhysicalSheet,
          ),
          IconButton(
            icon: Icon(Icons.auto_stories_outlined, color: theme.inkSecondary, size: 20),
            tooltip: 'Chaos Magic Archives & Interview Wiki',
            onPressed: _openWikiScreen,
          ),
          IconButton(
            icon: Icon(Icons.card_membership_outlined, color: theme.inkSecondary, size: 20),
            tooltip: 'Pay Schema & Memberships',
            onPressed: _showPayModal,
          ),
          IconButton(
            icon: Icon(Icons.account_balance_wallet_outlined, color: theme.inkSecondary, size: 20),
            tooltip: '\$IGNOSIS Solana Bank & Burn',
            onPressed: _showWalletBankModal,
          ),
          IconButton(
            icon: Icon(Icons.ios_share, color: theme.inkSecondary, size: 20),
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
                    style: TextStyle(
                      color: theme.inkPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Statement of Intent (e.g. MY WILL IS UNBREAKABLE)',
                      hintStyle: TextStyle(color: theme.inkMuted, fontSize: 13),
                      filled: true,
                      fillColor: theme.surface,
                      prefixIcon: Icon(Icons.edit_note, color: theme.inkSecondary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.inkPrimary, width: 1.2),
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
                        Text(
                          'AUSTIN OSMAN SPARE KERNEL: ',
                          style: TextStyle(
                            color: theme.inkMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          _kernel.reducedConsonants.split('').join(' · '),
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                        InkWell(
                          onTap: _showExegesisModal,
                          child: Text(
                            'Why reduce? 🛈',
                            style: TextStyle(fontSize: 11, color: theme.inkMuted, decoration: TextDecoration.underline),
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
                      color: theme.canvasBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _state.isIncinerated
                            ? theme.accent.withValues(alpha: 0.3)
                            : theme.hairline,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.inkPrimary.withValues(alpha: theme.id.isDark ? 0.3 : 0.04),
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
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'SEAL DISSOLVED INTO THE VOID',
                                    style: TextStyle(
                                      color: theme.inkSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '"Does not matter, need not be."\nReleased to subconscious execution.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.inkMuted,
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
                                  emberColor: theme.burn,
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
                      selectedColor: theme.surfaceElevated,
                      backgroundColor: theme.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? theme.inkPrimary : theme.inkMuted,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        letterSpacing: 0.5,
                      ),
                      side: BorderSide(
                        color: isSelected ? theme.inkPrimary : theme.hairline,
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
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border(top: BorderSide(color: theme.hairline)),
              ),
              child: Row(
                children: [
                  // Current Skin Label Tag
                  InkWell(
                    onTap: _showSkinModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.hairline),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 14, color: theme.accent),
                          const SizedBox(width: 6),
                          Text(
                            _currentSkinId.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: theme.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // The Burn Button (Refined minimal vermilion seal)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.inkPrimary,
                      foregroundColor: theme.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _state.isIncinerated ? null : _showBurnModal,
                    icon: Icon(Icons.whatshot, size: 16, color: theme.accent),
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

