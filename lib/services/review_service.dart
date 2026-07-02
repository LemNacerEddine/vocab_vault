import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// طلب تقييم ٥ نجوم عبر النوافذ الأصلية للمتجرين (Google Play In-App Review
/// وApple SKStoreReviewController) — مثل التطبيقات الكبيرة.
///
/// قواعد مهمة يفرضها المتجران:
/// - النافذة تظهر فقط عندما يكون التطبيق منشوراً على المتجر (أو على مسار
///   اختبار داخلي في Play / TestFlight في iOS). أثناء `flutter run` المحلي
///   يُتجاهل الطلب بصمت — هذا سلوك طبيعي.
/// - النظام هو من يقرر الإظهار فعلاً (Apple ~3 مرات في السنة كحد أقصى)،
///   لذا نطلب في "لحظة رضا" فقط وبقيود تكرار صارمة أدناه.
class ReviewService {
  ReviewService._();

  /// نطلب فقط بعد جلسة اختبار ناجحة بهذه النسبة فأكثر.
  static const int minScorePercent = 80;

  /// لا طلب قبل الجلسة الناجحة رقم 3 (المستخدم جرّب التطبيق فعلاً).
  static const int minSuccessfulSessions = 3;

  /// حد أقصى إجمالي لعدد الطلبات، ومهلة تهدئة بين الطلب والذي يليه.
  static const int maxPrompts = 3;
  static const Duration cooldown = Duration(days: 30);

  /// معرّف التطبيق في App Store — يُملأ بعد النشر على متجر Apple
  /// (يظهر في App Store Connect). فارغ = يعمل زر المتجر على Android فقط.
  static const String appStoreId = '';

  static const String _keySuccessCount = 'review_success_sessions';
  static const String _keyPromptCount = 'review_prompt_count';
  static const String _keyLastPromptMs = 'review_last_prompt_ms';

  /// تُستدعى بعد انتهاء جلسة اختبار بنتيجتها المئوية. تعرض نافذة التقييم
  /// الأصلية إن اجتمعت الشروط، وإلا لا تفعل شيئاً. آمنة تماماً: أي فشل
  /// (منصة غير مدعومة، عدم توفر الخدمة...) يُبتلع بصمت.
  static Future<void> maybeRequestReview({required int scorePercent}) async {
    try {
      if (scorePercent < minScorePercent) return;

      final prefs = await SharedPreferences.getInstance();

      final successes = (prefs.getInt(_keySuccessCount) ?? 0) + 1;
      await prefs.setInt(_keySuccessCount, successes);
      if (successes < minSuccessfulSessions) return;

      final prompts = prefs.getInt(_keyPromptCount) ?? 0;
      if (prompts >= maxPrompts) return;

      final lastMs = prefs.getInt(_keyLastPromptMs) ?? 0;
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (lastMs != 0 && elapsedMs < cooldown.inMilliseconds) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await review.requestReview();

      await prefs.setInt(_keyPromptCount, prompts + 1);
      await prefs.setInt(
        _keyLastPromptMs,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // لا نزعج المستخدم أبداً بسبب فشل طلب تقييم.
    }
  }

  /// فتح صفحة التطبيق في المتجر مباشرة (لزر "قيّمنا على المتجر ⭐" مستقبلاً).
  /// يعمل دائماً حتى عندما يرفض النظام إظهار نافذة النجوم التلقائية.
  static Future<void> openStoreListing() async {
    try {
      await InAppReview.instance.openStoreListing(
        appStoreId: appStoreId.isEmpty ? null : appStoreId,
      );
    } catch (_) {
      // صامت — كما أعلاه.
    }
  }
}
