import '../config/feature_flags.dart';

class WikiQuestion {
  final String category;
  final String title;
  final String prompt;
  final String hint;

  const WikiQuestion({
    required this.category,
    required this.title,
    required this.prompt,
    required this.hint,
  });
}

class ChaosMagicWikiData {
  static const List<WikiQuestion> questions = [
    // 1. History & Provenance
    WikiQuestion(
      category: 'I. History & Provenance',
      title: 'The Origin of Sigilization (Austin Osman Spare)',
      prompt: 'Spare’s brush with ceremonial magic was brief: a probationer of Crowley’s A∴A∴ in 1909, he soon rejected ritual “theatricals” and built his own method in The Book of Pleasure (1913). In your practice, does stripping away robes and hierarchy make sigil work more potent, or only more portable?',
      hint: 'Reflect on Spare’s “death posture” and his idea that belief works best below conscious attention.',
    ),
    WikiQuestion(
      category: 'I. History & Provenance',
      title: 'The 1970s Chaos Emergence (Carroll, Sherwin, IOT)',
      prompt: 'Peter J. Carroll and Ray Sherwin founded the Illuminates of Thanateros (1978). Carroll’s Liber Null quotes the maxim "Nothing is true, everything is permitted", popularly (and legendarily) ascribed to Hassan-i Sabbah. How has your practice absorbed or adapted this idea of belief as a tool?',
      hint: 'Consider meta-belief: adopting a belief system temporarily to achieve an effect, then discarding it.',
    ),

    // 2. Intentions & The Statement of Will
    WikiQuestion(
      category: 'II. Intention & Mechanics of Will',
      title: 'Formulating the Statement of Intent (SOI)',
      prompt: 'Spare and Carroll both phrase intents as wishes (“This my wish to obtain…”, “It is my will to…”); the present-tense affirmation is a later convention. Which phrasing works for you, and why might it matter to what Carroll calls the “psychic censor”?',
      hint: 'Contrast a stated wish with a present-tense affirmation, and notice which one your mind argues with.',
    ),
    WikiQuestion(
      category: 'II. Intention & Mechanics of Will',
      title: 'Letter Reduction & Abstract Transmutation',
      prompt: 'Spare combined “the letters of the alphabet simplified”; Carroll strikes out repeated letters; dropping vowels as well is a later popular convention. When the sentence becomes an abstract glyph, what happens to your attachment to it?',
      hint: 'Explore the transition from conscious linguistic thought to unconscious symbolic recognition.',
    ),

    // 3. States of Gnosis
    WikiQuestion(
      category: 'III. Gnosis & Charging States',
      title: 'Inhibitory vs. Excitatory Gnosis',
      prompt: 'Carroll (Liber Null) divides gnosis into inhibitory methods (death posture, trance, fasting, sleeplessness, gazing, sensory deprivation) and excitatory ones (sexual excitation, emotional arousal, dancing and drumming, chanting, forced over-breathing). Which do you find most reliable for charging a sigil?',
      hint: 'Discuss physical sensations at the moment of zero-point focus (the "click" or detachment).',
    ),
    WikiQuestion(
      category: 'III. Gnosis & Charging States',
      title: 'The Breath as a Focusing Rhythm',
      prompt: 'How does paced breathing (slow paced breathing, box breathing, yogic prāṇāyāma) help you gather attention before charging? How do you know when your focus has peaked?',
      hint: 'Reflect on any sense of slowing down, mental stillness, and the after-image of the seal.',
    ),

    // 4. The Burning, Sacrifice & Forgetting
    WikiQuestion(
      category: 'IV. Destruction, Combustion & Forgetting',
      title: 'Forgetting and the “Lust of Result”',
      prompt: 'Spare advised “a deliberate striving to forget” the sigil; Carroll, borrowing Crowley’s phrase (Liber AL I:44), warns against “lust of result”. Why is forgetting considered the hardest part, and what happens when a practitioner keeps watching for results?',
      hint: 'Consider how attention fixed on the outcome keeps the intent in conscious, doubting thought.',
    ),
    if (kEnableChain)
      WikiQuestion(
        category: 'IV. Destruction, Combustion & Forgetting',
        title: 'Physical Fire vs. Digital & Cryptographic Combustion',
        prompt: r'When physical paper burns, chemical energy is released as heat. In the digital world, how do you perceive the energetic exchange of burning cryptocurrency on a distributed ledger ($IGNOSIS proof-of-heat)? Is economic sacrifice a valid surrogate for physical ash?',
        hint: 'Consider how irreversible transactions mirror the finality of flame: both destroy substrate to release will.',
      )
    else
      WikiQuestion(
        category: 'IV. Destruction, Combustion & Forgetting',
        title: 'Physical Fire vs. Digital Combustion',
        prompt: 'When physical paper burns, the substrate is irreversibly consumed. When a sigil is dissolved on a screen, is the act of release any less real? What makes a destruction ritual effective: the medium, or the finality of the gesture?',
        hint: 'Consider how irreversibility, rather than material, mirrors the finality of flame: both destroy substrate to release will.',
      ),

    // 5. Personal Philosophy & Ethics
    WikiQuestion(
      category: 'V. Philosophy, Ethics & The Great Work',
      title: 'Banishing with Laughter',
      prompt: 'Carroll recommends banishing with laughter, echoing Spare’s advice to laugh at all things. Why close a rite with laughter or something deliberately mundane? How do you ground yourself after intense work?',
      hint: 'Banishment through humor breaks solemnity and snaps the psyche back to baseline reality.',
    ),
    WikiQuestion(
      category: 'V. Philosophy, Ethics & The Great Work',
      title: 'The Great Work in Chaos Magic',
      prompt: 'Chaos magic treats gods, doctrines and karma as tools rather than authorities. If none of them is binding, what guides your ethics and your development? What is the practitioner’s goal?',
      hint: 'Speak on autonomy, self-knowledge, mastery of will, and harmony with universal chaos.',
    ),
  ];
}
