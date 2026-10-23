import 'package:flutter_test/flutter_test.dart';
import 'package:ignosis_sigil_generator/main.dart';

void main() {
  testWidgets('IGNOSIS studio smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const IgnosisApp());
    expect(find.text('IGNOSIS'), findsOneWidget);
  });
}
