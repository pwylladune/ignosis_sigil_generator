import 'package:flutter/material.dart';
import '../../config/feature_flags.dart';
import '../theme/ignosis_theme.dart';

/// Modal dialog explaining the complete philosophy, science, and step-by-step
/// ritual mechanics of Chaos Sigil crafting and combustion.
class RitualExegesisModal extends StatelessWidget {
  const RitualExegesisModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: IgnosisTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: IgnosisTheme.parchmentSubtle),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: IgnosisTheme.paperWhite,
                      border: Border.all(color: IgnosisTheme.parchmentSubtle),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '🜂',
                        style: TextStyle(fontSize: 16, color: IgnosisTheme.vermilion),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE RITUAL OF IGNOSIS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: IgnosisTheme.sumiInk,
                        ),
                      ),
                      Text(
                        'The "Why" and Mechanics of Sigil Combustion',
                        style: TextStyle(fontSize: 12, color: IgnosisTheme.pencilGraphite),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: IgnosisTheme.pencilGraphite),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: IgnosisTheme.parchmentSubtle),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('1. THE FOUNDATIONAL PRINCIPLE (CHAOS MAGICK)'),
                    _buildParagraph(
                      'Pioneered by artist-occultist Austin Osman Spare and codified by Peter J. Carroll (Liber Null), '
                      'chaos magick treats ritual as pure psychological and informational technology. '
                      'A sigil is an encoded glyph of conscious will designed to bypass your psychic censor—planting '
                      'your intention deep into the subconscious matrix without the paralyzing friction of conscious doubt.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('2. STATEMENT OF INTENT TO PURE GEOMETRY'),
                    _buildStepRow('A', 'Formulate Intent', 'Phrase your will in the present or affirmative tense (e.g. "I EMBODY UNWAVERING CLARITY").'),
                    _buildStepRow('B', 'Spare Reduction', 'Vowels and duplicate consonants are stripped, leaving an irreducible phonetic kernel.'),
                    _buildStepRow('C', 'Geometric Transmutation', 'The remaining phonetic matrix is projected across mathematical ciphers (Planetary Kameas, Rose Cross Wheels, Chladni acoustic waves, or Cryptographic Entropy).'),
                    const SizedBox(height: 20),

                    _buildSectionHeader('3. GNOSIS (THE CHARGING TRANCE)'),
                    _buildParagraph(
                      'A sigil must be charged during a state of Gnosis—a peak threshold of absolute singular focus where the discursive '
                      'mind goes completely silent. In the studio, the breath-pacing ring brings your awareness into rhythmic theta/alpha harmony.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('4. THE "BURN" & "FREE BELIEF" (FORGETTING)'),
                    _buildParagraph(
                      'Spare established the iron law of sigils: "Does not matter, need not be." Obsessing over your desire binds it to '
                      'the conscious ego and prevents subconscious execution. Therefore, the physical or digital substrate must be '
                      'DESTROYED. Burning the sigil breaks emotional attachment and releases the intention to chaos.',
                    ),
                    const SizedBox(height: 20),

                    if (kEnableChain) ...[
                      _buildSectionHeader(r'5. THE $IGNOSIS ON-CHAIN COMBUSTION'),
                      _buildParagraph(
                        r'In classical alchemy, physical fire releases chemical bonds as thermal heat. In the digital universe, '
                        r'$IGNOSIS bridges on-chain decentralization with energetic sacrifice. Burning $IGNOSIS sends real tokens to the Solana incinerator, '
                        r'forever carving the mathematical proof-of-heat onto the distributed ledger while totally purging your intent text from local memory.',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: const BoxDecoration(
                color: IgnosisTheme.paperWhite,
                border: Border(top: BorderSide(color: IgnosisTheme.parchmentSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: IgnosisTheme.sumiInk,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('UNDERSTOOD · ENTER STUDIO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: IgnosisTheme.charcoal,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.6,
        color: IgnosisTheme.charcoal,
      ),
    );
  }

  Widget _buildStepRow(String letter, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              color: IgnosisTheme.bone,
              border: Border.all(color: IgnosisTheme.parchmentSubtle),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: IgnosisTheme.vermilion),
              ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: IgnosisTheme.charcoal, height: 1.4),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
