class Word {
  final int? id;
  final String word;
  final String translation;
  final String? definition; // التعريف الأول
  final String? allDefinitions; // جميع التعريفات (مفصولة بـ \n)
  final String? example; // أول مثال
  final String? allExamples; // جميع الأمثلة (مفصولة بـ \n)
  final String? phonetic; // النطق الصوتي (IPA)
  final String? audioUrl; // رابط ملف النطق الصوتي
  final String? partOfSpeech; // نوع الكلمة (noun, verb, adjective)
  final String? allPartsOfSpeech; // جميع أنواع الكلمة
  final String? synonyms; // المرادفات (مفصولة بفاصلة)
  final String? antonyms; // الأضداد (مفصولة بفاصلة)
  final String? imageUrl; // رابط صورة توضيحية من Unsplash
  final String? imageDescription; // وصف الصورة
  final String? allImageUrls; // جميع روابط الصور (مفصولة بـ |)
  final DateTime createdAt;

  Word({
    this.id,
    required this.word,
    required this.translation,
    this.definition,
    this.allDefinitions,
    this.example,
    this.allExamples,
    this.phonetic,
    this.audioUrl,
    this.partOfSpeech,
    this.allPartsOfSpeech,
    this.synonyms,
    this.antonyms,
    this.imageUrl,
    this.imageDescription,
    this.allImageUrls,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // تحويل المرادفات من نص إلى قائمة
  List<String> get synonymsList =>
      synonyms?.split(',').where((s) => s.trim().isNotEmpty).toList() ?? [];

  // تحويل الأضداد من نص إلى قائمة
  List<String> get antonymsList =>
      antonyms?.split(',').where((s) => s.trim().isNotEmpty).toList() ?? [];

  // تحويل جميع الأمثلة من نص إلى قائمة
  List<String> get examplesList =>
      allExamples?.split('\n').where((s) => s.trim().isNotEmpty).toList() ?? [];

  // تحويل جميع التعريفات من نص إلى قائمة
  List<String> get definitionsList =>
      allDefinitions?.split('\n').where((s) => s.trim().isNotEmpty).toList() ??
      [];

  // تحويل جميع روابط الصور من نص إلى قائمة
  List<String> get imageUrlsList =>
      allImageUrls?.split('|').where((s) => s.trim().isNotEmpty).toList() ?? [];

  // تحويل الكلمة إلى Map لحفظها في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'definition': definition,
      'allDefinitions': allDefinitions,
      'example': example,
      'allExamples': allExamples,
      'phonetic': phonetic,
      'audioUrl': audioUrl,
      'partOfSpeech': partOfSpeech,
      'allPartsOfSpeech': allPartsOfSpeech,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'imageUrl': imageUrl,
      'imageDescription': imageDescription,
      'allImageUrls': allImageUrls,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // إنشاء كلمة من Map (من قاعدة البيانات)
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String,
      translation: map['translation'] as String,
      definition: map['definition'] as String?,
      allDefinitions: map['allDefinitions'] as String?,
      example: map['example'] as String?,
      allExamples: map['allExamples'] as String?,
      phonetic: map['phonetic'] as String?,
      audioUrl: map['audioUrl'] as String?,
      partOfSpeech: map['partOfSpeech'] as String?,
      allPartsOfSpeech: map['allPartsOfSpeech'] as String?,
      synonyms: map['synonyms'] as String?,
      antonyms: map['antonyms'] as String?,
      imageUrl: map['imageUrl'] as String?,
      imageDescription: map['imageDescription'] as String?,
      allImageUrls: map['allImageUrls'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // نسخة معدلة من الكلمة
  Word copyWith({
    int? id,
    String? word,
    String? translation,
    String? definition,
    String? allDefinitions,
    String? example,
    String? allExamples,
    String? phonetic,
    String? audioUrl,
    String? partOfSpeech,
    String? allPartsOfSpeech,
    String? synonyms,
    String? antonyms,
    String? imageUrl,
    String? imageDescription,
    String? allImageUrls,
    DateTime? createdAt,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      definition: definition ?? this.definition,
      allDefinitions: allDefinitions ?? this.allDefinitions,
      example: example ?? this.example,
      allExamples: allExamples ?? this.allExamples,
      phonetic: phonetic ?? this.phonetic,
      audioUrl: audioUrl ?? this.audioUrl,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      allPartsOfSpeech: allPartsOfSpeech ?? this.allPartsOfSpeech,
      synonyms: synonyms ?? this.synonyms,
      antonyms: antonyms ?? this.antonyms,
      imageUrl: imageUrl ?? this.imageUrl,
      imageDescription: imageDescription ?? this.imageDescription,
      allImageUrls: allImageUrls ?? this.allImageUrls,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
