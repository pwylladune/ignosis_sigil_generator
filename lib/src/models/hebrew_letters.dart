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

  /// Letters of one class in traditional order (mothers: A M Sh;
  /// doubles: B G D K P R T; simples: H V Z Ch T Y L N S O Tz Q).
  static List<HebrewLetter> ofClass(LetterClass c) => values.where((l) => l.letterClass == c).toList();
}

/// Published Latin → Hebrew transliteration used by the Kamea and Rose Cross.
///
/// Every one of the 26 Latin letters maps to exactly one Hebrew letter. It
/// follows common Golden Dawn practice; where a Latin letter has several
/// candidates (C, K; S, Sh; T, Th; V, W, U) a single fixed choice is made so
/// the mapping stays deterministic. X is given Shin so all three mothers are
/// reachable. Teth and Tzaddi are reached only by digraphs (Th, Tz) in the
/// tradition and are not used by single letters here.
const Map<String, HebrewLetter> latinToHebrew = {
  'A': HebrewLetter.aleph,
  'B': HebrewLetter.beth,
  'C': HebrewLetter.kaph,
  'D': HebrewLetter.daleth,
  'E': HebrewLetter.he,
  'F': HebrewLetter.pe,
  'G': HebrewLetter.gimel,
  'H': HebrewLetter.heth,
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
  'T': HebrewLetter.tav,
  'U': HebrewLetter.vav,
  'V': HebrewLetter.vav,
  'W': HebrewLetter.vav,
  'X': HebrewLetter.shin,
  'Y': HebrewLetter.yod,
  'Z': HebrewLetter.zayin,
};

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
