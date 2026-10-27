import 'package:url_launcher/url_launcher.dart';

/// The legal pages, published with the web app (web/terms.html and siblings).
/// Absolute, so the Android app opens the same pages.
enum LegalPage {
  terms('Terms', 'https://ignosis.net/terms.html'),
  privacy('Privacy', 'https://ignosis.net/privacy.html'),
  refunds('Refunds', 'https://ignosis.net/refunds.html');

  const LegalPage(this.label, this.url);

  final String label;
  final String url;

  /// Opens the page in a new tab (web) or the browser (apps).
  Future<void> open() => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
}
