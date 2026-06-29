class Word {
  final int? id;
  final String word;
  final String translation;
  final DateTime createdAt;

  Word({
    this.id,
    required this.word,
    required this.translation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // تحويل الكلمة إلى Map لحفظها في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // إنشاء كلمة من Map (من قاعدة البيانات)
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String,
      translation: map['translation'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // نسخة معدلة من الكلمة
  Word copyWith({
    int? id,
    String? word,
    String? translation,
    DateTime? createdAt,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
