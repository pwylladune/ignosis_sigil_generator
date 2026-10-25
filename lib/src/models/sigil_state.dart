import '../engines/kamea_engine.dart';

enum SigilSystem {
  spare('Monogram (after Spare)', 'Letters merged into one glyph as in Spare (1913); the radial symmetry is IGNOSIS’s own'),
  kamea('Planetary Kamea', 'Agrippa’s planetary magic squares (Saturn to Luna), traced as the Golden Dawn did'),
  roseCross('Golden Dawn Rose', 'The 22-petal rose of the Golden Dawn Rose Cross lamen (3 · 7 · 12)'),
  chladni('Cymatic Resonance', '2D acoustic Chladni plate vibration nodal field'),
  cyberChaos('Cyber Chaos', 'SHA-256 seeded Clifford strange attractor');

  final String title;
  final String description;
  const SigilSystem(this.title, this.description);
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
    this.system = SigilSystem.spare,
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
