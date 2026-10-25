import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../engines/kamea_engine.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';
import '../../services/iap_service.dart';
import '../../services/sigil_print_service.dart';
import '../../services/universal_export_service.dart';
import '../../motion/breath.dart';
import '../canvas/sigil_canvas.dart';
import '../canvas/sigil_spec.dart';
import '../theme/sigil_skins.dart';
import '../widgets/pay_schema_modal.dart';
import '../widgets/pen_ink_ritual_burn_dialog.dart';
import '../widgets/ritual_exegesis_modal.dart';
import '../widgets/skin_selector_modal.dart';
import 'chaos_wiki_screen.dart';

class SigilStudioScreen extends StatefulWidget {
  const SigilStudioScreen({super.key});

  @override
  State<SigilStudioScreen> createState() => _SigilStudioScreenState();
}

class _SigilStudioScreenState extends State<SigilStudioScreen> {
  late final TextEditingController _textController;
  final SigilBurnController _burn = SigilBurnController();
  final BreathSignal _breath = BreathSignal();
  bool _isBurning = false;


  SigilSkinId _currentSkinId = SigilSkinId.vellumDraft;
  SigilSkinTheme get _skinTheme => SigilSkinTheme.getSkin(_currentSkinId);

  SigilState _state = const SigilState();
  IntentKernel _kernel = IntentKernel.fromText('I COMMAND RADIANT CLARITY');

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _state.rawIntent);
    IapService.instance.addListener(_enforceSkinEntitlement);
    _restoreSkin();
  }

  static const _skinPrefsKey = 'ignosis_selected_skin';

  /// Restores the last selected skin, if it is (still) unlocked.
  Future<void> _restoreSkin() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_skinPrefsKey);
    final match = SigilSkinId.values.where((s) => s.key == saved);
    if (!mounted || match.isEmpty) return;
    _savedSkin = match.first;
    _enforceSkinEntitlement();
  }

  SigilSkinId? _savedSkin;

  /// Applies the saved skin once entitled, and falls back to the free skin if
  /// the current one is not (for example a saved skin whose unlock is not on
  /// this device yet; refunds are not revoked locally, see IapService).
  void _enforceSkinEntitlement() {
    if (!mounted) return;
    final iap = IapService.instance;
    var next = _currentSkinId;
    final saved = _savedSkin;
    if (saved != null && iap.isSkinUnlocked(saved.key)) next = saved;
    if (!iap.isSkinUnlocked(next.key)) next = SigilSkinId.vellumDraft;
    if (next != _currentSkinId) setState(() => _currentSkinId = next);
  }

  Future<void> _selectSkin(SigilSkinId skin) async {
    if (!IapService.instance.isSkinUnlocked(skin.key)) return;
    setState(() => _currentSkinId = skin);
    _savedSkin = skin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skinPrefsKey, skin.key);
  }

  @override
  void dispose() {
    IapService.instance.removeListener(_enforceSkinEntitlement);
    _textController.dispose();
    _burn.dispose();
    _breath.dispose();
    super.dispose();
  }

  void _onIntentChanged(String value) {
    setState(() {
      _state = _state.copyWith(rawIntent: value, isIncinerated: false);
      _kernel = IntentKernel.fromText(value, stripVowels: _state.stripVowels);
    });
  }

  /// The settled seal for the current spec, rendered offscreen: never a
  /// half-written or half-burnt frame, and always on the skin's paper.
  Future<Uint8List?> _settledSealPng() async =>
      UniversalExportService.encodePng(await renderSettledSeal(_spec, _skinTheme));

  bool get _canExport => !_state.isIncinerated && !_isBurning && !_kernel.isEmpty;

  Future<void> _exportSigil() async {
    final bytes = await _settledSealPng();
    if (bytes != null) {
      await UniversalExportService.shareSigilPng(bytes, 'ignosis_sigil');
    }
  }

  Future<void> _printPhysicalSheet() async {
    final bytes = await _settledSealPng();
    if (bytes != null) {
      await SigilPrintService.printPhysicalBurnSheet(
        pngBytes: bytes,
        reducedKernel: _kernel.reducedConsonants,
        systemTitle: _state.system.title,
      );
    }
  }

  SigilSpec get _spec => SigilSpec(
        kernel: _kernel,
        system: _state.system,
        kameaType: _state.kameaType,
        symmetryFolds: _state.symmetryFolds,
        symmetryGroup: _state.symmetryGroup,
      );

  void _triggerLocalBurn() {
    if (_isBurning) return;
    setState(() => _isBurning = true);
    _burn.ignite();
  }

  void _onIncinerated() {
    if (!mounted) return;
    setState(() {
      _isBurning = false;
      _state = _state.copyWith(isIncinerated: true, rawIntent: '');
      _textController.clear();
      _kernel = IntentKernel.fromText('');
    });
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
        onSkinSelected: _selectSkin,
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

  void _showBurnModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (context) => PenInkRitualBurnDialog(
        onBurnComplete: _triggerLocalBurn,
        breath: _breath,
      ),
    );
  }

  /// Options for the selected system (planet for Kamea; folds and group for
  /// the symmetric systems). Empty for systems without options.
  Widget _buildSystemOptions(SigilSkinTheme theme) {
    final chips = <Widget>[];
    Widget chip(String label, bool selected, VoidCallback onTap, {String? tooltip}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Tooltip(
            message: tooltip ?? '',
            child: InkWell(
              onTap: _isBurning ? null : onTap,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: selected ? theme.accent : theme.hairline),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? theme.inkPrimary : theme.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        );

    switch (_state.system) {
      case SigilSystem.kamea:
        for (final t in PlanetaryKameaType.values) {
          chips.add(chip(
            t.label.split(' ').first,
            _state.kameaType == t,
            () => setState(() => _state = _state.copyWith(kameaType: t)),
            tooltip: '${t.label}: ${t.aspect}',
          ));
        }
      case SigilSystem.spare:
      case SigilSystem.cyberChaos:
      case SigilSystem.chladni:
        if (_state.system != SigilSystem.cyberChaos) {
          // How letters are reduced: Carroll's method, or the modern convention.
          for (final strip in const [false, true]) {
            chips.add(chip(
              strip ? 'NO VOWELS (MODERN)' : 'KEEP VOWELS (CARROLL)',
              _state.stripVowels == strip,
              () => setState(() {
                _state = _state.copyWith(stripVowels: strip);
                _kernel = IntentKernel.fromText(_state.rawIntent, stripVowels: strip);
              }),
              tooltip: strip
                  ? 'Strike out repeated letters and vowels (a later popular convention)'
                  : 'Strike out repeated letters only (Carroll, Liber Null)',
            ));
          }
          if (_state.system == SigilSystem.chladni) break;
          chips.add(const SizedBox(width: 8));
        }
        if (_state.system == SigilSystem.spare) {
          for (final g in SymmetryGroup.values) {
            chips.add(chip(
              g == SymmetryGroup.cyclic ? 'ROTATE' : 'ROTATE + MIRROR',
              _state.symmetryGroup == g,
              () => setState(() => _state = _state.copyWith(symmetryGroup: g)),
              tooltip: g == SymmetryGroup.cyclic ? 'Cyclic group Cₙ' : 'Dihedral group Dₙ',
            ));
          }
          chips.add(const SizedBox(width: 8));
        }
        for (final n in const [1, 2, 3, 4, 5, 6, 8]) {
          final sym = _state.system == SigilSystem.spare ? _state.symmetryGroup.symbol : 'C';
          chips.add(chip(
            '$sym$n',
            _state.symmetryFolds == n,
            () => setState(() => _state = _state.copyWith(symmetryFolds: n)),
            tooltip: '$n-fold symmetry',
          ));
        }
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: chips),
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
            onPressed: _canExport ? _printPhysicalSheet : null,
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
            icon: Icon(Icons.ios_share, color: theme.inkSecondary, size: 20),
            tooltip: 'Share seal (PNG)',
            onPressed: _canExport ? _exportSigil : null,
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
                    // A released seal burns to the end; the intent is fixed meanwhile.
                    enabled: !_isBurning,
                    // The intent is private: keep it out of the keyboard's
                    // learned (and possibly cloud-synced) dictionary.
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
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
                          'KERNEL: ',
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
                      child: _state.isIncinerated
                          ? _IncineratedPlate(theme: theme)
                          : SigilCanvas(
                              spec: _spec,
                              skin: theme,
                              burn: _burn,
                              onIncinerated: _onIncinerated,
                              breath: _breath,
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
                      onSelected: _isBurning
                          ? null
                          : (val) {
                              if (val) setState(() => _state = _state.copyWith(system: sys));
                            },
                    ),
                  );
                }).toList(),
              ),
            ),

            _buildSystemOptions(theme),

            const SizedBox(height: 10),

            // Bottom Bar: Ink Tones, Stroke Slider, and Burn Trigger
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border(top: BorderSide(color: theme.hairline)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Current Skin Label Tag (shrinks with an ellipsis on narrow phones)
                  Flexible(
                    child: InkWell(
                    onTap: _showSkinModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette_outlined, size: 14, color: theme.accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                            _currentSkinId.label.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: theme.inkPrimary,
                            ),
                          ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(width: 12),
                  // The Burn Button (Refined minimal vermilion seal)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.inkPrimary,
                      foregroundColor: theme.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _state.isIncinerated || _isBurning || _kernel.isEmpty ? null : _showBurnModal,
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

/// The empty plate after combustion: silence, then the banishing line.
class _IncineratedPlate extends StatefulWidget {
  const _IncineratedPlate({required this.theme});

  final SigilSkinTheme theme;

  @override
  State<_IncineratedPlate> createState() => _IncineratedPlateState();
}

class _IncineratedPlateState extends State<_IncineratedPlate> {
  bool _visible = false;
  bool _laughed = false;

  @override
  void initState() {
    super.initState();
    // Hold the empty plate for about two seconds before speaking.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SEAL DISSOLVED INTO THE VOID',
              style: TextStyle(color: theme.inkSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.0),
            ),
            const SizedBox(height: 6),
            Text(
              '"Does not matter—need not be."\n(Spare, The Book of Pleasure)',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.inkMuted, fontSize: 12, fontStyle: FontStyle.italic, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _laughed ? null : () => setState(() => _laughed = true),
              child: Text(
                _laughed ? 'Ha.' : 'BANISH WITH LAUGHTER',
                style: TextStyle(color: theme.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
