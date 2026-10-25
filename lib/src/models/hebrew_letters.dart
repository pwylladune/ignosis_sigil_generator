/// The 22 Hebrew letters with their standard gematria values and their
/// Sepher Yetzirah class (3 mothers, 7 doubles, 12 simples), as used in the
/// Hermetic Qabalah of the Golden Dawn (not Jewish Kabbalah practice).
enum LetterClass { mother, double, simple }

enum HebrewLetter {
  aleph('Aleph', 'א', 1, LetterClass.mother),
  beth('Beth', 'ב', 2, LetterClass.double),
  gimel('Gimel', 'ג', 3, LetterClass.double),
  daleth('Daleth', 'ד', 4, LetterClass.double),
  he('He', 'ה', 5, LetterClass.simple),
  vav('Vav', 'ו', 6, LetterClass.simple),
  zayin('Zayin', 'ז', 7, LetterClass.simple),
  heth('Heth', 'ח', 8, LetterClass.simple),
  teth('Teth', 'ט', 9, LetterClass.simple),
  yod('Yod', 'י', 10, LetterClass.simple),
  kaph('Kaph', 'כ', 20, LetterClass.double),
  lamed('Lamed', 'ל', 30, LetterClass.simple),
  mem('Mem', 'מ', 40, LetterClass.mother),
  nun('Nun', 'נ', 50, LetterClass.simple),
  samekh('Samekh', 'ס', 60, LetterClass.simple),
  ayin('Ayin', 'ע', 70, LetterClass.simple),
  pe('Pe', 'פ', 80, LetterClass.double),
  tzaddi('Tzaddi', 'צ', 90, LetterClass.simple),
  qoph('Qoph', 'ק', 100, LetterClass.simple),
  resh('Resh', 'ר', 200, LetterClass.double),
  shin('Shin', 'ש', 300, LetterClass.mother),
  tav('Tav', 'ת', 400, LetterClass.double);

  final String title;
  final String glyph;
  final int value;
  final LetterClass letterClass;
  const HebrewLetter(this.title, this.glyph, this.value, this.letterClass);

  /// Letters of one class in alphabetical order (mothers: A M Sh;
  /// doubles: B G D K P R T; simples: H V Z Ch T Y L N S O Tz Q).
  static List<HebrewLetter> ofClass(LetterClass c) => values.where((l) => l.letterClass == c).toList();
}

/// Latin → Hebrew transliteration used by the Kamea and Rose Cross.
///
/// Follows the Golden Dawn / Crowley *777* convention: He = E and H, Cheth =
/// Ch, Teth = T, Tav = Th, Shin = Sh, Tzaddi = Tz, Samekh = S (and X, whose
/// Greek ancestor Ξ derives from Samekh). Digraphs ([latinDigraphs]) are read
/// before single letters, so all 22 letters are reachable. Where a Latin
/// letter has several candidates (C/K → Kaph; I/J/Y → Yod; U/V/W → Vav) one
/// fixed choice keeps the mapping deterministic.
///
/// This is a letter-by-letter transliteration of the typed text, not a
/// Hebrew spelling of a name: the Golden Dawn spelled names in Hebrew
/// (e.g. Raphael = Resh-Pe-Aleph-Lamed), which needs a dictionary.
const Map<String, HebrewLetter> latinToHebrew = {
  'A': HebrewLetter.aleph,
  'B': HebrewLetter.beth,
  'C': HebrewLetter.kaph,
  'D': HebrewLetter.daleth,
  'E': HebrewLetter.he,
  'F': HebrewLetter.pe,
  'G': HebrewLetter.gimel,
  'H': HebrewLetter.he,
  'I': HebrewLetter.yod,
  'J': HebrewLetter.yod,
  'K': HebrewLetter.kaph,
  'L': HebrewLetter.lamed,
  'M': HebrewLetter.mem,
  'N': HebrewLetter.nun,
  'O': HebrewLetter.ayin,
  'P': HebrewLetter.pe,
  'Q': HebrewLetter.qoph,
  'R': HebrewLetter.resh,
  'S': HebrewLetter.samekh,
  'T': HebrewLetter.teth,
  'U': HebrewLetter.vav,
  'V': HebrewLetter.vav,
  'W': HebrewLetter.vav,
  'X': HebrewLetter.samekh,
  'Y': HebrewLetter.yod,
  'Z': HebrewLetter.zayin,
};

/// Two-letter Latin sounds with their own Hebrew letter, read first.
const Map<String, HebrewLetter> latinDigraphs = {
  'SH': HebrewLetter.shin,
  'TH': HebrewLetter.tav,
  'CH': HebrewLetter.heth,
  'TZ': HebrewLetter.tzaddi,
  'TS': HebrewLetter.tzaddi,
  'PH': HebrewLetter.pe,
};

/// Transliterates normalised A–Z text into Hebrew letters, digraphs first.
/// Repeated letters are kept: Golden Dawn kamea and rose sigils trace every
/// letter, and a doubled letter is drawn as a loop.
List<HebrewLetter> transliterate(String normalized) {
  final out = <HebrewLetter>[];
  var i = 0;
  while (i < normalized.length) {
    if (i + 1 < normalized.length) {
      final di = latinDigraphs[normalized.substring(i, i + 2)];
      if (di != null) {
        out.add(di);
        i += 2;
        continue;
      }
    }
    final single = latinToHebrew[normalized[i]];
    if (single != null) out.add(single);
    i++;
  }
  return out;
}

/// Aiq Bekar (Qabalah of Nine Chambers) reduction of a gematria value into
/// `[1, max]`: tens and hundreds share a chamber with their units, so 200 → 20
/// → 2 is applied until the value fits.
int aiqBekarReduce(int value, int max) {
  var v = value;
  while (v > max) {
    if (v % 10 == 0) {
      v ~/= 10;
    } else {
      // Not reached by single-letter gematria; fall back to the digit sum.
      v = v.toString().split('').fold(0, (s, d) => s + int.parse(d));
    }
  }
  return v < 1 ? 1 : v;
}
