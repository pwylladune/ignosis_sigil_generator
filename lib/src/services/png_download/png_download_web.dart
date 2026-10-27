import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// The browser saves the file to its downloads folder.
const bool canDownloadPng = true;

/// Saves [bytes] as [filename] through a temporary download link.
Future<bool> downloadPng(Uint8List bytes, String filename) async {
  try {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    link.style.display = 'none';
    web.document.body?.append(link);
    link.click();
    link.remove();
    // The browser has the file once the click is handled; free the blob after.
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}
