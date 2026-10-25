import '../engines/kamea_engine.dart';

enum SigilSystem {
  spare('Austin Osman Spare', 'Letter reduction monogram assembled by a symmetry group'),
  kamea('Planetary Kamea', 'Planetary magic square ciphers (Saturn to Luna)'),
  roseCross('Rose Cross Dial', 'Hermetic 3 · 7 · 12 Rosicrucian petal rose'),
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
  final bool isIncinerated;

  const SigilState({
    this.rawIntent = 'I COMMAND RADIANT CLARITY',
    this.system = SigilSystem.spare,
    this.kameaType = PlanetaryKameaType.sol,
    this.symmetryFolds = 4,
    this.symmetryGroup = SymmetryGroup.cyclic,
    this.isIncinerated = false,
  });

  SigilState copyWith({
    String? rawIntent,
    SigilSystem? system,
    PlanetaryKameaType? kameaType,
    int? symmetryFolds,
    SymmetryGroup? symmetryGroup,
    bool? isIncinerated,
  }) {
    return SigilState(
      rawIntent: rawIntent ?? this.rawIntent,
      system: system ?? this.system,
      kameaType: kameaType ?? this.kameaType,
      symmetryFolds: symmetryFolds ?? this.symmetryFolds,
      symmetryGroup: symmetryGroup ?? this.symmetryGroup,
      isIncinerated: isIncinerated ?? this.isIncinerated,
    );
  }
}
