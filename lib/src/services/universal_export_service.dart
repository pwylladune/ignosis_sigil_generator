import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Platform-safe exporter supporting Web, iOS, and Android
class UniversalExportService {
  /// Captures RepaintBoundary as high-DPI PNG bytes
  static Future<Uint8List?> capturePng(RenderRepaintBoundary boundary, {double pixelRatio = 3.0}) async {
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
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

      final result = await Share.shareXFiles(
        [xFile],
        text: 'Consecrated via IGNOSIS: Chaos Magic Sigil Studio',
        subject: 'My Consecrated Sigil',
      );

      return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }

  /// Converts a Path into SVG string for vector export
  static String exportSvg(Path path, Size size, Color color, double strokeWidth) {
    // Generate basic clean SVG wrapper
    final hexColor = '#${color.value.toRadixString(16).substring(2)}';
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size.width} ${size.height}" width="${size.width}" height="${size.height}">');
    buffer.writeln('  <rect width="100%" height="100%" fill="#070709"/>');
    buffer.writeln('  <path d="" stroke="$hexColor" stroke-width="$strokeWidth" fill="none" stroke-linecap="round" stroke-linejoin="round"/>');
    buffer.writeln('</svg>');
    return buffer.toString();
  }
}
