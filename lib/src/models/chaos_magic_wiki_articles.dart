/// A wiki article: the studio explaining itself, as opposed to a
/// [WikiQuestion] that asks the practitioner.
///
/// Claims about the tradition follow the project's esoteric notes: what is
/// attested in a source says so, and what IGNOSIS invented says that too.
class WikiArticle {
  final String category;
  final String title;

  /// One line under the title.
  final String summary;

  /// Paragraphs, in reading order.
  final List<String> body;

  /// Sources and provenance, shown in small type under the article.
  final List<String> sources;

  const WikiArticle({
    required this.category,
    required this.title,
    required this.summary,
    required this.body,
    this.sources = const [],
  });
}

class ChaosMagicWikiArticles {
  // Unnumbered: the interview's sections keep their roman numerals I–V.
  static const systems = 'The Codex: The Six Systems';
  static const making = 'The Codex: The Making of IGNOSIS';

  static const List<WikiArticle> articles = [
    // ── VI. The six systems ────────────────────────────────────────────────
    WikiArticle(
      category: systems,
      title: 'Circumlocution',
      summary: 'The whole phrase, walked outward ring by ring between the spokes of its letters. The default system.',
      body: [
        'Method. Twenty-eight spokes divide the wheel: the twenty-six Latin letters, then the comma and the full stop, set '
            'clockwise so that A stands just above nine o’clock and N just above three. Around the hub lie concentric rings, '
            'one for each step of the phrase. The pen begins on the innermost ring at the spoke of the first letter and fills '
            'that ring as far as the spoke of the second, taking whichever way round is shorter; at an exact half-turn it '
            'goes clockwise. Then it steps out one ring and fills from that spoke to the next letter’s, and so on, outward, '
            'until the last letter is reached. A doubled letter has nowhere to travel, so it leaves a short notch on its '
            'spoke and the repetition is kept. Nothing is reduced. Every letter of the phrase, and its punctuation, is walked.',
        'Why. The other systems begin by breaking the sentence. Spare struck out its repetitions; the Golden Dawn rewrote '
            'it in Hebrew; the attractor hashes it into noise. Circumlocution declines to. Its premise is that we do not '
            'stand outside language and command it. We live inside it, in rings of it, the way one lives inside a city whose '
            'streets were laid long before one was born. The words we inherit encircle us. Some of them hold us up and some '
            'of them hold us in, and it is not always possible, from the inside, to tell which. To speak is to walk a route '
            'that grammar paved in advance, and most of us walk it all our lives believing we chose the way.',
        'So the wheel is a kind of confession. It admits the maze, and then it maps an honest path through it: not the '
            'straight line, which language has never once offered anyone, but the shortest way round, each time, one ring at '
            'a time, the phrase driven outward from the hub as a voice is driven out of the chest. There is a darkness at the '
            'centre of every sentence we use to bind ourselves, a small, airless room where the words were first agreed '
            'upon, and the pen does not pretend otherwise. It does not linger there, either. It keeps going, spoke to spoke, '
            'outward, away from it.',
        'The release is not an ornament of the design but its arithmetic. A phrase of n letters makes n − 1 arcs on n − 1 '
            'rings, and when the last arc closes on the last spoke there is no further ring to step into. The rite ends '
            'where the words end. Speak the phrase as the pen moves and let the final word leave on the out-breath: the '
            'wheel has been walked to its edge, the exhalation is complete, and what remains on the paper is a figure that '
            'once held a sentence and now holds only the shape of its passage.',
        'Motion. Each band is filled at a constant pen speed, so a long phrase takes honestly longer than a short one. '
            'The spokes are labelled, which no other system allows: here the letters are not hidden, only made to travel, '
            'and the eye loses the sentence in the rings well before the hand has finished writing it.',
      ],
      sources: [
        'Provenance: IGNOSIS’s own (2026), first drawn by hand as a wheel of letters filling outward. It belongs to no '
            'historical tradition; from the older alphabet wheels and cipher discs it takes only the habit of setting letters '
            'on a circle. It is the studio’s default because it is the only system that keeps every word.',
        'The name is meant plainly: circumlocution is speech that goes round, and this is the system in which going round '
            'is the whole of the method.',
      ],
    ),
    WikiArticle(
      category: systems,
      title: 'Monogram (after Spare)',
      summary: 'The letters merged into one glyph, then multiplied by a symmetry group.',
      body: [
        'Method. Austin Osman Spare made sigils “by combining the letters of the alphabet simplified” into a single '
            'monogram, stylised until it no longer suggested the desire (The Book of Pleasure, 1913). Peter Carroll, '
            'demonstrating the method in Liber Null (1978), strikes out repeated letters and keeps the vowels. Dropping '
            'the vowels as well is a later popular convention; the studio offers it as an option and says so.',
        'IGNOSIS places the remaining letter-forms on a shared armature, so that coincident strokes merge rather than '
            'stack, and then replicates that fundamental shape by a rotation group (Cₙ) or a rotation-and-mirror group (Dₙ).',
        'Motion. The radicals are written one by one with the timing of a human hand; then the copies rotate out from '
            'zero to their places, each a little after the last, and the viewer watches the group assemble the seal. Then '
            'stillness. The strokes are laid with the sumi-e brush.',
      ],
      sources: [
        'Attested: Spare, The Book of Pleasure (1913); Carroll, Liber Null (1978), “Sigils”.',
        'IGNOSIS’s own: the radial and dihedral symmetry, and the assembly animation.',
      ],
    ),
    WikiArticle(
      category: systems,
      title: 'Planetary Kamea',
      summary: 'The intent, spelled in Hebrew, traced cell to cell across a planet’s magic square.',
      body: [
        'Method. The seven squares are Agrippa’s “sacred tables of the planets” (De occulta philosophia II.22, 1533): '
            'Saturn 3×3, Jupiter 4, Mars 5, Sol 6, Venus 7, Mercury 8, Luna 9. Every row, column and diagonal sums to the '
            'same number, M = n(n² + 1)/2, which Agrippa gives as the table’s sacred number. The phrase is transliterated '
            'into Hebrew by the Golden Dawn and 777 convention, each letter takes its gematria value, and values too large '
            'for the square are reduced by the Qabalah of Nine Chambers (Aiq Bekar), dropping zeros until they fit. Agrippa’s '
            'own intelligence sigils trace their names this way.',
        'The line starts with a small circle and ends with a short bar, as Golden Dawn practice describes; a doubled '
            'value draws a small loop rather than vanishing.',
        'Motion. A pen point travels the square at constant speed; each visited cell’s number brightens and fades. When '
            'the trace is done, the rows, columns and diagonals light in turn to M. That “consecration” is IGNOSIS’s own '
            'flourish: the number is Agrippa’s, the ceremony is ours.',
      ],
      sources: [
        'Attested: Agrippa, De occulta philosophia II.20 and II.22 (1533; Freake translation 1651); Crowley, 777 (1909).',
        'Consensus: “kamea” as the name for these squares is 19th-century occultist usage, not Agrippa’s.',
        'IGNOSIS’s own: lighting the sums to M.',
      ],
    ),
    WikiArticle(
      category: systems,
      title: 'Golden Dawn Rose',
      summary: 'A line from letter to letter of the Hebrew spelling across the 22 petals of the Rose Cross lamen.',
      body: [
        'Method. The Rose Cross lamen holds 22 petals in three rings, by the classes of the Sefer Yetzirah: three mother '
            'letters within, seven doubles in the middle, twelve simples outside (published in The Equinox I:3, 1910). A '
            'name’s sigil is a line drawn through the petals of its Hebrew spelling, beginning with a small circle and '
            'ending with a short stroke. The studio uses the same transliteration as the Kamea, so all 26 Latin letters '
            'land on a petal and the same intent always gives the same path.',
        'Motion. The rings counter-rotate at speeds in the ratio 3 : 7 : 12, and the path is drawn between them while they '
            'move, until they ease into alignment as the last stroke lands, like the rings of a cryptex closing. The brush '
            'is seeded from the strokes themselves, so its texture holds still while the rings turn.',
      ],
      sources: [
        'Attested: The Equinox I:3 (1910), Diagram 63; Robert Wang, The Secret Temple (1980); Sefer Yetzirah (Kaplan, 1990).',
        'Unverified: the order of the middle ring has not yet been checked against the original plate.',
        'IGNOSIS’s own: the 3 : 7 : 12 astrolabe motion.',
      ],
    ),
    WikiArticle(
      category: systems,
      title: 'Cymatic Resonance',
      summary: 'A vibration mode of a square plate chosen by the intent; the sigil is where the sand comes to rest.',
      body: [
        'Method. Ernst Chladni showed in 1787 that sand on a bowed plate gathers along the lines that do not move. The '
            'studio solves a mode of a square free plate, f(x, y) = cos(nπx)·cos(mπy) ± cos(mπx)·cos(nπy), with n and m '
            'derived from the reduced intent, and traces the nodal set f = 0 by marching squares. Those quiet lines are '
            'the sigil.',
        'Motion. Several thousand grains start evenly spread and slide down the energy f², with a little thermal noise, '
            'until they settle on the nodal lines as real sand does. During Gnosis the breath lifts and settles them.',
      ],
      sources: [
        'Attested: E. F. F. Chladni, Entdeckungen über die Theorie des Klanges (1787).',
        'IGNOSIS’s own: using a Chladni mode as a sigil system.',
      ],
    ),
    WikiArticle(
      category: systems,
      title: 'Cyber Chaos',
      summary: 'A strange attractor seeded from the SHA-256 hash of the intent.',
      body: [
        'Method. The intent is hashed with SHA-256, and four of its bytes become the parameters of a Clifford attractor: '
            'xₙ₊₁ = sin(a·yₙ) + c·cos(a·xₙ), yₙ₊₁ = sin(b·xₙ) + d·cos(b·yₙ). Seeds whose orbit is not chaotic, or that '
            'collapse to a few points, are rejected deterministically. The orbit is drawn as a density of ink and folded by '
            'symmetry.',
        'Because the orbit is chaotic, a difference of one unit in the last place between two devices would grow into a '
            'different sigil. The studio therefore computes sine, cosine and logarithm with its own deterministic routines, '
            'so the seal is identical on a phone, a laptop and the web.',
        'Motion. The attractor condenses out of noise over a few seconds, density accumulating like ink soaking into paper.',
      ],
      sources: [
        'Consensus: the attractor is named after Clifford A. Pickover.',
        'IGNOSIS’s own: the system as a whole.',
      ],
    ),

    // ── VII. The making of IGNOSIS ─────────────────────────────────────────
    WikiArticle(
      category: making,
      title: 'Pen & Ink, and the Vermilion Seal',
      summary: 'Why the studio looks the way it does, and the one colour it will not give up.',
      body: [
        'IGNOSIS is drawn in Pen & Ink: paper for the plate, ink for the strokes, hairlines for everything else, and one '
            'vermilion accent. A sigil is a private instrument, and an instrument should not perform. So the studio is '
            'quiet by design, and almost nothing moves that the mathematics does not move.',
        'The vermilion is a role, not merely a colour. Every skin, light or dark, must honour a seal colour, red on paper '
            'and a brighter red in the dark, and the bind point, the kernel letters and the focus ring all wear it. A skin '
            'may change everything else; it may not erase the seal.',
        'The studio is built to WCAG 2.2: every text colour is measured against its background, small text has its own '
            'tertiary ink, labels never fall below 12 points, touch targets are 44 points, and dialogs take the skin’s own '
            'colours, so a meditative rite in a dark room is never interrupted by a white panel.',
      ],
    ),
    WikiArticle(
      category: making,
      title: 'Same Intent, Same Seal',
      summary: 'Determinism as a promise.',
      body: [
        'The same intent always gives the same sigil. A practitioner who returns to a phrase finds the same seal waiting, '
            'on any device, years later. It is a small promise and an expensive one.',
        'It forbids randomness without a seed, and seeds taken from anything but the intent. It forbids trusting the '
            'platform’s floating-point functions in the chaotic system, and so the studio carries its own. It is enforced '
            'by tests that render each system for fixed phrases and compare the images pixel for pixel, and by a test that '
            'runs the same engines in a browser and on the desktop and demands identical results.',
        'Where the studio uses chance on purpose, as in the burn’s embers or the brush’s dry streaks, the chance is seeded '
            'from the seal itself, so even the accidents repeat.',
      ],
    ),
    WikiArticle(
      category: making,
      title: 'Nothing Moves Unless the Mathematics Moves It',
      summary: 'The motion doctrine.',
      body: [
        'The studio does not decorate. Every animation is the time-evolution of the same function that drew the glyph: '
            'either its construction (how it is written), the field it lives in (the square, the rose, the plate), or its '
            'dissolution (the burn). Generic rotation, glow and sparks from nowhere belong to none of these, and so they '
            'have no place here.',
        'Practically: one clock, counted in seconds, that stops when nothing is moving. Strokes revealed by arc length at '
            'a fixed pen speed, so a long sigil takes honestly longer to write. Timing from the minimum-jerk profile that '
            'describes the human hand (Flash & Hogan, 1985), which is what makes a stroke look written rather than tweened. '
            'Idle motion, where there is any, at ratios of φ, so it never visibly repeats. And for anyone whose device asks '
            'for reduced motion, still states in place of movement.',
        'The strokes are laid with a sumi-e brush, after the ink-wash painting of Ōkami: pressure that swells and tapers, '
            'dry-brush streaks near the end of a stroke, and splatter only where the brush first lands. Its texture is '
            'seeded by the stroke, not the moment, so a turning rose does not boil.',
      ],
    ),
    WikiArticle(
      category: making,
      title: 'The Letters: What Is Tradition and What Is Ours',
      summary: 'Why the studio labels its sources.',
      body: [
        'Occult writing is often more confident than its sources. Numerology sold as Pythagorean that Pythagoras never '
            'knew; vowel-stripping credited to Spare, who did not do it; burning presented as a requirement when Carroll '
            'offers it as one option among three. IGNOSIS does not repeat these. It says what is attested, in which source, '
            'and what it invented.',
        'So the default reduction strikes repeated letters, as Carroll does, and dropping vowels is an option marked as '
            'a later convention. The Kamea and the Rose trace the Hebrew spelling, as the Golden Dawn did, and show it. '
            'The “Why reduce?” note explains the step rather than mystifying it. Circumlocution, Cymatic Resonance and Cyber '
            'Chaos are described plainly as IGNOSIS’s own.',
        'None of this makes the practice less. A tool that tells the truth about its parts can be trusted with the '
            'parts that are not about truth at all.',
      ],
    ),
    WikiArticle(
      category: making,
      title: 'Gnosis, the Breath and the Burn',
      summary: 'How the rite is paced, and how the seal is unwritten.',
      body: [
        'Charging follows Carroll’s gnosis, reached here by the breath. The default is slow paced breathing at 5.5 '
            'breaths a minute, near the resonance frequency studied by Lehrer and Vaschillo, with box and 4-7-8 as '
            'alternatives. The breath is the master rhythm: the same curve swells the guide in the dialog and the sigil on '
            'the plate, a soft tick marks each turn for eyes-closed practice, and the dialog sits low and small so the seal '
            'stays the single point of focus. It never advances on its own. After seven breaths the release is offered more '
            'firmly, and that is all.',
        'The burn knows the sigil. Fire starts at the end of the last stroke and runs back along the ink as along a fuse, '
            'branching where strokes touch and creeping slowly across bare paper to reach ink that does not. The seal is '
            'unwritten in the reverse of its writing. A shader draws the char band and the glowing rim: a blackbody ramp on '
            'dark skins, and on light paper a char-dominant edge, because nothing can glow brighter than white paper. '
            'Embers rise on a curl-noise field so the smoke curls rather than slides.',
        'Then silence: the empty plate held for two seconds, Spare’s “Does not matter—need not be” (a line about '
            'non-resistance, not a rule about sigils), and an offer to banish with laughter, as both Spare and Carroll advise.',
        'Forgetting is part of the method, so the reduced letters are hidden while the rite runs, and the intent is '
            'cleared when the seal is gone.',
      ],
      sources: [
        'Attested: Carroll, Liber Null (1978), “Gnosis” and “Sigils”; Spare, The Book of Pleasure (1913).',
        'A focus exercise, not medical advice.',
      ],
    ),
    WikiArticle(
      category: making,
      title: 'The Joule: Paper and Ledger',
      summary: 'Why the on-chain burn is measured against a square of burning paper.',
      body: [
        'The question behind the on-chain rite is a physical one: how much energy does the old ritual release? A '
            'two-inch square of ordinary 80 gsm paper weighs about 0.21 g and burns to about 3,300 joules. One Solana '
            'transaction, by the network’s own 2022 report, costs about 3,290. The on-chain act and the square of paper '
            'release, within half a percent, the same energy. The burn on the ledger is not a metaphor for the burn on the '
            'altar; it is the same quantity of fire, spent elsewhere.',
        'The Joule is the record of it. It is minted once, a fixed supply in which one token stands for one joule, held '
            'entirely by the studio and made non-transferable by the chain itself, so that no one can buy, hold or trade it. '
            'When a practitioner chooses an on-chain witness, the studio burns 1,618 Joules, after φ, at the moment the seal '
            'is released. The burn carries only a salted hash of the intent, computed on the device. The intent never '
            'leaves it, and without the salt nobody, the studio included, can connect the burn to the words.',
        'What the burn is not: an investment, a currency, a sacrifice of money. A token no one can own destroys no '
            'value. The chain is a public witness, permanent and indifferent, which is perhaps the most a ledger can be.',
        'Skins are free while the studio has no store products. When they are sold, they will unlock only on a payment '
            'the store has completed, never on a simulated or failed one.',
      ],
      sources: [
        'Energy: Solana Foundation, Energy Use Report (September 2022): 3,290 J per non-voting transaction. Paper: '
            '2″ × 2″ (25.8 cm²) at 80 gsm and about 16 MJ/kg.',
        'Symbolic and artistic practice. No physical, medical or financial effect is claimed.',
      ],
    ),
  ];
}
