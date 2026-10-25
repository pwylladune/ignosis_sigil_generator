@Tags(['visual'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/ui/screens/sigil_studio_screen.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/ignosis_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full-studio screenshots at phone size:
///   VISUAL_OUT=build/visual flutter test --tags visual --run-skipped test/visual/studio_screenshot_test.dart
void main() {
  final out = Platform.environment['VISUAL_OUT'] ?? 'build/visual';

  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final file = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    if (file.existsSync()) {
      await (FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())))).load();
    }
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    }
  });

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(out).createSync(recursive: true);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('studio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: IgnosisTheme.lightTheme.copyWith(
          textTheme: IgnosisTheme.lightTheme.textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto'), child: const SigilStudioScreen()),
      ),
    ));
    for (var i = 0; i < 6 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shot(tester, key, 'studio_spare');

    await tester.tap(find.text('Planetary Kamea'));
    for (var i = 0; i < 8 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shot(tester, key, 'studio_kamea');

    await tester.tap(find.byIcon(Icons.palette_outlined).first);
    await tester.pumpAndSettle();
    await shot(tester, key, 'studio_skins');
  });
}
