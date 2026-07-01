/// أنواع الأسئلة العشرة التي يدعمها نظام الاختبار المحلي.
///
/// كل نوع يُختبر من زاوية مختلفة لتعلّم الكلمة (لا يقتصر على الترجمة).
enum QuestionType {
  imageToWord, // صورة → كلمة
  audioToWord, // صوت → كلمة
  wordToArabic, // كلمة → ترجمة عربية
  arabicToWord, // ترجمة عربية → كلمة
  definitionToWord, // تعريف إنجليزي → كلمة
  wordToDefinition, // كلمة → تعريف إنجليزي
  clozeSentence, // جملة ناقصة (cloze)
  synonym, // مرادف
  antonym, // ضد
  wordFamily, // عائلة الكلمة (تصريفات: go / went / gone / going)
}
