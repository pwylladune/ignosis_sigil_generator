import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../theme/sigil_skins.dart';

/// Modal dialog for subscribing or purchasing $IGNOSIS burn allowances
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
                      child: Text('🜂', style: TextStyle(color: theme.accent, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IGNOSIS MEMBERSHIP & REVENUE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.inkPrimary,
                        ),
                      ),
                      Text(
                        'Universal Revenue & Tier Access Across iOS, Android & Web',
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
                    _buildTierCard(
                      tier: SubscriptionTier.adept,
                      price: '\$4.99 / month or \$39.99 / year',
                      badge: 'MOST POPULAR',
                      benefits: [
                        'Instant access to all 8 aesthetic skins (Tech-Occult, Cosmic, Alchemical, etc.)',
                        'Unlimited high-resolution PDF print sheets with cut lines',
                        'Vector SVG export for laser engraving & physical talismans',
                        'Full access to the Chaos Magic Wiki & Philosophy Archives',
                      ],
                      isFeatured: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTierCard(
                      tier: SubscriptionTier.magus,
                      price: '\$12.99 / month',
                      badge: 'FULL ON-CHAIN',
                      benefits: [
                        'All Adept features included',
                        'Monthly bank of 372 \$IGNOSIS tokens deposited to your Solana address',
                        'Direct in-app on-chain consecrations without manual gas hassle',
                        'Permanent listing in the Cosmic Pyre Global Archival Registry',
                      ],
                      isFeatured: false,
                    ),
                    const SizedBox(height: 16),
                    _buildPackTile(
                      title: '3-RITUAL CONSECRATION BUNDLE',
                      subtitle: 'Micro-pack: 279 \$IGNOSIS + PDF sheets',
                      price: '\$1.99',
                    ),
                  ],
                ),
              ),
            ),

            // Footer note on cross-platform sync
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: theme.background,
                border: Border(top: BorderSide(color: theme.hairline)),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, size: 14, color: theme.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Purchases restore across iOS, Android, and Web automatically via your account or connected Solana wallet.',
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
    required SubscriptionTier tier,
    required String price,
    required String badge,
    required List<String> benefits,
    required bool isFeatured,
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
                tier.title.toUpperCase(),
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
              onPressed: () {},
              child: Text(
                'ACTIVATE ${tier.title.toUpperCase()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackTile({
    required String title,
    required String subtitle,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.inkPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 10, color: theme.inkMuted)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.surface,
              foregroundColor: theme.inkPrimary,
              elevation: 0,
              side: BorderSide(color: theme.hairline),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {},
            child: Text(price, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
