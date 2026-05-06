import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'services/theme_controller.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try to initialize Firebase, if it fails, falls back gracefully to offline Demo Mode
  await FirebaseService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Yemek Sipariş Uygulaması',
          debugShowCheckedModeBanner: false,
          theme: themeController.activeTheme,
          home: const LoginScreen(),
        );
      },
    );
  }
}
