import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'core/presentation/splash_screen.dart';
import 'features/main_layout/presentation/pages/main_layout_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Preserve native splash screen while initializing app
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);
  
  await di.init();
  
  // Remove native splash screen after initialization
  FlutterNativeSplash.remove();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LANKA AI SUPER POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _showSplash
          ? SplashScreen(
              onComplete: () {
                setState(() => _showSplash = false);
              },
            )
          : const MainLayoutPage(),
      builder: (context, child) {
        // Global min constraints wrapper
        return ConstrainedBox(
          constraints: const BoxConstraints(
              // your POS minimum width
            minHeight: 500,   // your POS minimum height
          ),
          child: child!,
        );
      },
    );
  }
}