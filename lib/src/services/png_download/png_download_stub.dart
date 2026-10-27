import 'dart:typed_data';

/// Saving a file straight to disk is a browser feature; the apps save through
/// the share sheet (Save Image, Save to Files) instead.
const bool canDownloadPng = false;

Future<bool> downloadPng(Uint8List bytes, String filename) async => false;
