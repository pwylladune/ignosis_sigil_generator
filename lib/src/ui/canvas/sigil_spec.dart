import 'package:flutter/foundation.dart';
import '../../engines/infinite_engine.dart';
import '../../engines/kamea_engine.dart';
import '../../engines/ring_cipher_engine.dart';
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

  /// The Infinite only: drawn by the inverse map z ↦ ±√(z − c).
  final bool inverted;

  /// The Infinite only: the zoomed window, or null for the whole set.
  final InfiniteView? view;

  const SigilSpec({
    required this.kernel,
    required this.system,
    required this.kameaType,
    required this.symmetryFolds,
    required this.symmetryGroup,
    this.inverted = false,
    this.view,
  });

  /// True when only the intent differs (typing), not the system or its options.
  bool sameSettings(SigilSpec o) =>
      system == o.system &&
      kameaType == o.kameaType &&
      symmetryFolds == o.symmetryFolds &&
      symmetryGroup == o.symmetryGroup &&
      inverted == o.inverted &&
      view == o.view;

  /// True when only the zoom differs: the new view appears at once, not rewritten.
  bool differsOnlyInView(SigilSpec o) =>
      view != o.view &&
      system == o.system &&
      inverted == o.inverted &&
      kernel.normalized == o.kernel.normalized &&
      kernel.reducedConsonants == o.kernel.reducedConsonants;

  /// Extra text that changes the sigil: Circumlocution also traces ',' and '.'.
  String get _extra => system == SigilSystem.ringCipher ? RingCipherEngine.cipherText(kernel.rawIntent) : '';

  @override
  bool operator ==(Object other) =>
      other is SigilSpec &&
      sameSettings(other) &&
      other.kernel.normalized == kernel.normalized &&
      other.kernel.reducedConsonants == kernel.reducedConsonants &&
      other._extra == _extra;

  @override
  int get hashCode =>
      Object.hash(kernel.normalized, kernel.reducedConsonants, system, kameaType, symmetryFolds, symmetryGroup, _extra,
          inverted, view);
}
