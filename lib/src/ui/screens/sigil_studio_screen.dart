import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/feature_flags.dart';
import '../../config/legal_links.dart';
import '../../engines/infinite_engine.dart';
import '../../engines/kamea_engine.dart';
import '../../engines/ring_cipher_engine.dart';
import '../../models/hebrew_letters.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';
import '../../services/iap_service.dart';
import '../../services/rite/rite_service.dart';
import '../../services/sigil_print_service.dart';
import '../../services/universal_export_service.dart';
import '../../motion/breath.dart';
import '../canvas/sigil_canvas.dart';
import '../canvas/sigil_spec.dart';
import '../theme/sigil_skins.dart';
import '../widgets/pay_schema_modal.dart';
import '../widgets/ignosis_mark.dart';
import '../widgets/pen_ink_ritual_burn_dialog.dart';
import '../widgets/rite_witness.dart';
import '../widgets/ritual_exegesis_modal.dart';
import '../widgets/skin_selector_modal.dart';
import 'compendium_screen.dart';

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

  /// A locked skin shown behind the skin dialog while the user considers it.
  SigilSkinId? _previewSkinId;

  SigilSkinTheme get _skinTheme => SigilSkinTheme.getSkin(_previewSkinId ?? _currentSkinId);

  /// The purpose of the work (the owner's words), now in the "?" sheet.
  static const _purpose = 'IGNOSIS transforms intent into a sigil meant for consumption. Choose your ritual. '
      'Charge the seal with your breath. Burn it. Forget.';

  /// The rite in four steps: the first-visit card and the "?" sheet.
  static const _steps = [
    'I. Write what you will. Set your intention.',
    'II. Choose a system. IGNOSIS transforms your intent into a seal.',
    'III. Breathe seven breaths. Release. It burns.',
    'IV. Forget.',
  ];

  /// Drawn faintly on the empty plate. A fixed string, so it never varies.
  static const exampleIntent = 'I STAND WITH STRENGTH';
  static final _exampleKernel = IntentKernel.fromText(exampleIntent);

  SigilState _state = const SigilState();

  /// The Infinite: drawn by the inverse map, and the zoomed window (null = whole set).
  bool _infiniteInverted = false;
  InfiniteView? _infiniteView;
  IntentKernel _kernel = IntentKernel.fromText('');

  static const introPrefsKey = 'ignosis_intro_seen';

  /// Null until preferences load, so a returning user never sees the card flash.
  bool? _introSeen;

  final _intentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _state.rawIntent);
    IapService.instance.addListener(_enforceSkinEntitlement);
    _restoreSkin();
    _restoreIntro();
    if (kEnableRite) {
      // Off the web the rite is paid through the app store (Google Play).
      if (!kIsWeb) RiteService.instance.attachStore(IapService.instance);
      unawaited(RiteService.instance.load());
    }
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

  Future<void> _restoreIntro() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _introSeen = prefs.getBool(introPrefsKey) ?? false);
  }

  Future<void> _dismissIntro() async {
    setState(() => _introSeen = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(introPrefsKey, true);
  }

  /// First visit: the four-step card is up and Circumlocution is marked.
  bool get _firstVisit => _introSeen == false;

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
    _intentFocus.dispose();
    _burn.dispose();
    _breath.dispose();
    super.dispose();
  }

  void _onIntentChanged(String value) {
    setState(() {
      // A new intent is a new set: its old window means nothing.
      _infiniteView = null;
      _state = _state.copyWith(rawIntent: value, isIncinerated: false);
      _kernel = IntentKernel.fromText(value, stripVowels: _state.stripVowels);
    });
  }

  /// The settled seal for the current spec, rendered offscreen: never a
  /// half-written or half-burnt frame, and always on the skin's paper.
  Future<Uint8List?> _settledSealPng() async =>
      UniversalExportService.encodePng(await renderSettledSeal(_spec, _skinTheme));

  bool get _canExport => !_state.isIncinerated && !_isBurning && !_kernel.isEmpty;

  /// One entry point for getting the seal out of the app: download (in a
  /// browser), share or print.
  void _showExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _skinned(SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (UniversalExportService.canDownload)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download seal (PNG)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _downloadSigil();
                },
              ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Share seal (PNG)'),
              onTap: () {
                Navigator.of(context).pop();
                _exportSigil();
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print burn sheet'),
              subtitle: const Text('A4 or US Letter, with the seal to cut out'),
              onTap: () {
                Navigator.of(context).pop();
                _printPhysicalSheet();
              },
            ),
          ],
        ),
      )),
    );
  }

  Future<void> _downloadSigil() async {
    final bytes = await _settledSealPng();
    if (bytes != null) await UniversalExportService.downloadSigilPng(bytes, 'ignosis_sigil');
  }

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

  /// The Infinite's map and zoom, e.g. "z² + c, c = −0.4321 − 0.5631i · ×8".
  String get _infiniteLabel {
    final c = JuliaParams.fromKernel(_kernel);
    final view = _infiniteView;
    final zoom = view == null ? '' : ' · ×${_formatZoom(view.magnificationFrom(c.home))}';
    return 'z² + c, ${c.toString()}$zoom';
  }

  static String _formatZoom(double m) => m >= 1e4 ? m.toStringAsExponential(1) : m.toStringAsFixed(m < 10 ? 1 : 0);

  /// Kamea and Rose trace the Hebrew transliteration, not the reduced kernel.
  bool get _tracesHebrew => _state.system == SigilSystem.kamea || _state.system == SigilSystem.roseCross;

  bool get _isInfinite => _state.system == SigilSystem.infinite;

  SigilSpec get _spec => SigilSpec(
        kernel: _kernel,
        system: _state.system,
        kameaType: _state.kameaType,
        symmetryFolds: _state.symmetryFolds,
        symmetryGroup: _state.symmetryGroup,
        inverted: _isInfinite && _infiniteInverted,
        view: _isInfinite ? _infiniteView : null,
      );

  void _triggerLocalBurn() {
    if (_isBurning) return;
    // The on-chain witness takes the intent's commitment now, before the
    // intent is cleared; the paper burns locally either way.
    if (kEnableRite) unawaited(RiteService.instance.releaseWith(_state.rawIntent));
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

  /// After a release: back to an empty plate, ready for a new intent.
  void _makeAnother() {
    setState(() => _state = _state.copyWith(isIncinerated: false));
    _intentFocus.requestFocus();
  }

  /// "?": the rite in four steps, why sigils are forgotten, and the owner's line.
  void _showHowItWorks() {
    final theme = _skinTheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _skinned(SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepLabel(theme, 'THE RITE, IN FOUR STEPS'),
              const SizedBox(height: 8),
              for (final step in _steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(step, style: TextStyle(color: theme.inkPrimary, fontSize: 14, height: 1.4)),
                ),
              const SizedBox(height: 8),
              Text(
                'Sigils work by being forgotten: the desire is hidden from the mind that would worry it.',
                style: TextStyle(color: theme.inkSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                _purpose,
                style: TextStyle(color: theme.inkSecondary, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: theme.accent, minimumSize: const Size(44, 44)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showExegesisModal();
                    },
                    child: const Text('Why reduce? →'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: theme.accent, minimumSize: const Size(44, 44)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openCompendium();
                    },
                    child: const Text('The Compendium →'),
                  ),
                ],
              ),
            ],
          ),
        ),
      )),
    );
  }

  /// A step or section label: small caps, readable grey.
  static Widget _stepLabel(SigilSkinTheme theme, String text) => Text(
        text,
        style: TextStyle(color: theme.inkSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.4),
      );

  /// What the "drawn from" value is, per system.
  String get _drawnFromHelp {
    if (_tracesHebrew) return 'Your intent spelled in Hebrew letters, as the figures require.';
    if (_state.system == SigilSystem.ringCipher) return 'The full phrase, traced around the rings.';
    if (_isInfinite) return 'The point your intent chooses on the Mandelbrot edge.';
    return _state.stripVowels
        ? 'Your letters with repeats and vowels struck out (a modern convention).'
        : 'Your letters with repeats struck out (Carroll’s rule).';
  }

  void _showExegesisModal() {
    showDialog(
      context: context,
      builder: (context) => _skinned(RitualExegesisModal(theme: _skinTheme)),
    );
  }

  void _showSkinModal() {
    showDialog(
      context: context,
      builder: (context) => _skinned(SkinSelectorModal(
        currentSkinId: _currentSkinId,
        theme: _skinTheme,
        onSkinSelected: _selectSkin,
        onPreview: (skin) => setState(() => _previewSkinId = skin),
      )),
    ).whenComplete(() {
      // The preview ends with the dialog unless the skin was bought.
      if (mounted) setState(() => _previewSkinId = null);
    });
  }

  void _showPayModal() {
    showDialog(
      context: context,
      builder: (context) => _skinned(PaySchemaModal(theme: _skinTheme)),
    );
  }

  void _openCompendium() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _skinned(CompendiumScreen(theme: _skinTheme)),
      ),
    );
  }

  /// True while the Gnosis dialog is open.
  bool _charging = false;

  void _showBurnModal() {
    setState(() => _charging = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (context) => _skinned(PenInkRitualBurnDialog(
        theme: _skinTheme,
        onBurnComplete: _triggerLocalBurn,
        breath: _breath,
        witness: kEnableRite ? RiteWitnessFold(theme: _skinTheme, service: RiteService.instance) : null,
      )),
    ).whenComplete(() {
      if (mounted) setState(() => _charging = false);
    });
  }

  /// Options for the selected system (planet for Kamea; folds and group for
  /// the symmetric systems). Empty for systems without options.
  Widget _buildSystemOptions(SigilSkinTheme theme) {
    final chips = <Widget>[];
    // A 36 pt chip inside a 44 pt hit area (HIG; WCAG 2.2 SC 2.5.8).
    Widget chip(String label, bool selected, VoidCallback onTap, {String? tooltip}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Tooltip(
            message: tooltip ?? '',
            child: Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: _isBurning ? null : onTap,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? theme.seal : theme.hairlineStrong),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? theme.inkPrimary : theme.inkTertiary,
                      ),
                    ),
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
      case SigilSystem.infinite:
        chips.add(chip(
          'INVERT · √',
          _infiniteInverted,
          () => setState(() => _infiniteInverted = !_infiniteInverted),
          tooltip: 'Draw the set by the inverse map z ↦ ±√(z − c) instead of the rings around it',
        ));
        if (_infiniteView != null) {
          chips.add(chip('RESET VIEW', false, () => setState(() => _infiniteView = null),
              tooltip: 'Back out to the whole set'));
        }
        chips.add(Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text('Pinch, scroll or double-tap to zoom', style: TextStyle(fontSize: 12, color: theme.inkTertiary)),
        ));
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

  /// Applies the active skin's Material theme (cursor, chips, tooltips,
  /// dialogs), including to dialog routes, which sit above the studio.
  Widget _skinned(Widget child) => Theme(data: _skinTheme.toThemeData(), child: child);

  @override
  Widget build(BuildContext context) {
    final theme = _skinTheme;

    return _skinned(Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        centerTitle: true,
        // Left of the title, so the bar balances at phone width.
        leading: IconButton(
          icon: Icon(Icons.help_outline, color: theme.inkSecondary, size: 22),
          tooltip: 'How it works',
          onPressed: _showHowItWorks,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IgnosisMark(skin: theme, size: 34),
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
            icon: Icon(Icons.auto_stories_outlined, color: theme.inkSecondary, size: 22),
            tooltip: 'The Compendium',
            onPressed: _openCompendium,
          ),
          IconButton(
            icon: Icon(Icons.ios_share, color: theme.inkSecondary, size: 22),
            tooltip: 'Share or print the seal',
            onPressed: _canExport ? _showExportSheet : null,
          ),
          PopupMenuButton<VoidCallback>(
            icon: Icon(Icons.more_vert, color: theme.inkSecondary, size: 22),
            tooltip: 'More',
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(value: _showSkinModal, child: const Text('Skins')),
              PopupMenuItem(value: _showPayModal, child: const Text('Skins & support')),
              PopupMenuItem(value: _showExegesisModal, child: const Text('Why reduce?')),
              const PopupMenuDivider(),
              for (final page in LegalPage.values) PopupMenuItem(value: page.open, child: Text(page.label)),
            ],
          ),
          const SizedBox(width: 4),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _stepLabel(theme, 'I · INTENT'),
                  ),
                  TextField(
                    controller: _textController,
                    focusNode: _intentFocus,
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
                      hintText: 'e.g. $exampleIntent.',
                      hintStyle: TextStyle(color: theme.inkTertiary, fontSize: 14),
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
                  if (_kernel.isEmpty && !_state.isIncinerated)
                    Text(
                      'One sentence, stated positively. Your intent stays on this device.',
                      style: TextStyle(color: theme.inkSecondary, fontSize: 12, height: 1.4),
                    ),
                  // Hidden during the rite: forgetting the intent is part of the practice.
                  if (_kernel.reducedConsonants.isNotEmpty && !_charging && !_isBurning)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // One label for every system; the tooltip says what each takes.
                        Tooltip(
                          message: _drawnFromHelp,
                          triggerMode: TooltipTriggerMode.tap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'DRAWN FROM',
                                style: TextStyle(
                                  color: theme.inkSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.info_outline, size: 14, color: theme.inkSecondary),
                            ],
                          ),
                        ),
                        Text(
                          _tracesHebrew
                              ? transliterate(_kernel.normalized).map((l) => l.glyph).join()
                              : _state.system == SigilSystem.ringCipher
                                  ? RingCipherEngine.cipherText(_kernel.rawIntent).split('').join(' · ')
                                  : _isInfinite
                                      ? _infiniteLabel
                                      : _kernel.reducedConsonants.split('').join(' · '),
                          style: TextStyle(
                            color: theme.seal,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                        // Circumlocution traces the whole phrase, and The
                        // Infinite hashes it: nothing is reduced.
                        if (_state.system != SigilSystem.ringCipher && !_isInfinite)
                          TextButton(
                            // TextButton keeps a 48 pt hit area around the small link.
                            onPressed: _showExegesisModal,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.inkTertiary,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(44, 44),
                            ),
                            child: const Text(
                              'Why reduce?',
                              style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            // Archival Parchment Canvas Viewport
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.canvasBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _state.isIncinerated ? theme.accent.withValues(alpha: 0.3) : theme.hairline,
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
                                ? _IncineratedPlate(
                                    theme: theme,
                                    onAnother: _makeAnother,
                                    witness: kEnableRite
                                        ? RiteWitnessRecord(theme: theme, service: RiteService.instance)
                                        : null,
                                  )
                                : _kernel.isEmpty
                                    ? _ExamplePlate(
                                        theme: theme,
                                        spec: SigilSpec(
                                          kernel: _exampleKernel,
                                          system: _state.system,
                                          kameaType: _state.kameaType,
                                          symmetryFolds: _state.symmetryFolds,
                                          symmetryGroup: _state.symmetryGroup,
                                        ),
                                        burn: _burn,
                                      )
                                    : Semantics(
                                        image: true,
                                        label: _kernel.isEmpty ? 'Empty plate' : '${_state.system.title} sigil',
                                        child: SigilCanvas(
                                          spec: _spec,
                                          skin: theme,
                                          burn: _burn,
                                          onIncinerated: _onIncinerated,
                                          breath: _breath,
                                          onViewChanged: _isInfinite && !_charging
                                              ? (v) => setState(() => _infiniteView = v)
                                              : null,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // First visit only, over the example plate; it scrolls on a short screen.
                  if (_firstVisit)
                    Positioned.fill(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: _IntroCard(theme: theme, steps: _steps, onDismiss: _dismissIntro),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // II · SEAL: the systems in one scrolling row, grouped by family
            // (one row keeps the plate large at phone width).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: _stepLabel(theme, 'II · SEAL')),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: SigilSystem.values.expand((sys) {
                  final isSelected = _state.system == sys;
                  final firstOfGroup = sys == SigilSystem.values.firstWhere((s) => s.group == sys.group);
                  return [
                    if (firstOfGroup)
                      Padding(
                        padding: EdgeInsets.only(left: sys.index == 0 ? 0 : 8, right: 8),
                        child: Text(
                          sys.group.caption,
                          style: TextStyle(color: theme.inkSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(sys.title),
                        selected: isSelected,
                        selectedColor: theme.surfaceElevated,
                        backgroundColor: theme.surface,
                        labelStyle: TextStyle(
                          // On the first visit the place to start is marked in vermilion.
                          color: sys == SigilSystem.ringCipher && _firstVisit
                              ? theme.accent
                              : isSelected
                                  ? theme.inkPrimary
                                  : theme.inkTertiary,
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
                    ),
                  ];
                }).toList(),
              ),
            ),

            // What the system does in plain words, then its ritual in the
            // owner's voice; both stay through the rite.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  children: [
                    Text(
                      _state.system.howTo,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.inkPrimary, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _state.system.ritual,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: theme.inkSecondary, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
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
                                _skinTheme.shortLabel.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.inkPrimary,
                          foregroundColor: theme.surface,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _state.isIncinerated || _isBurning || _kernel.isEmpty ? null : _showBurnModal,
                        icon: Icon(Icons.whatshot, size: 16, color: theme.surface),
                        label: const Text(
                          'III · CHARGE THE SEAL',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
                        ),
                      ),
                      if (_kernel.isEmpty && !_state.isIncinerated)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Write your intent first',
                              style: TextStyle(color: theme.inkSecondary, fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

/// The empty plate after combustion: silence, then the banishing line.
class _IncineratedPlate extends StatefulWidget {
  const _IncineratedPlate({required this.theme, required this.onAnother, this.witness});

  final SigilSkinTheme theme;

  /// Back to an empty plate for a new intent.
  final VoidCallback onAnother;

  /// The release's on-chain record, when the rite is enabled.
  final Widget? witness;

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
    return Semantics(
      liveRegion: true,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
        // Scaled down rather than clipped on a small plate.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'IV · RELEASED',
                    style: TextStyle(
                        color: theme.inkSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The seal is gone. Now put it out of mind. Do not check whether it is working.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.inkPrimary, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"Does not matter—need not be."\n(Spare, The Book of Pleasure)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.inkSecondary, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
                    onPressed: _laughed ? null : () => setState(() => _laughed = true),
                    child: Text(
                      _laughed ? 'Ha.' : 'BANISH WITH LAUGHTER',
                      style:
                          TextStyle(color: theme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.4),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: theme.inkSecondary, minimumSize: const Size(44, 44)),
                    onPressed: widget.onAnother,
                    child: const Text('Make another seal', style: TextStyle(fontSize: 12)),
                  ),
                  if (widget.witness != null) ...[const SizedBox(height: 4), widget.witness!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first visit: the rite in four steps, until dismissed.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.theme, required this.steps, required this.onDismiss});

  final SigilSkinTheme theme;
  final List<String> steps;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Got it" shares the title row, so the card stays short on a small screen.
          Row(
            children: [
              Expanded(
                child: Text(
                  'THE RITE, IN FOUR STEPS',
                  style: TextStyle(
                      color: theme.inkSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.4),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: theme.accent, minimumSize: const Size(64, 48)),
                onPressed: onDismiss,
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 12),
              child: Text(step, style: TextStyle(color: theme.inkPrimary, fontSize: 14, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

/// The empty plate: a fixed example seal in faint ink, tagged as an example.
class _ExamplePlate extends StatelessWidget {
  const _ExamplePlate({required this.theme, required this.spec, required this.burn});

  final SigilSkinTheme theme;
  final SigilSpec spec;
  final SigilBurnController burn;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Example seal. Write your own intent to begin.',
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0.2,
                  child: SigilCanvas(spec: spec, skin: theme, burn: burn, onIncinerated: () {}),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.canvasBackground,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: theme.hairlineStrong),
              ),
              child: Text(
                'EXAMPLE · write your own',
                style:
                    TextStyle(color: theme.inkSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
