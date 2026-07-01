import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import 'home_screen.dart';

/// شاشة البداية: تعرض شعار المؤسسة VP DEVELOPER وهوية التطبيق، وأثناء
/// عرضها تُهيَّأ خدمة الإشعارات ويُجدول تذكير المراجعة اليومي، ثم تنتقل
/// للشاشة الرئيسية. لو أُقلع التطبيق بالنقر على إشعار المراجعة، تُفتح جلسة
/// اختبار مباشرة بعد الانتقال.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(milliseconds: 2500);

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final start = DateTime.now();

    // تهيئة الإشعارات وجدولة التذكير أثناء عرض السبلاش (لا وقت ضائع).
    await NotificationService.init();
    final fromReminder = await NotificationService.launchedFromReminder();
    await NotificationService.rescheduleWithFreshCount();

    // ضمان حد أدنى لمدة العرض كي لا تومض الشاشة وتختفي.
    final elapsed = DateTime.now().difference(start);
    final remaining = _minSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );

    // أُقلع التطبيق من إشعار المراجعة → افتح جلسة الاختبار فوق الرئيسية.
    if (fromReminder) {
      NotificationService.openDueReviewQuiz();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade400,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeIn,
          ),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // شعار المؤسسة داخل بطاقة بيضاء
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/vp_logo.png',
                  width: 190,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'VocabVault',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'تعلّم الكلمات بذكاء',
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(flex: 3),
              const CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2.5,
              ),
              const Spacer(flex: 2),
              // اسم المؤسسة أسفل الشاشة
              const Text(
                'VP DEVELOPER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تطوير: مؤسسة VP Developer',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
