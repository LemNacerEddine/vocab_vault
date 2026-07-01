// اختبار دخان بسيط للتطبيق.
//
// ملاحظة: الشاشة الرئيسية تفتح قاعدة بيانات SQLite في initState، وهذا يتطلب
// إعداد sqflite_common_ffi لاختبارات الودجت الكاملة. لذا نكتفي هنا بالتأكد من
// أن جذر التطبيق قابل للإنشاء. منطق الأعمال (خوارزمية SM-2) مغطّى باختبارات
// وحدة في spaced_repetition_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocab_vault/main.dart';

void main() {
  test('جذر التطبيق قابل للإنشاء', () {
    const app = VocabVaultApp();
    expect(app, isA<Widget>());
  });
}
