/// Model representing a prepared and reduced Statement of Intent (SOI).
///
/// Letter reduction, attributed as precisely as the sources allow:
/// - Spare (The Book of Pleasure, 1913) only combines "the letters of the
///   alphabet simplified".
/// - Carroll (Liber Null, 1978) strikes out repeated letters and keeps the
///   vowels. This is the default here.
/// - Stripping vowels as well is a later popular convention, available with
///   `stripVowels: true` (Y is then treated as a consonant).
/// Whitespace, digits and punctuation are always removed.
class IntentKernel {
  final String rawIntent;
  final String normalized;

  /// The reduced letters, in order of first appearance. (Consonants only when
  /// built with `stripVowels`; the name predates the vowel option.)
  final String reducedConsonants;
  final List<int> consonantCodes;
  final List<int> gematriaValues;

  const IntentKernel({
    required this.rawIntent,
    required this.normalized,
    required this.reducedConsonants,
    required this.consonantCodes,
    required this.gematriaValues,
  });

  /// Factory constructor that processes any input statement of intent.
  factory IntentKernel.fromText(String input, {bool stripVowels = false}) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return const IntentKernel(
        rawIntent: '',
        normalized: '',
        reducedConsonants: '',
        consonantCodes: [],
        gematriaValues: [],
      );
    }

    // 1. Normalize: uppercase, A-Z only
    final normalized = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    // 2. Strike out repeated letters (Carroll); with stripVowels, also drop
    // A, E, I, O, U (a modern convention; Y counts as a consonant).
    const vowels = {'A', 'E', 'I', 'O', 'U'};
    final seen = <String>{};
    final reducedBuffer = StringBuffer();

    for (int i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (!(stripVowels && vowels.contains(char)) && !seen.contains(char)) {
        seen.add(char);
        reducedBuffer.write(char);
      }
    }

    // If string contained only vowels, fallback to deduplicated original letters
    String reduced = reducedBuffer.toString();
    if (reduced.isEmpty && normalized.isNotEmpty) {
      final fallbackSeen = <String>{};
      final fallbackBuffer = StringBuffer();
      for (int i = 0; i < normalized.length; i++) {
        final char = normalized[i];
        if (!fallbackSeen.contains(char)) {
          fallbackSeen.add(char);
          fallbackBuffer.write(char);
        }
      }
      reduced = fallbackBuffer.toString();
    }

    final codes = reduced.codeUnits;

    // Pythagorean reduction: A=1, B=2 ... I=9, J=1 ... Z=8 (not Agrippan values).
    // Hebrew gematria with Aiq Bekar lives in hebrew_letters.dart (Kamea, Rose).
    final gematria = codes.map((c) {
      final alphaIndex = c - 65; // 0 for A, 25 for Z
      return (alphaIndex % 9) + 1; // 1 to 9
    }).toList();

    return IntentKernel(
      rawIntent: raw,
      normalized: normalized,
      reducedConsonants: reduced,
      consonantCodes: codes,
      gematriaValues: gematria,
    );
  }

  bool get isEmpty => reducedConsonants.isEmpty;
  int get length => reducedConsonants.length;
}
