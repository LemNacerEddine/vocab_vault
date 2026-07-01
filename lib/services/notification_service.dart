import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';
import '../main.dart';
import '../screens/quiz_screen.dart';
import 'review_session_builder.dart';

/// نظام التذكير المحلي: إشعار يومي يدعو المستخدم لاختبار صغير على الكلمات
/// المستحقّة للمراجعة. يعمل بالكامل على الجهاز (بدون خادم أو إنترنت):
/// - يُجدول إشعاراً متكرراً يومياً الساعة [reminderHour] بتوقيت الجهاز.
/// - نص الإشعار يتضمن عدد الكلمات المستحقّة لحظة الجدولة، ويُحدَّث بإعادة
///   الجدولة عند كل إقلاع وبعد كل جلسة اختبار.
/// - النقر على الإشعار يفتح جلسة اختبار مباشرة للكلمات المستحقّة.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// ساعة التذكير اليومي بتوقيت الجهاز (24 ساعة). غيّرها لتجربة سريعة.
  static const int reminderHour = 20;

  static const int _dailyReminderId = 1001;
  static const String _payloadDueReview = 'due_review';

  static bool _initialized = false;

  /// تهيئة البلجن والمناطق الزمنية وطلب الأذونات. تُستدعى مرة عند الإقلاع
  /// (من شاشة البداية). آمنة الاستدعاء المتكرر.
  static Future<void> init() async {
    if (_initialized) return;

    // قاعدة بيانات المناطق الزمنية + ضبط منطقة الجهاز (لازمة لـ zonedSchedule).
    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // إن تعذّر تحديد المنطقة تبقى UTC — الإشعار يعمل لكن بساعة مزاحة.
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payloadDueReview) {
          openDueReviewQuiz();
        }
      },
    );
    _initialized = true;

    // طلب الأذونات: Android 13+ يتطلب طلباً صريحاً، وكذلك iOS.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// هل أُقلع التطبيق أصلاً بالنقر على إشعار المراجعة؟ (يُفحص بعد السبلاش
  /// لفتح جلسة الاختبار مباشرة.)
  static Future<bool> launchedFromReminder() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload == _payloadDueReview;
  }

  /// (إعادة) جدولة التذكير اليومي بنص محدَّث يتضمن عدد الكلمات المستحقّة.
  /// تُستدعى عند كل إقلاع وبعد كل جلسة اختبار فيبقى العدد شبه دقيق.
  static Future<void> rescheduleWithFreshCount() async {
    if (!_initialized) return;

    final dueCount = await DatabaseHelper.instance.getDueCount();
    final body = dueCount > 0
        ? 'لديك $dueCount كلمة تنتظر المراجعة — اختبار صغير؟ 📚'
        : 'حان وقت مراجعة كلماتك! اختبار صغير يثبّت الحفظ 📚';

    await _plugin.cancel(_dailyReminderId);
    await _plugin.zonedSchedule(
      _dailyReminderId,
      'تذكير المراجعة اليومية',
      body,
      _nextInstanceOfHour(reminderHour),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_review',
          'تذكير المراجعة',
          channelDescription: 'إشعار يومي لمراجعة الكلمات المستحقّة',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // وضع غير دقيق: لا يحتاج إذن التنبيهات الدقيقة (SCHEDULE_EXACT_ALARM)
      // وفارق الدقائق غير مهم لتذكير مراجعة.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // التكرار يومياً في نفس الساعة.
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _payloadDueReview,
    );
  }

  /// أقرب موعد قادم للساعة المطلوبة بتوقيت الجهاز.
  static tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// إشعار فوري للتجربة أثناء التطوير (لا ينتظر موعد التذكير اليومي).
  static Future<void> showTestNotification() async {
    if (!_initialized) return;
    final dueCount = await DatabaseHelper.instance.getDueCount();
    await _plugin.show(
      9999,
      'تذكير المراجعة (تجربة)',
      'لديك $dueCount كلمة تنتظر المراجعة — اختبار صغير؟ 📚',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_review',
          'تذكير المراجعة',
          channelDescription: 'إشعار يومي لمراجعة الكلمات المستحقّة',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _payloadDueReview,
    );
  }

  /// فتح جلسة اختبار للكلمات المستحقّة (يُستدعى عند النقر على الإشعار).
  /// إن لا كلمات مستحقّة أو لا أسئلة ممكنة، يبقى المستخدم على الشاشة الحالية.
  static Future<void> openDueReviewQuiz() async {
    final due = await DatabaseHelper.instance.getDueWords();
    if (due.isEmpty) return;
    final progress = await DatabaseHelper.instance.getAllProgressMap();
    final questions = ReviewSessionBuilder.buildSession(
      words: due,
      progress: progress,
    );
    if (questions.isEmpty) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => QuizScreen(questions: questions)),
    );
  }
}
