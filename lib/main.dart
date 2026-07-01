import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

/// مفتاح تنقّل عام — تحتاجه خدمة الإشعارات لفتح جلسة اختبار عند النقر
/// على إشعار التذكير من خارج شجرة الواجهات.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VocabVaultApp());
}

class VocabVaultApp extends StatelessWidget {
  const VocabVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocabVault',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
