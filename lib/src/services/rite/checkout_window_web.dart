import 'package:web/web.dart' as web;

/// Where Stripe Checkout opens: a new tab, so the rite in progress keeps its
/// state. Browsers block tabs opened after an await, so the tab is opened
/// blank in the tap itself and pointed at Checkout once the session exists.
class CheckoutWindow {
  CheckoutWindow._(this._tab);

  final web.Window? _tab;

  /// Call synchronously in the tap handler, before any await.
  static CheckoutWindow open() => CheckoutWindow._(web.window.open('', '_blank'));

  Future<void> go(Uri url) async {
    final tab = _tab;
    if (tab != null) {
      tab.location.href = url.toString();
    } else {
      // The blank tab was blocked: try once more (the browser may block it too).
      web.window.open(url.toString(), '_blank');
    }
  }

  void close() => _tab?.close();
}
