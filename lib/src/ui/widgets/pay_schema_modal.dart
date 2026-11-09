import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../../services/iap_service.dart';
import '../../services/rite/rite_service.dart';
import '../theme/sigil_skins.dart';
import 'purchase_feedback.dart';
import 'rite_witness.dart';

/// "Free and paid": what is free, what the skins cost when they are sold
/// (with the bundle and Restore actions), and the optional on-chain records.
/// Prices are only ever the store's localised ones.
class PaySchemaModal extends StatelessWidget {
  final SigilSkinTheme theme;
  final IapService? iap;

  /// The on-chain rite, when it is enabled: its packages can be bought here,
  /// away from the rite itself.
  final RiteService? rite;

  const PaySchemaModal({super.key, required this.theme, this.iap, this.rite});

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
        borderRadius: BorderRadius.circular(10),
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
                        Semantics(
                          header: true,
                          child: Text(
                            'Free and paid',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.inkPrimary),
                          ),
                        ),
                        Text(
                          store.sellSkins
                              ? 'The studio is free. Skins are optional, one-time unlocks.'
                              : 'The studio and every skin are free.',
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
                      title: 'Core studio',
                      badge: 'Free',
                      children: [
                        for (final b in const [
                          'All seven systems: Circumlocution, Monogram (after Spare), Planetary Kamea, Golden Dawn Rose, Cymatic Resonance, '
                              'Cyber Chaos and The Infinite.',
                          'The default Vellum & Ink skin.',
                          'Gnosis breathing and the ritual burn.',
                          'Share the seal, or print a burn sheet (A4 or US Letter).',
                        ])
                          _bullet(b),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!store.sellSkins)
                      _card(
                        title: 'Skins',
                        badge: 'Free for now',
                        children: [
                          Text(
                            'Each skin restyles the whole studio, canvas and burn. All of them are free for now.',
                            style: TextStyle(fontSize: 14, color: theme.inkSecondary, height: 1.4),
                          ),
                        ],
                      )
                    else
                    _card(
                      title: 'Skins',
                      badge: skinPrice == null ? 'One-time unlock' : '$skinPrice each',
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
                              side: BorderSide(color: theme.inkTertiary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: owned == premium.length
                                ? null
                                : () async {
                                    final result = await store.buy(RevenueSchemaConfig.allSkinsBundleId);
                                    reportPurchaseStart(store, result);
                                  },
                            child: Text(
                              owned == premium.length
                                  ? 'All skins unlocked'
                                  : [
                                      owned == 0 ? 'Unlock all 7 skins' : 'Unlock remaining skins',
                                      if (bundlePrice != null) bundlePrice,
                                    ].join(' · '),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        PurchaseNote(store: store, theme: theme),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                            onPressed: store.isRestoring
                                ? null
                                : () async {
                                    final result = await store.restorePurchases();
                                    reportPurchaseStart(store, result, restoring: true);
                                  },
                            child: Text(
                              store.isRestoring ? 'Restoring…' : 'Restore purchases',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.inkSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (rite != null) ...[
                      const SizedBox(height: 16),
                      _card(
                        title: 'On-chain records',
                        badge: 'Optional · paid',
                        children: [
                          Text(
                            'A paid record that a rite happened: $riteJoulesLabel is burnt on Solana when you '
                            'release a seal. Your seal burns the same without it. Bought in packages of rites.',
                            style: TextStyle(fontSize: 14, color: theme.inkSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          RiteWitnessRow(theme: theme, service: rite!),
                        ],
                      ),
                    ],
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.inkPrimary),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: theme.hairlineStrong),
                ),
                child: Text(badge, style: TextStyle(fontSize: 12, color: theme.inkSecondary)),
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
            Text('–  ', style: TextStyle(color: theme.inkTertiary, fontSize: 14, height: 1.4)),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: theme.inkSecondary, height: 1.4))),
          ],
        ),
      );

  Widget _pill(String label, bool owned) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: owned ? theme.seal : theme.inkTertiary),
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
