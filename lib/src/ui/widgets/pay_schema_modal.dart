import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../theme/sigil_skins.dart';

/// Modal dialog detailing the IGNOSIS transparent pay schema & micro-transactions
class PaySchemaModal extends StatelessWidget {
  final SigilSkinTheme theme;

  const PaySchemaModal({super.key, required this.theme});

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
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 20, 16),
              child: Row(
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
                      child: Text('⚖', style: TextStyle(color: theme.accent, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IGNOSIS REVENUE SCHEMA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.inkPrimary,
                        ),
                      ),
                      Text(
                        'Transparent, Free Core Studio & Modular Esoteric Add-ons',
                        style: TextStyle(fontSize: 11, color: theme.inkMuted),
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
            ),
            Divider(height: 1, color: theme.hairline),

            // Content Plans
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 1. FREE TIER - FULL FUNCTIONALITY
                    _buildTierCard(
                      title: 'CORE STUDIO (FREE)',
                      price: 'Free Forever (\$0.00)',
                      badge: 'FULLY FUNCTIONAL',
                      benefits: [
                        'All 5 Mathematical Engines: Spare Monogram, Planetary Kameas (Saturn to Moon), Rose Cross, Chladni Cymatics, and SHA-256 Cyber Chaos.',
                        'Default Vellum & Ink light archival pen-and-ink aesthetic.',
                        'Local gnosis breath charging and simulated digital combustion.',
                        'High-resolution A4 / US-Letter PDF Print Sheets with cut-lines for physical parchment burns.',
                        'Connect any external Solana wallet (Phantom, Solflare, etc.) to burn \$IGNOSIS acquired separately on decentralized exchanges at zero in-app surcharge.',
                      ],
                      isFeatured: false,
                      actionLabel: 'CURRENTLY ACTIVE',
                      onAction: null,
                    ),

                    const SizedBox(height: 16),

                    // 2. IGNITION STARTER PACK ($1.99)
                    _buildTierCard(
                      title: 'IGNITION STARTER PACK',
                      price: '\$${RevenueSchemaConfig.ignitionStarterPackPriceUsd.toStringAsFixed(2)} One-Time',
                      badge: 'RECOMMENDED FOR BEGINNERS',
                      benefits: [
                        'Instantly establishes & provisions an in-app Solana \$IGNOSIS wallet.',
                        'Deposits ${RevenueSchemaConfig.starterPackTokensDeposited} \$IGNOSIS directly into your vault.',
                        'Pre-funds exactly 3 full classical rites (based on standard default of ${RevenueSchemaConfig.defaultBurnAmount} \$IGNOSIS per burn).',
                        'Skip manual DEX swapping or crypto bridging.',
                      ],
                      isFeatured: true,
                      actionLabel: 'ESTABLISH WALLET & CLAIM 279 \$IGNOSIS',
                      onAction: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: theme.inkPrimary,
                            content: const Text('Open Consecration modal to activate Ignition Starter Pack.'),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // 3. AESTHETIC GENRE SKINS ($0.99 each or $3.99 bundle)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'AESTHETIC GENRE SKINS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: theme.inkPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: theme.hairline),
                                ),
                                child: Text(
                                  '\$${RevenueSchemaConfig.individualSkinPriceUsd.toStringAsFixed(2)} EACH',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    color: theme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selectable esoteric visual paradigms altering the entire studio environment, typography, drafting canvas motifs, and ember particles:',
                            style: TextStyle(fontSize: 11, color: theme.inkSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          const Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _GenrePill(label: 'Tech-Occult'),
                              _GenrePill(label: 'Dark Academia'),
                              _GenrePill(label: 'Cosmic'),
                              _GenrePill(label: 'Surrealist'),
                              _GenrePill(label: 'Alchemical'),
                              _GenrePill(label: 'Wiccan'),
                              _GenrePill(label: 'Chaos'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.inkPrimary,
                                side: BorderSide(color: theme.hairline),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'UNLOCK ALL 7 SKINS BUNDLE — \$${RevenueSchemaConfig.allSkinsBundlePriceUsd.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: theme.background,
                border: Border(top: BorderSide(color: theme.hairline)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: theme.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No paywalls on sigil creation or personal crypto burns. Default ritual burn is 93 \$IGNOSIS and fully modifiable.',
                      style: TextStyle(fontSize: 10, color: theme.inkMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required String title,
    required String price,
    required String badge,
    required List<String> benefits,
    required bool isFeatured,
    required String actionLabel,
    required VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isFeatured ? theme.surfaceElevated : theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFeatured ? theme.accent : theme.hairline,
          width: isFeatured ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: theme.inkPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFeatured ? theme.accent.withValues(alpha: 0.1) : theme.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isFeatured ? theme.accent : theme.hairline),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isFeatured ? theme.accent : theme.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isFeatured ? theme.accent : theme.inkPrimary),
          ),
          const SizedBox(height: 12),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✦ ', style: TextStyle(color: theme.accent, fontSize: 10)),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(fontSize: 11, color: theme.inkSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFeatured ? theme.inkPrimary : theme.surface,
                foregroundColor: isFeatured ? theme.surface : theme.inkPrimary,
                side: BorderSide(color: theme.hairline),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenrePill extends StatelessWidget {
  final String label;
  const _GenrePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}
