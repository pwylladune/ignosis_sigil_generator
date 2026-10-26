import 'package:flutter/material.dart';
import '../../config/feature_flags.dart';
import '../theme/sigil_skins.dart';
import 'ignosis_mark.dart';

/// Modal dialog explaining the complete philosophy, science, and step-by-step
/// ritual mechanics of Chaos Sigil crafting and combustion.
class RitualExegesisModal extends StatelessWidget {
  const RitualExegesisModal({super.key, required this.theme});

  final SigilSkinTheme theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
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
                  IgnosisMark(skin: theme, size: 34),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE RITUAL OF IGNOSIS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: theme.inkPrimary,
                        ),
                      ),
                      Text(
                        'The "Why" and Mechanics of Sigil Combustion',
                        style: TextStyle(fontSize: 12, color: theme.inkTertiary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: theme.inkTertiary),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.hairline),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('1. THE FOUNDATIONAL PRINCIPLE (CHAOS MAGICK)'),
                    _buildParagraph(
                      'Sigil magic in this form comes from the artist-occultist Austin Osman Spare (The Book of Pleasure, 1913) and was '
                      'systematised by Peter J. Carroll (Liber Null, 1978). In chaos magick a sigil is understood as a glyph of intent '
                      'meant to slip past what Carroll calls the "psychic censor", so the wish can work without the friction of conscious doubt.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('2. STATEMENT OF INTENT TO PURE GEOMETRY'),
                    _buildStepRow('A', 'Formulate Intent', 'Spare and Carroll phrase it as a wish ("This my wish to obtain…"); present-tense affirmations are a later convention. Use whichever your mind does not argue with.'),
                    _buildStepRow('B', 'Reduce the Letters', 'Repeated letters are struck out (Carroll, Liber Null). Removing vowels too is a later popular convention, offered as an option. The Kamea and Rose Cross instead trace the Hebrew spelling, as the Golden Dawn did.'),
                    _buildStepRow('C', 'Draw the Glyph', 'The letters are drawn through a system: Spare-style monogram, planetary kamea, Golden Dawn rose, Chladni plate or a hash-seeded attractor. The last two are IGNOSIS\'s own.'),
                    const SizedBox(height: 20),

                    _buildSectionHeader('3. GNOSIS (THE CHARGING TRANCE)'),
                    _buildParagraph(
                      'Carroll teaches that a sigil is charged in "gnosis": a peak of single-pointed focus, reached by inhibitory methods '
                      '(stillness, trance) or excitatory ones (dance, chanting). In the studio, the breath ring paces a slow, steady rhythm '
                      'to help gather your attention.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('4. FORGETTING (AND THE OPTIONAL BURN)'),
                    _buildParagraph(
                      'Spare\'s formula of non-attachment was "Does not matter—need not be" (The Book of Pleasure). He advised '
                      '"a deliberate striving to forget" the sigil; dwelling on the outcome, what Carroll (after Crowley) calls '
                      '"lust of result", keeps the wish in doubting conscious thought. Destroying the sigil is a later, optional custom: '
                      'Carroll says it "may be burnt, buried, or cast into an ocean". The studio\'s burn is that gesture.',
                    ),
                    const SizedBox(height: 20),
                    _buildParagraph(
                      'Symbolic and artistic practice. No physical, medical or financial effect is claimed.',
                    ),
                    const SizedBox(height: 20),

                    if (kEnableChain) ...[
                      _buildSectionHeader(r'5. THE $IGNOSIS ON-CHAIN COMBUSTION'),
                      _buildParagraph(
                        r'Fire consumes its substrate irreversibly. In the digital universe, '
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
              decoration: BoxDecoration(
                color: theme.canvasBackground,
                border: Border(top: BorderSide(color: theme.hairline)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.inkPrimary,
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: theme.inkSecondary,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: theme.inkSecondary,
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
              color: theme.background,
              border: Border.all(color: theme.hairline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.seal),
              ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: theme.inkSecondary, height: 1.4),
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
