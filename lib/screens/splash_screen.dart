import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// شاشة البداية بهوية Mofradati (مطابقة لتصميم Stitch المعتمد):
/// خلفية Canvas فاتحة، أيقونة التطبيق داخل بطاقة بيضاء بظل ناعم، اسم
/// التطبيق بالأخضر الأساسي مع شعار KNOWLEDGE SEEKER، شريط تقدم بأخضر
/// النمو، وأسفل الشاشة اعتمادات المطوّر والمؤسسة.
///
/// أثناء عرضها تُهيَّأ خدمة الإشعارات ويُجدول تذكير المراجعة اليومي، ثم
/// تنتقل للشاشة الرئيسية. لو أُقلع التطبيق بالنقر على إشعار المراجعة،
/// تُفتح جلسة اختبار مباشرة بعد الانتقال.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(milliseconds: 2600);

  // دخول المجموعة المركزية: تكبير + ظهور (scaleUp في التصميم)
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  // ظهور التذييل متأخراً قليلاً (fadeIn بتأخير 0.5s في التصميم)
  late final AnimationController _footerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  // شريط التقدم يمتلئ على مدة عرض السبلاش
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: _minSplashDuration,
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _footerController.forward();
    });
    _boot();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _footerController.dispose();
    _progressController.dispose();
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
    final entry = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // هالتان لونيتان شفافتان في الزوايا (العنصر الجوي في التصميم)
          Positioned(
            top: -120,
            right: -120,
            child: _AtmosphereBlob(color: AppColors.primary.withOpacity(0.05)),
          ),
          Positioned(
            bottom: -110,
            left: -110,
            child: _AtmosphereBlob(
              color: AppColors.secondary.withOpacity(0.05),
              size: 350,
            ),
          ),
          // المحتوى الرئيسي: يملأ الشاشة بالكامل (Positioned.fill يجبر
          // الـ Column على أخذ عرض/ارتفاع الشاشة كاملَين، بدل التقلّص
          // لعرض أوسع عنصر بداخله فقط وهو ما كان يترك نصف الشاشة فارغاً).
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(flex: 3),
                // المجموعة المركزية: الأيقونة + الاسم + الشعار
                ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(entry),
                  child: FadeTransition(
                    opacity: _entryController,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.focusBlue.withOpacity(0.12),
                                blurRadius: 40,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 128,
                              height: 128,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Mofradati',
                          style: TextStyle(
                            fontFamily: AppTheme.headlineFont,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'KNOWLEDGE SEEKER',
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                // شريط التقدم (أخضر النمو على مسار رمادي فاتح)
                SizedBox(
                  width: 128,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _progressController.value,
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.growthGreen,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                // التذييل: اعتمادات المطوّر والمؤسسة
                FadeTransition(
                  opacity: _footerController,
                  child: Column(
                    children: [
                      Image.asset('assets/images/vp_logo.png', height: 36),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          text: 'Created by ',
                          style: const TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: 'Lemmouchi Nacereddine',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'VP Developer',
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 12,
                              color: AppColors.outline,
                            ),
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.outlineVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Text(
                            'Group VP Developer',
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 12,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'www.vpdeveloper.dz',
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12,
                          color: AppColors.secondary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// هالة لونية دائرية ضبابية تُستخدم كعنصر جوي خلف المحتوى.
class _AtmosphereBlob extends StatelessWidget {
  const _AtmosphereBlob({required this.color, this.size = 400});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}
