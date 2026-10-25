import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Platform-safe exporter supporting Web, iOS, and Android
class UniversalExportService {
  /// Encodes an image as PNG bytes.
  static Future<Uint8List?> encodePng(ui.Image image) async {
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image.dispose();
    }
  }

  /// Exports and shares PNG across iOS, Android, and Web
  static Future<bool> shareSigilPng(Uint8List pngBytes, String filenamePrefix) async {
    try {
      final filename = '${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';

      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: filename,
      );

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Consecrated via IGNOSIS: Chaos Magic Sigil Studio',
          subject: 'My Consecrated Sigil',
        ),
      );

      return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }
}
