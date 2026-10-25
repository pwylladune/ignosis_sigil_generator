import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../../services/iap_service.dart';
import '../theme/sigil_skins.dart';
import 'purchase_feedback.dart';

/// "Skins & support": what is free, what the optional skins cost, and the
/// bundle and Restore actions. Prices are only ever the store's localised ones.
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
    final premium = RevenueSchemaConfig.skinProductIds.keys;
    final owned = premium.where(store.isSkinUnlocked).length;
    final bundlePrice = store.product(RevenueSchemaConfig.allSkinsBundleId)?.price;
    final skinPrice = store.product(RevenueSchemaConfig.skinChaosId)?.price;

    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SKINS & SUPPORT',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: theme.inkPrimary),
                        ),
                        Text(
                          'The studio is free. Skins are optional, one-time unlocks.',
                          style: TextStyle(fontSize: 12, color: theme.inkTertiary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: theme.inkTertiary),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.hairline),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _card(
                      title: 'CORE STUDIO',
                      badge: 'FREE · INCLUDED',
                      children: [
                        for (final b in const [
                          'All five systems: Monogram (after Spare), Planetary Kamea, Golden Dawn Rose, Chladni plate and Cyber Chaos.',
                          'The default Vellum & Ink skin.',
                          'Gnosis breathing and the ritual burn.',
                          'Share the seal, or print a burn sheet (A4 or US Letter).',
                        ])
                          _bullet(b),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _card(
                      title: 'SKINS',
                      badge: skinPrice == null ? 'ONE-TIME UNLOCK' : '$skinPrice EACH',
                      children: [
                        Text(
                          'Each skin restyles the whole studio, canvas and burn.',
                          style: TextStyle(fontSize: 14, color: theme.inkSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final id in SigilSkinId.values)
                              if (RevenueSchemaConfig.skinProductIds.containsKey(id.key))
                                _pill(SigilSkinTheme.getSkin(id).shortLabel, store.isSkinUnlocked(id.key)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.inkPrimary,
                              side: BorderSide(color: theme.hairlineStrong),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: owned == premium.length
                                ? null
                                : () async {
                                    final result = await store.buy(RevenueSchemaConfig.allSkinsBundleId);
                                    reportPurchaseStart(store, result);
                                  },
                            child: Text(
                              owned == premium.length
                                  ? 'ALL SKINS UNLOCKED'
                                  : [
                                      owned == 0 ? 'UNLOCK ALL 7 SKINS' : 'UNLOCK REMAINING SKINS',
                                      if (bundlePrice != null) bundlePrice,
                                    ].join(' · '),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                          ),
                        ),
                        PurchaseNote(store: store, theme: theme),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                            onPressed: store.isRestoring
                                ? null
                                : () async {
                                    final result = await store.restorePurchases();
                                    reportPurchaseStart(store, result, restoring: true);
                                  },
                            child: Text(
                              store.isRestoring ? 'RESTORING…' : 'RESTORE PURCHASES',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.inkSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required String badge, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.inkPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.hairlineStrong),
                ),
                child: Text(
                  badge,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: theme.inkSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✦ ', style: TextStyle(color: theme.seal, fontSize: 12)),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: theme.inkSecondary, height: 1.4))),
          ],
        ),
      );

  Widget _pill(String label, bool owned) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: owned ? theme.seal : theme.hairlineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (owned) ...[Icon(Icons.check, size: 14, color: theme.seal), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 12, color: theme.inkPrimary)),
          ],
        ),
      );
}
