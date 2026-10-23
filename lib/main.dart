import 'package:flutter/material.dart';
import 'src/ui/screens/sigil_studio_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IgnosisApp());
}

class IgnosisApp extends StatelessWidget {
  const IgnosisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IGNOSIS - Chaos Magic Sigil Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070709),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amberAccent,
          secondary: Colors.deepOrangeAccent,
          surface: Color(0xFF0F0F16),
        ),
      ),
      home: const SigilStudioScreen(),
    );
  }
}
