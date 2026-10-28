import '../engines/kamea_engine.dart';

/// The families the studio groups its systems into.
enum SystemGroup {
  letters('Letter methods'),
  hebrew('Hebrew figures'),
  generative('Generative fields');

  final String caption;
  const SystemGroup(this.caption);
}

/// Sigil systems, in the order the studio offers them (the first is the default).
enum SigilSystem {
  ringCipher(
    'Circumlocution',
    SystemGroup.letters,
    'Draws your phrase as a path that winds around a ring of letters.',
    'The phrase traced outward ring by ring between letter spokes (IGNOSIS’s own)',
    'Every phrase describes the outline of a truth. Trace your truth around its edges, back and forth, '
        'letter by letter, until the maze of your intention is set. Ready to be burned.',
  ),
  spare(
    'Monogram (after Spare)',
    SystemGroup.letters,
    'Strikes repeated letters and fuses the rest into one glyph.',
    'Letters merged into one glyph as in Spare (1913); the radial symmetry is IGNOSIS’s own',
    'Strike out the repeated letters. Merge the rest into one glyph, as Spare did in 1913. Let symmetry multiply it.',
  ),
  kamea(
    'Planetary Kamea',
    SystemGroup.hebrew,
    'Spells your intent in Hebrew and traces its numbers on a planetary square.',
    'Agrippa’s planetary magic squares (Saturn to Luna), traced as the Golden Dawn did',
    'Spell your intent in Hebrew. Trace it across Agrippa’s planetary square, as the Golden Dawn drew the sigils '
        'of spirits.',
  ),
  roseCross(
    'Golden Dawn Rose',
    SystemGroup.hebrew,
    'Spells your intent in Hebrew and traces it across the 22-petal rose.',
    'The 22-petal rose of the Golden Dawn Rose Cross lamen (3 · 7 · 12)',
    'Spell your intent in Hebrew. Draw it across the 22 petals of the Rose Cross as its rings align.',
  ),
  chladni(
    'Cymatic Resonance',
    SystemGroup.generative,
    'Turns your intent into a vibration and draws where sand would settle.',
    '2D acoustic Chladni plate vibration nodal field',
    'Your intention as vibration. The sand comes to rest in the patterns of your self.',
  ),
  cyberChaos(
    'Cyber Chaos',
    SystemGroup.generative,
    'Hashes your intent into the seed of a strange attractor.',
    'SHA-256 seeded Clifford strange attractor',
    'Hash your intent into the seed of a strange attractor. Fields of truth blossom from folds of self. '
        'Consume to release.',
  ),
  infinite(
    'The Infinite',
    SystemGroup.generative,
    'Finds your intent’s point on the Mandelbrot edge and draws its Julia set.',
    'The Julia set of z² + c, with c chosen by the intent; zoom without end (IGNOSIS’s own)',
    'Find your intent’s point on the edge of the Mandelbrot set. Descend into its Julia set without end.',
  );

  final String title;
  final SystemGroup group;

  /// What the system does, in one plain line, shown above the ritual.
  final String howTo;
  final String description;

  /// The line shown under the system chips: the ritual, in the owner's words.
  final String ritual;
  const SigilSystem(this.title, this.group, this.howTo, this.description, this.ritual);
}

/// Symmetry group applied to the fundamental domain of a glyph.
enum SymmetryGroup {
  /// Rotations only (Cₙ).
  cyclic('C'),

  /// Rotations and mirror reflections (Dₙ).
  dihedral('D');

  final String symbol;
  const SymmetryGroup(this.symbol);
}

class SigilState {
  final String rawIntent;
  final SigilSystem system;
  final PlanetaryKameaType kameaType;
  final int symmetryFolds;
  final SymmetryGroup symmetryGroup;

  /// Also strip vowels when reducing (a modern convention). Off by default:
  /// Carroll's method strikes out repeated letters only.
  final bool stripVowels;
  final bool isIncinerated;

  const SigilState({
    this.rawIntent = 'I COMMAND RADIANT CLARITY',
    this.system = SigilSystem.ringCipher,
    this.kameaType = PlanetaryKameaType.sol,
    this.symmetryFolds = 4,
    this.symmetryGroup = SymmetryGroup.cyclic,
    this.stripVowels = false,
    this.isIncinerated = false,
  });

  SigilState copyWith({
    String? rawIntent,
    SigilSystem? system,
    PlanetaryKameaType? kameaType,
    int? symmetryFolds,
    SymmetryGroup? symmetryGroup,
    bool? stripVowels,
    bool? isIncinerated,
  }) {
    return SigilState(
      rawIntent: rawIntent ?? this.rawIntent,
      system: system ?? this.system,
      kameaType: kameaType ?? this.kameaType,
      symmetryFolds: symmetryFolds ?? this.symmetryFolds,
      symmetryGroup: symmetryGroup ?? this.symmetryGroup,
      stripVowels: stripVowels ?? this.stripVowels,
      isIncinerated: isIncinerated ?? this.isIncinerated,
    );
  }
}
