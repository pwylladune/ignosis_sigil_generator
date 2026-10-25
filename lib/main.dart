import 'package:flutter/material.dart';
import 'src/services/iap_service.dart';
import 'src/ui/screens/sigil_studio_screen.dart';
import 'src/ui/theme/ignosis_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IapService.instance.initialize();
  runApp(const IgnosisApp());
}

class IgnosisApp extends StatelessWidget {
  const IgnosisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IGNOSIS - Chaos Sigil Studio',
      debugShowCheckedModeBanner: false,
      theme: IgnosisTheme.lightTheme,
      home: const SigilStudioScreen(),
    );
  }
}
