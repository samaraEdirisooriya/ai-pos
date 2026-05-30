import 'package:flutter/material.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/main_layout/presentation/pages/main_layout_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LANKA AI SUPER POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainLayoutPage(),
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