import 'package:url_launcher/url_launcher.dart';

/// Where Stripe Checkout opens. Off the web, the system browser.
class CheckoutWindow {
  CheckoutWindow._();

  /// Call synchronously in the tap handler (see the web implementation).
  static CheckoutWindow open() => CheckoutWindow._();

  Future<void> go(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  void close() {}
}
