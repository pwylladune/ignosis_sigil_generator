import 'package:flutter/material.dart';
import '../../services/iap_service.dart';
import '../theme/sigil_skins.dart';

/// Records why a purchase or restore could not start (or that a restore is
/// under way) as the store's notice, shown inline by [PurchaseNote] inside
/// the purchase dialogs. A started purchase records nothing: the store sheet
/// speaks for itself and the unlock arrives on the purchase stream.
void reportPurchaseStart(IapService store, PurchaseStart result, {bool restoring = false}) {
  switch (result) {
    case PurchaseStart.started:
      store.setNotice(restoring ? 'Restoring purchases from the store…' : null);
    case PurchaseStart.storeUnavailable:
      store.setNotice('The store is not available on this device.', error: true);
    case PurchaseStart.productUnavailable:
      store.setNotice('This item is not available from the store right now. Check your connection and try again.',
          error: true);
    case PurchaseStart.failed:
      store.setNotice(store.lastError ?? 'The store reported an error.', error: true);
  }
}

/// Inline store notice for purchase dialogs (errors and restore progress).
class PurchaseNote extends StatelessWidget {
  const PurchaseNote({super.key, required this.store, required this.theme});

  final IapService store;
  final SigilSkinTheme theme;

  @override
  Widget build(BuildContext context) {
    final message = store.notice;
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(store.noticeIsError ? Icons.error_outline : Icons.info_outline, size: 16, color: theme.seal),
            const SizedBox(width: 6),
            Expanded(
              child: Text(message, style: TextStyle(fontSize: 12, color: theme.inkSecondary, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
