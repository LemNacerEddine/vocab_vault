import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// مفتاح تنقّل عام — تحتاجه خدمة الإشعارات لفتح جلسة اختبار عند النقر
/// على إشعار التذكير من خارج شجرة الواجهات.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MofradatiApp());
}

class MofradatiApp extends StatelessWidget {
  const MofradatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mofradati',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
