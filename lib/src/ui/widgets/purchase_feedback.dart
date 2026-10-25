import 'package:flutter/material.dart';
import '../../services/iap_service.dart';
import '../theme/sigil_skins.dart';

/// Tells the user why a purchase or restore could not start. A started
/// purchase reports nothing here: the store sheet speaks for itself and the
/// unlock arrives on the purchase stream.
void showPurchaseFeedback(BuildContext context, SigilSkinTheme theme, PurchaseStart result, {bool restoring = false}) {
  final String? message;
  switch (result) {
    case PurchaseStart.started:
      message = restoring ? 'Restoring purchases from the store…' : null;
    case PurchaseStart.storeUnavailable:
      message = 'The store is not available on this device.';
    case PurchaseStart.productUnavailable:
      message = 'This item is not available from the store right now. Check your connection and try again.';
    case PurchaseStart.failed:
      message = IapService.instance.lastError ?? 'The store reported an error.';
  }
  if (message == null) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(backgroundColor: theme.inkPrimary, content: Text(message, style: TextStyle(color: theme.surface))),
  );
}

/// Inline note for the last store error, shown inside purchase dialogs.
class PurchaseErrorNote extends StatelessWidget {
  const PurchaseErrorNote({super.key, required this.message, required this.theme});

  final String message;
  final SigilSkinTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 14, color: theme.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: TextStyle(fontSize: 10, color: theme.inkSecondary, height: 1.4)),
        ),
      ],
    );
  }
}
