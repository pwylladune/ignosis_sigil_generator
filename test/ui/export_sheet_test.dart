import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';
import 'package:ignosis_sigil_generator/src/services/universal_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => UniversalExportService.canDownload = false);

  test('the seal is saved as a PNG named by prefix and time', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1793078224020);
    expect(UniversalExportService.pngFilename('ignosis_sigil', at), 'ignosis_sigil_1793078224020.png');
  });

  testWidgets('in a browser the export sheet offers a download, then share and print', (tester) async {
    SharedPreferences.setMockInitialValues({});
    UniversalExportService.canDownload = true;
    await tester.pumpWidget(const IgnosisApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share or print the seal'));
    await tester.pumpAndSettle();
    expect(find.text('Download seal (PNG)'), findsOneWidget);
    expect(find.text('Share seal (PNG)'), findsOneWidget);
    expect(find.text('Print burn sheet'), findsOneWidget);
  });

  testWidgets('in the apps the share sheet saves the seal, so there is no download entry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    UniversalExportService.canDownload = false;
    await tester.pumpWidget(const IgnosisApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share or print the seal'));
    await tester.pumpAndSettle();
    expect(find.text('Download seal (PNG)'), findsNothing);
    expect(find.text('Share seal (PNG)'), findsOneWidget);
  });
}
