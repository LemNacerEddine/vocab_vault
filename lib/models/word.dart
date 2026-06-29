class Word {
  final int? id;
  final String word;
  final String translation;
  final String? definition; // التعريف بالإنجليزية
  final String? example; // مثال على الكلمة
  final String? phonetic; // النطق الصوتي (IPA)
  final String? audioUrl; // رابط ملف النطق الصوتي
  final String? partOfSpeech; // نوع الكلمة (noun, verb, adjective)
  final String? imageUrl; // رابط صورة توضيحية من Unsplash
  final String? imageDescription; // وصف الصورة
  final DateTime createdAt;

  Word({
    this.id,
    required this.word,
    required this.translation,
    this.definition,
    this.example,
    this.phonetic,
    this.audioUrl,
    this.partOfSpeech,
    this.imageUrl,
    this.imageDescription,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // تحويل الكلمة إلى Map لحفظها في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'definition': definition,
      'example': example,
      'phonetic': phonetic,
      'audioUrl': audioUrl,
      'partOfSpeech': partOfSpeech,
      'imageUrl': imageUrl,
      'imageDescription': imageDescription,
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
      example: map['example'] as String?,
      phonetic: map['phonetic'] as String?,
      audioUrl: map['audioUrl'] as String?,
      partOfSpeech: map['partOfSpeech'] as String?,
      imageUrl: map['imageUrl'] as String?,
      imageDescription: map['imageDescription'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // نسخة معدلة من الكلمة
  Word copyWith({
    int? id,
    String? word,
    String? translation,
    String? definition,
    String? example,
    String? phonetic,
    String? audioUrl,
    String? partOfSpeech,
    String? imageUrl,
    String? imageDescription,
    DateTime? createdAt,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      phonetic: phonetic ?? this.phonetic,
      audioUrl: audioUrl ?? this.audioUrl,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      imageUrl: imageUrl ?? this.imageUrl,
      imageDescription: imageDescription ?? this.imageDescription,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
