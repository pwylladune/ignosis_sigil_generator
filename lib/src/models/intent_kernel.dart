/// Model representing a prepared and reduced Statement of Intent (SOI).
///
/// Implements classical Austin Osman Spare letter reduction:
/// - Strips whitespace, digits, and punctuation
/// - Strips vowels (A, E, I, O, U)
/// - Deduplicates remaining consonants while preserving phonetic order
class IntentKernel {
  final String rawIntent;
  final String normalized;
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
  factory IntentKernel.fromText(String input) {
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

    // 2. Austin Osman Spare reduction:
    // Strip vowels: A, E, I, O, U (keeping Y as consonant or optional)
    const vowels = {'A', 'E', 'I', 'O', 'U'};
    final seen = <String>{};
    final reducedBuffer = StringBuffer();

    for (int i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (!vowels.contains(char) && !seen.contains(char)) {
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

    // Agrippan / Gematria reduction: A=1, B=2 ... I=9, J=1 ... Z=8
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
