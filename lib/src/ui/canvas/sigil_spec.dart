import 'package:flutter/foundation.dart';
import '../../engines/kamea_engine.dart';
import '../../models/intent_kernel.dart';
import '../../models/sigil_state.dart';

/// Everything that determines a sigil's geometry. Same spec, same sigil.
@immutable
class SigilSpec {
  final IntentKernel kernel;
  final SigilSystem system;
  final PlanetaryKameaType kameaType;
  final int symmetryFolds;
  final SymmetryGroup symmetryGroup;

  const SigilSpec({
    required this.kernel,
    required this.system,
    required this.kameaType,
    required this.symmetryFolds,
    required this.symmetryGroup,
  });

  /// True when only the intent differs (typing), not the system or its options.
  bool sameSettings(SigilSpec o) =>
      system == o.system && kameaType == o.kameaType && symmetryFolds == o.symmetryFolds && symmetryGroup == o.symmetryGroup;

  @override
  bool operator ==(Object other) =>
      other is SigilSpec && sameSettings(other) && other.kernel.normalized == kernel.normalized && other.kernel.reducedConsonants == kernel.reducedConsonants;

  @override
  int get hashCode => Object.hash(kernel.normalized, kernel.reducedConsonants, system, kameaType, symmetryFolds, symmetryGroup);
}
