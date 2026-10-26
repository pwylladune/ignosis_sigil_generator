// Renders the "Rise In Power" icon: the Cyber Chaos attractor of
// "Michael Roland" with two-fold symmetry, inside the Circumlocution walk of
// "Rise In Power", painted with the studio's sumi-e brush. The drawing itself
// is the app's own (paintIgnosisMark), so the icons and the title mark match.
//
//   flutter test brand/rise_in_power_icon_test.dart
//
// Writes brand/rise_in_power_icon.png (1024 px), brand/rise_in_power_icon_dark.png
// and the app-icon masters brand/app_icon_1024.png and brand/app_icon_safe_1024.png.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/src/ui/theme/sigil_skins.dart';
import 'package:ignosis_sigil_generator/src/ui/widgets/ignosis_mark.dart';

/// [content] shrinks the drawing inside the paper: 1 fills it; 0.78 keeps it in
/// the safe zone of Android launcher and PWA "maskable" masks.
Future<void> render(String file, SigilSkinTheme skin, {int pixels = 1024, double content = 1}) async {
  final recorder = ui.PictureRecorder();
  paintIgnosisMark(ui.Canvas(recorder), pixels.toDouble(), skin, paper: true, content: content);
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(file).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render the Rise In Power icon', (tester) async {
    await tester.runAsync(() async {
      await render('brand/rise_in_power_icon.png', SigilSkinTheme.getSkin(SigilSkinId.vellumDraft));
      await render('brand/rise_in_power_icon_dark.png', SigilSkinTheme.getSkin(SigilSkinId.chaos));
      // App-icon masters: full bleed (iOS, web), and the safe zone (Android, maskable).
      await render('brand/app_icon_1024.png', SigilSkinTheme.getSkin(SigilSkinId.vellumDraft));
      await render('brand/app_icon_safe_1024.png', SigilSkinTheme.getSkin(SigilSkinId.vellumDraft), content: 0.78);
    });
  });
}
