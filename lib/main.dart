import 'dart:async';
import 'package:flutter/material.dart';
import 'src/services/iap_service.dart';
import 'src/ui/screens/sigil_studio_screen.dart';
import 'src/ui/theme/ignosis_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to the store in the background: a slow StoreKit / Play response
  // must never hold the first frame. Entitlements update when it completes.
  unawaited(IapService.instance.initialize());
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
