import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/sigil_skins.dart';

/// Minimalist, high-security dialog displaying the practitioner's 12-word recovery phrase
class SeedPhraseExportModal extends StatefulWidget {
  final String mnemonic;
  final String publicAddress;
  final SigilSkinTheme theme;

  const SeedPhraseExportModal({
    super.key,
    required this.mnemonic,
    required this.publicAddress,
    required this.theme,
  });

  @override
  State<SeedPhraseExportModal> createState() => _SeedPhraseExportModalState();
}

class _SeedPhraseExportModalState extends State<SeedPhraseExportModal> {
  bool _revealWords = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final words = widget.mnemonic.trim().split(RegExp(r'\s+'));

    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.hairline),
                    ),
                    child: Center(
                      child: Text('🗝', style: TextStyle(color: theme.accent, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SECRET RECOVERY VAULT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.inkPrimary,
                        ),
                      ),
                      Text(
                        '12-Word Master Cryptographic Mnemonic',
                        style: TextStyle(fontSize: 10, color: theme.inkMuted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: theme.inkMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.hairline),
              const SizedBox(height: 14),

              // Public Solana Address Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SOLANA PUBLIC VAULT ADDRESS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.inkMuted)),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: widget.publicAddress));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: theme.inkPrimary,
                                content: const Text('Solana Address copied to clipboard.'),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 11, color: theme.accent),
                              const SizedBox(width: 4),
                              Text('COPY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.accent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.publicAddress,
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: theme.inkPrimary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reveal / Hide Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '12 RECOVERY SEED WORDS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.inkSecondary),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () {
                      setState(() {
                        _revealWords = !_revealWords;
                      });
                    },
                    icon: Icon(_revealWords ? Icons.visibility_off : Icons.visibility, size: 14),
                    label: Text(_revealWords ? 'HIDE WORDS' : 'REVEAL WORDS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 3x4 Words Grid
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.hairline),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.inkMuted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _revealWords ? words[index] : '••••••',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: _revealWords ? 'monospace' : null,
                                color: theme.inkPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Warning Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: theme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Do not photograph or share these words. Anyone with this phrase has irrevocable custody over your \$IGNOSIS vault.',
                        style: TextStyle(fontSize: 10, color: theme.inkSecondary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Copy All Button
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.inkPrimary,
                    foregroundColor: theme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.mnemonic));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: theme.inkPrimary,
                        content: const Text('12 Secret Words copied to clipboard. Paste and store securely offline!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text(
                    'COPY RECOVERY PHRASE TO CLIPBOARD',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
