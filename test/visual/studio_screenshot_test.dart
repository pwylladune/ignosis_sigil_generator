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

  /// The studio at [size] with the intro [seen] or not, then with an intent,
  /// the rite dialog and the "Free and paid" sheet.
  Future<void> states(WidgetTester tester, Size size, String tag, {required bool seen, String? skin}) async {
    SharedPreferences.setMockInitialValues({'ignosis_intro_seen': seen, if (skin != null) 'ignosis_selected_skin': skin});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await shot(tester, key, 'studio_${tag}_empty');
    if (!seen) return;

    await tester.enterText(find.byType(TextField), 'I command radiant clarity');
    for (var i = 0; i < 8 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shot(tester, key, 'studio_${tag}_intent');
    if (skin != null) return;

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free and paid'));
    await tester.pumpAndSettle();
    await shot(tester, key, 'studio_${tag}_free_and_paid');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('III · Charge the seal'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shot(tester, key, 'studio_${tag}_charge');
  }

  testWidgets('studio states: phone, first visit', (t) => states(t, const Size(390, 844), 'phone_first', seen: false));
  testWidgets('studio states: small phone, first visit',
      (t) => states(t, const Size(320, 568), 'small_first', seen: false));
  testWidgets('studio states: phone', (t) => states(t, const Size(390, 844), 'phone', seen: true));
  testWidgets('studio states: desktop', (t) => states(t, const Size(1440, 900), 'desktop', seen: true));
  testWidgets('studio states: desktop, first visit',
      (t) => states(t, const Size(1440, 900), 'desktop_first', seen: false));
  // Every other skin, with an intent: the default is covered above.
  for (final skin in const ['techOccult', 'darkAcademia', 'cosmic', 'surrealist', 'alchemical', 'wiccan', 'chaos']) {
    testWidgets('studio states: phone, $skin',
        (t) => states(t, const Size(390, 844), 'skin_$skin', seen: true, skin: skin));
  }
}
