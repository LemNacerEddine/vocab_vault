import 'package:flutter/material.dart';

import '../models/question_type.dart';

/// تسميات وأيقونات عربية لكل نوع سؤال — تُستخدم في واجهة الاختبار
/// وملخّص النتائج.
class QuestionTypeLabels {
  static String arabic(QuestionType type) {
    switch (type) {
      case QuestionType.imageToWord:
        return 'الصورة';
      case QuestionType.audioToWord:
        return 'النطق';
      case QuestionType.wordToArabic:
        return 'الترجمة (كلمة ← معنى)';
      case QuestionType.arabicToWord:
        return 'الترجمة (معنى ← كلمة)';
      case QuestionType.definitionToWord:
        return 'التعريف ← الكلمة';
      case QuestionType.wordToDefinition:
        return 'الكلمة ← التعريف';
      case QuestionType.clozeSentence:
        return 'الجملة الناقصة';
      case QuestionType.synonym:
        return 'المرادف';
      case QuestionType.antonym:
        return 'الضد';
      case QuestionType.wordFamily:
        return 'عائلة الكلمة';
    }
  }

  static IconData icon(QuestionType type) {
    switch (type) {
      case QuestionType.imageToWord:
        return Icons.image_outlined;
      case QuestionType.audioToWord:
        return Icons.volume_up_outlined;
      case QuestionType.wordToArabic:
      case QuestionType.arabicToWord:
        return Icons.translate;
      case QuestionType.definitionToWord:
      case QuestionType.wordToDefinition:
        return Icons.menu_book_outlined;
      case QuestionType.clozeSentence:
        return Icons.short_text;
      case QuestionType.synonym:
        return Icons.compare_arrows;
      case QuestionType.antonym:
        return Icons.swap_horiz;
      case QuestionType.wordFamily:
        return Icons.account_tree_outlined;
    }
  }
}
