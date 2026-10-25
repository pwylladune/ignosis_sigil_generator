import 'package:flutter/material.dart';
import '../../models/revenue_schema.dart';
import '../../services/iap_service.dart';
import '../theme/sigil_skins.dart';
import 'purchase_feedback.dart';

/// Modal to choose among the 8 aesthetic skins.
///
/// Premium skins are gated on [IapService] entitlements. Tapping a locked
/// skin previews it behind the dialog (via [onPreview]) and offers an
/// explicit "Unlock · price" button; nothing is bought on a single tap.
class SkinSelectorModal extends StatefulWidget {
  final SigilSkinId currentSkinId;
  final ValueChanged<SigilSkinId> onSkinSelected;

  /// Called with a locked skin to preview it, and with null to end the preview.
  final ValueChanged<SigilSkinId?>? onPreview;
  final SigilSkinTheme theme;
  final IapService? iap;

  const SkinSelectorModal({
    super.key,
    required this.currentSkinId,
    required this.onSkinSelected,
    required this.theme,
    this.onPreview,
    this.iap,
  });

  @override
  State<SkinSelectorModal> createState() => _SkinSelectorModalState();
}

class _SkinSelectorModalState extends State<SkinSelectorModal> {
  SigilSkinId? _previewing;

  IapService get _store => widget.iap ?? IapService.instance;
  SigilSkinTheme get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    // A preview that became a purchase is applied at once.
    final p = _previewing;
    if (p != null && _store.isSkinUnlocked(p.key)) {
      _apply(p);
      return;
    }
    if (mounted) setState(() {});
  }

  void _apply(SigilSkinId skin) {
    widget.onSkinSelected(skin);
    if (mounted) Navigator.of(context).pop();
  }

  void _tap(SigilSkinId skin) {
    if (_store.isSkinUnlocked(skin.key)) {
      _apply(skin);
      return;
    }
    setState(() => _previewing = skin);
    widget.onPreview?.call(skin);
  }

  Future<void> _buy(String productId) async {
    final result = await _store.buy(productId);
    reportPurchaseStart(_store, result);
  }

  /// The store's localised price, or null while it is unknown.
  String? _price(String productId) => _store.product(productId)?.price;

  Widget _priceLabel(String productId) {
    final price = _price(productId);
    if (price != null) {
      return Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.inkSecondary));
    }
    if (_store.isLoadingProducts) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.inkTertiary),
      );
    }
    return Text('Locked', style: TextStyle(fontSize: 12, color: theme.inkTertiary));
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final premium = RevenueSchemaConfig.skinProductIds.keys;
    final owned = premium.where(store.isSkinUnlocked).length;
    final previewProduct = _previewing == null ? null : RevenueSchemaConfig.skinProductIds[_previewing!.key];

    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.hairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SKINS',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: theme.inkPrimary),
                        ),
                        Text(
                          'Tap a locked skin to preview it',
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
              Divider(height: 16, color: theme.hairline),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(right: 12),
                  itemCount: SigilSkinId.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final skinId = SigilSkinId.values[index];
                    final skin = SigilSkinTheme.getSkin(skinId);
                    final isCurrent = skinId == widget.currentSkinId;
                    final isPreview = skinId == _previewing;
                    final unlocked = store.isSkinUnlocked(skinId.key);
                    final productId = RevenueSchemaConfig.skinProductIds[skinId.key];
                    final highlighted = isCurrent || isPreview;

                    return Semantics(
                      button: true,
                      selected: isCurrent,
                      label: '${skin.shortLabel}${unlocked ? '' : ', locked'}',
                      child: InkWell(
                        onTap: () => _tap(skinId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: highlighted ? theme.surfaceElevated : theme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: highlighted ? theme.seal : theme.hairline,
                              width: highlighted ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Swatch: paper, ink and the skin's accent.
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: skin.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: skin.hairlineStrong),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(color: skin.inkPrimary, shape: BoxShape.circle),
                                    ),
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      skin.shortLabel,
                                      style: TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.bold, color: theme.inkPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      skinId.description,
                                      style: TextStyle(fontSize: 12, color: theme.inkSecondary, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isCurrent)
                                Icon(Icons.check_circle, size: 20, color: theme.seal)
                              else if (!unlocked && productId != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 16, color: theme.inkTertiary),
                                    const SizedBox(width: 4),
                                    _priceLabel(productId),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: PurchaseNote(store: store, theme: theme),
              ),
              if (previewProduct != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.inkPrimary,
                        foregroundColor: theme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _buy(previewProduct),
                      child: Text(
                        _price(previewProduct) == null
                            ? 'UNLOCK ${SigilSkinTheme.getSkin(_previewing!).shortLabel.toUpperCase()}'
                            : 'UNLOCK ${SigilSkinTheme.getSkin(_previewing!).shortLabel.toUpperCase()} · ${_price(previewProduct)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton(
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
                  const Spacer(),
                  if (owned < premium.length)
                    TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      onPressed: () => _buy(RevenueSchemaConfig.allSkinsBundleId),
                      child: Text(
                        [
                          owned == 0 ? 'ALL 7 SKINS' : 'REMAINING SKINS',
                          if (_price(RevenueSchemaConfig.allSkinsBundleId) != null)
                            _price(RevenueSchemaConfig.allSkinsBundleId)!,
                        ].join(' · '),
                        style:
                            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: theme.seal),
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
