import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'services/firebase_service.dart';
import 'services/theme_controller.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Run the background check
    await FirebaseService.checkBackgroundNotifications();
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase, if it fails, falls back gracefully to offline Demo Mode
  await FirebaseService.initialize();

  // Initialize background system notifications
  await NotificationService.init();

  // Initialize Workmanager for background execution (when app is closed/terminated)
  await Workmanager().initialize(callbackDispatcher);

  // Clear any previous infinite/broken scheduled workers from the device database
  try {
    await Workmanager().cancelAll();
  } catch (e) {
    debugPrint('Failed to cancel old workmanager tasks: $e');
  }

  // Register a periodic task for support checks (runs every 15 mins - Android battery-safe standard)
  await Workmanager()
      .registerPeriodicTask(
        "support_check_task",
        "supportBackgroundCheck",
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      )
      .catchError((e) => debugPrint('Workmanager register error: $e'));

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
          navigatorKey: NotificationService.navigatorKey,
          title: 'Yemek Sipariş Uygulaması',
          debugShowCheckedModeBanner: false,
          theme: themeController.activeTheme,
          home: const LoginScreen(),
        );
      },
    );
  }
}
