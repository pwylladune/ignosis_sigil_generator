import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/rite/checkout_window.dart';
import '../../services/rite/rite_service.dart';
import '../theme/sigil_skins.dart';

/// Joules burnt per release, as the backend burns them (shown, not enforced).
const riteJoulesLabel = '1618 J';

const _privacy = 'Only a salted hash of your intent is recorded. The intent never leaves this device.';

/// The Gnosis dialog's on-chain line: buy a witnessed release, wait for the
/// payment, or choose whether the release is burnt on-chain.
class RiteWitnessRow extends StatelessWidget {
  const RiteWitnessRow({super.key, required this.theme, required this.service});

  final SigilSkinTheme theme;
  final RiteService service;

  Future<void> _buy() async {
    if (service.usesStore) return service.buyInStore();
    // Opened in the tap itself: browsers block tabs opened after an await.
    final tab = CheckoutWindow.open();
    final url = await service.beginCheckout();
    url == null ? tab.close() : await tab.go(url);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final label = TextStyle(color: theme.inkPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0);
        final sub = TextStyle(color: theme.inkTertiary, fontSize: 12, height: 1.35);
        final Widget trailing;
        final String detail;
        if (service.credits > 0) {
          detail = service.witness ? 'Your release will be burnt on-chain.' : 'Paid; this release stays off-chain.';
          trailing = Switch(
            value: service.witness,
            activeThumbColor: theme.seal,
            onChanged: (v) => service.witness = v,
          );
        } else if (service.awaitingPayment) {
          detail = 'Waiting for payment in the checkout tab…';
          trailing = SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.inkTertiary),
              ),
            ),
          );
        } else {
          detail = service.notice ?? 'Burn $riteJoulesLabel on Solana when you release.';
          trailing = TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44), foregroundColor: theme.seal),
            onPressed: _buy,
            child: Text(
              service.storePrice == null ? 'ADD' : 'ADD · ${service.storePrice}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          );
        }
        return Tooltip(
          message: _privacy,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              border: Border.all(color: theme.hairlineStrong),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: theme.seal, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('WITNESS ON-CHAIN · $riteJoulesLabel', style: label),
                      const SizedBox(height: 2),
                      Semantics(liveRegion: true, child: Text(detail, style: sub)),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Under the dissolved seal: the release's on-chain record as it is burnt,
/// confirmed and read back. Shows nothing for an off-chain release.
class RiteWitnessRecord extends StatelessWidget {
  const RiteWitnessRecord({super.key, required this.theme, required this.service});

  final SigilSkinTheme theme;
  final RiteService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final style = TextStyle(color: theme.inkTertiary, fontSize: 12, height: 1.4);
        final receipt = service.current;
        final Widget child = switch (service.state) {
          RiteWitnessState.none => const SizedBox.shrink(),
          RiteWitnessState.burning => Text('Burning $riteJoulesLabel on-chain…', style: style),
          RiteWitnessState.failed => Text(service.notice ?? 'The on-chain burn did not go through.', style: style),
          RiteWitnessState.witnessed when receipt != null => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  receipt.verified
                      ? '${receipt.joules} J burnt on-chain · verified'
                      : '${receipt.joules} J burnt on-chain',
                  style: style,
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: theme.seal),
                  onPressed: () => launchUrl(Uri.parse(receipt.explorerUrl), webOnlyWindowName: '_blank'),
                  child: const Text(
                    'VIEW THE RECORD',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          RiteWitnessState.witnessed => const SizedBox.shrink(),
        };
        return Semantics(liveRegion: true, child: child);
      },
    );
  }
}
