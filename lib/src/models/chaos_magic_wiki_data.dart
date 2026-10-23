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
      prompt: 'How do you view Austin Osman Spare’s departure from the Golden Dawn and Aleister Crowley’s ceremonialism? In your philosophy, why did stripping away complex robes and Hebrew hierarchy make sigil magic more potent rather than less?',
      hint: 'Reflect on Spare’s concept of the death posture and the role of the subconscious mind over dogma.',
    ),
    WikiQuestion(
      category: 'I. History & Provenance',
      title: 'The 1970s Chaos Emergence (Carroll, Sherwin, IOT)',
      prompt: 'Peter J. Carroll and Ray Sherwin formed the Illuminates of Thanateros with the maxim "Nothing is true, everything is permitted." How has your practice absorbed or adapted this idea of belief as an arbitrary tool?',
      hint: 'Consider meta-belief: adopting a belief system temporarily to achieve an effect, then discarding it.',
    ),

    // 2. Intentions & The Statement of Will
    WikiQuestion(
      category: 'II. Intention & Mechanics of Will',
      title: 'Formulating the Statement of Intent (SOI)',
      prompt: 'What grammatical structures or linguistic tenses produce the most resonant results for you? Why does phrasing desire in the present/past tense bypass the psychic censor compared to future longing?',
      hint: 'Contrast "I want wealth" (reinforcing lack) with "I embody sovereign abundance".',
    ),
    WikiQuestion(
      category: 'II. Intention & Mechanics of Will',
      title: 'Letter Reduction & Abstract Transmutation',
      prompt: 'When you reduce letters down to consonants and build an abstract glyph, what do you believe happens to the psychic attachment to the original sentence? Where does the energy go?',
      hint: 'Explore the transition from conscious linguistic thought to unconscious symbolic recognition.',
    ),

    // 3. States of Gnosis
    WikiQuestion(
      category: 'III. Gnosis & Charging States',
      title: 'Inhibitory vs. Excitatory Gnosis',
      prompt: 'Carroll divides Gnosis into Inhibitory (sensory deprivation, deep meditation, breath-holding) and Excitatory (ecstasy, dance, spinning, emotional surge). Which modalities do you find most reliable for projecting sigils into the void?',
      hint: 'Discuss physical sensations at the moment of zero-point focus (the "click" or detachment).',
    ),
    WikiQuestion(
      category: 'III. Gnosis & Charging States',
      title: 'The Breath as an Alchemical Accelerator',
      prompt: 'How does rhythmic breathing (box breathing, pranayama) synchronize mind and body prior to consecration? How do you know when your focus has reached peak saturation?',
      hint: 'Reflect on the heart rate drop, mental stillness, and the optic retention of the seal.',
    ),

    // 4. The Burning, Sacrifice & Forgetting
    WikiQuestion(
      category: 'IV. Destruction, Combustion & Forgetting',
      title: 'Austin Osman Spare’s "Free Belief"',
      prompt: 'Why is forgetting the desire considered the hardest yet most critical part of chaos magic? What happens when a practitioner continues to lust for results after casting?',
      hint: 'Explore the concept of "lust of result" as psychic drag that traps the intent in conscious ego.',
    ),
    WikiQuestion(
      category: 'IV. Destruction, Combustion & Forgetting',
      title: 'Physical Fire vs. Digital & Cryptographic Combustion',
      prompt: r'When physical paper burns, chemical energy is released as heat. In the digital world, how do you perceive the energetic exchange of burning cryptocurrency on a distributed ledger ($IGNOSIS proof-of-heat)? Is economic sacrifice a valid surrogate for physical ash?',
      hint: 'Consider how irreversible transactions mirror the finality of flame: both destroy substrate to release will.',
    ),

    // 5. Personal Philosophy & Ethics
    WikiQuestion(
      category: 'V. Philosophy, Ethics & The Great Work',
      title: 'Banishing with Laughter',
      prompt: 'Why do chaos magicians traditionally conclude rites by laughing or doing something intensely mundane? How do you ground yourself after heavy occult work?',
      hint: 'Banishment through humor breaks solemnity and snaps the psyche back to baseline reality.',
    ),
    WikiQuestion(
      category: 'V. Philosophy, Ethics & The Great Work',
      title: 'The Great Work in Chaos Magic',
      prompt: 'Without external gods, commandments, or karma, what guides your personal ethics and spiritual evolution within chaos magic? What is the ultimate goal of the practitioner?',
      hint: 'Speak on autonomy, self-knowledge, mastery of will, and harmony with universal chaos.',
    ),
  ];
}
