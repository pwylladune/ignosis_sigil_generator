import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../../services/iap_service.dart';
import '../theme/sigil_skins.dart';
import 'purchase_feedback.dart';

/// Modal dialog detailing the IGNOSIS transparent pay schema & micro-transactions
class PaySchemaModal extends StatelessWidget {
  final SigilSkinTheme theme;
  final IapService? iap;

  const PaySchemaModal({super.key, required this.theme, this.iap});

  @override
  Widget build(BuildContext context) {
    final store = iap ?? IapService.instance;
    return ListenableBuilder(listenable: store, builder: (context, _) => _buildDialog(context, store));
  }

  Widget _buildDialog(BuildContext context, IapService store) {
    final bundleOwned = RevenueSchemaConfig.skinProductIds.keys.every(store.isSkinUnlocked);
    // Only ever show prices the store returned (localised); never hard-coded USD.
    final bundlePrice = store.product(RevenueSchemaConfig.allSkinsBundleId)?.price;
    final skinPrice = store.product(RevenueSchemaConfig.skinChaosId)?.price;
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
                        'Gnosis breath charging and ritual combustion of the seal.',
                        'High-resolution A4 / US-Letter PDF Print Sheets with cut-lines for physical parchment burns.',
                      ],
                      isFeatured: false,
                      actionLabel: 'CURRENTLY ACTIVE',
                      onAction: null,
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
                                  skinPrice == null ? 'ONE-TIME UNLOCK' : '$skinPrice EACH',
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
                              onPressed: bundleOwned
                                  ? null
                                  : () async {
                                      final result = await store.buy(RevenueSchemaConfig.allSkinsBundleId);
                                      if (context.mounted) showPurchaseFeedback(context, theme, result);
                                    },
                              child: Text(
                                bundleOwned
                                    ? 'ALL 7 SKINS UNLOCKED'
                                    : bundlePrice == null
                                        ? 'UNLOCK ALL 7 SKINS BUNDLE'
                                        : 'UNLOCK ALL 7 SKINS BUNDLE — $bundlePrice',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                            ),
                          ),
                          if (store.lastError != null) ...[
                            const SizedBox(height: 10),
                            PurchaseErrorNote(message: store.lastError!, theme: theme),
                          ],
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: store.isRestoring
                                  ? null
                                  : () async {
                                      final result = await store.restorePurchases();
                                      if (context.mounted) showPurchaseFeedback(context, theme, result, restoring: true);
                                    },
                              child: Text(
                                store.isRestoring ? 'RESTORING…' : 'RESTORE PURCHASES',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.inkSecondary),
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
                      'No paywalls on sigil creation, charging, burning or printing. Skins are cosmetic, one-time unlocks.',
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
