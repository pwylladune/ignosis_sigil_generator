import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../../services/iap_service.dart';
import '../theme/sigil_skins.dart';
import 'purchase_feedback.dart';

/// Clean minimalist modal to select from the 8 aesthetic magic genre skins.
///
/// Premium skins are gated on [IapService] entitlements: a locked skin shows
/// its store price and starts a purchase instead of being applied.
class SkinSelectorModal extends StatelessWidget {
  final SigilSkinId currentSkinId;
  final ValueChanged<SigilSkinId> onSkinSelected;
  final SigilSkinTheme theme;
  final IapService? iap;

  const SkinSelectorModal({
    super.key,
    required this.currentSkinId,
    required this.onSkinSelected,
    required this.theme,
    this.iap,
  });

  @override
  Widget build(BuildContext context) {
    final store = iap ?? IapService.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _buildDialog(context, store),
    );
  }

  Future<void> _buy(BuildContext context, IapService store, String productId) async {
    final result = await store.buy(productId);
    if (context.mounted) showPurchaseFeedback(context, theme, result);
  }

  /// The store's localised price; never a hard-coded one.
  String _price(IapService store, String productId) => store.product(productId)?.price ?? 'UNLOCK';

  Widget _buildDialog(BuildContext context, IapService store) {
    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.hairline),
                    ),
                    child: const Center(
                      child: Text('🎨', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESOTERIC AESTHETIC SKINS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.inkPrimary,
                        ),
                      ),
                      Text(
                        'Select visual paradigm for studio and canvas',
                        style: TextStyle(fontSize: 10, color: theme.inkMuted),
                      ),
                    ],
                  ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: theme.inkMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.hairline),
              const SizedBox(height: 12),

              // Skin Grid List
              Expanded(
                child: ListView.separated(
                  itemCount: SigilSkinId.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final skinId = SigilSkinId.values[index];
                    final skin = SigilSkinTheme.getSkin(skinId);
                    final isSelected = skinId == currentSkinId;
                    final unlocked = store.isSkinUnlocked(skinId.key);
                    final productId = RevenueSchemaConfig.skinProductIds[skinId.key];

                    return InkWell(
                      onTap: () {
                        if (!unlocked && productId != null) {
                          _buy(context, store, productId);
                          return;
                        }
                        onSkinSelected(skinId);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.surfaceElevated : theme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? theme.accent : theme.hairline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Palette swatches preview
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: skin.background,
                                shape: BoxShape.circle,
                                border: Border.all(color: skin.hairlineStrong),
                              ),
                              child: Center(
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: skin.inkPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        skin.id.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.inkPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: theme.hairline,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          skin.id.isDark ? 'DARK' : 'LIGHT',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: theme.inkMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    skin.id.description,
                                    style: TextStyle(fontSize: 10, color: theme.inkSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle, size: 18, color: theme.accent)
                            else if (!unlocked && productId != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, size: 14, color: theme.inkMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    _price(store, productId),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.inkSecondary),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (store.lastError != null) ...[
                const SizedBox(height: 10),
                PurchaseErrorNote(message: store.lastError!, theme: theme),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
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
                  const Spacer(),
                  if (RevenueSchemaConfig.skinProductIds.keys.any((k) => !store.isSkinUnlocked(k)))
                    TextButton(
                      onPressed: () => _buy(context, store, RevenueSchemaConfig.allSkinsBundleId),
                      child: Text(
                        'ALL 7 · ${_price(store, RevenueSchemaConfig.allSkinsBundleId)}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.accent),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
