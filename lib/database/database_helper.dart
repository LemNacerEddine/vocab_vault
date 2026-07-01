import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';
import '../models/word_progress.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vocab_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        definition TEXT,
        allDefinitions TEXT,
        example TEXT,
        allExamples TEXT,
        phonetic TEXT,
        audioUrl TEXT,
        partOfSpeech TEXT,
        allPartsOfSpeech TEXT,
        synonyms TEXT,
        antonyms TEXT,
        rootWord TEXT,
        formTypeLabel TEXT,
        inputFormExamples TEXT,
        imageUrl TEXT,
        imageDescription TEXT,
        allImageUrls TEXT,
        quizContent TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    await _createProgressTableV8(db);
  }

  /// جدول تقدّم التعلّم بنظام "مستوى الإتقان" (masteryLevel 0-5)، ويتتبّع
  /// أيضاً عدد الأخطاء/الإجابات الصحيحة لكل نوع سؤال (JSON) لدعم المراجعة
  /// الذكية حسب نقاط الضعف.
  Future<void> _createProgressTableV8(Database db) async {
    await db.execute('''
      CREATE TABLE word_progress (
        wordId INTEGER PRIMARY KEY,
        correctCount INTEGER DEFAULT 0,
        wrongCount INTEGER DEFAULT 0,
        lastReviewedAt TEXT,
        nextReviewAt TEXT,
        masteryLevel INTEGER DEFAULT 0,
        wrongByType TEXT,
        correctByType TEXT,
        FOREIGN KEY (wordId) REFERENCES words(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE words ADD COLUMN definition TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN example TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN phonetic TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN audioUrl TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN partOfSpeech TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE words ADD COLUMN imageUrl TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN imageDescription TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE words ADD COLUMN allDefinitions TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN allExamples TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN allPartsOfSpeech TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN synonyms TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN antonyms TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE words ADD COLUMN allImageUrls TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE words ADD COLUMN rootWord TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN formTypeLabel TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN inputFormExamples TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE words ADD COLUMN quizContent TEXT');
    }
    if (oldVersion < 8) {
      // (v7 أنشأ جدول word_progress بمخطط SM-2 قديم؛ استُبدل هنا بنظام
      // "مستوى الإتقان" الأبسط الذي يتتبّع أيضاً نوع الأسئلة الخاطئة/الصحيحة
      // لكل كلمة. المرحلة كانت لا تزال قيد التطوير المبكر، فلا بيانات
      // إنتاجية مهمة تستحق الحفظ عبر هذا التحوّل الهيكلي.)
      await db.execute('DROP TABLE IF EXISTS word_progress');
      await _createProgressTableV8(db);
    }
  }

  Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    final result = await db.query('words', orderBy: 'createdAt DESC');
    return result.map((map) => Word.fromMap(map)).toList();
  }

  Future<Word?> getWordById(int id) async {
    final db = await database;
    final result = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Word.fromMap(result.first);
  }

  Future<int> deleteWord(int id) async {
    final db = await database;
    return await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateWord(Word word) async {
    final db = await database;
    return await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<List<Word>> searchWords(String query) async {
    final db = await database;
    final result = await db.query(
      'words',
      where: 'word LIKE ? OR translation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return result.map((map) => Word.fromMap(map)).toList();
  }

  Future<int> getWordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    return result.first['count'] as int;
  }

  Future<bool> wordExists(String word) async {
    final db = await database;
    final result = await db.query(
      'words',
      where: 'LOWER(word) = ?',
      whereArgs: [word.toLowerCase()],
    );
    return result.isNotEmpty;
  }

  // ==================== تقدّم التعلّم (مستوى الإتقان) ====================

  /// سجل التقدّم لكلمة، أو null إن لم تُراجَع بعد.
  Future<WordProgress?> getProgress(String wordId) async {
    final db = await database;
    final result = await db.query(
      'word_progress',
      where: 'wordId = ?',
      whereArgs: [int.tryParse(wordId) ?? wordId],
    );
    if (result.isEmpty) return null;
    return WordProgress.fromMap(result.first);
  }

  /// إدراج أو تحديث سجل التقدّم.
  Future<void> upsertProgress(WordProgress progress) async {
    final db = await database;
    await db.insert(
      'word_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// سجلات تقدّم جميع الكلمات، مُفهرَسة بمعرّف الكلمة (نصاً) — تُستخدم في
  /// بناء جلسة المراجعة الذكية دفعة واحدة بدل استعلام لكل كلمة.
  Future<Map<String, WordProgress>> getAllProgressMap() async {
    final db = await database;
    final rows = await db.query('word_progress');
    final map = <String, WordProgress>{};
    for (final row in rows) {
      final wp = WordProgress.fromMap(row);
      map[wp.wordId] = wp;
    }
    return map;
  }

  /// جميع الكلمات المستحقّة للمراجعة الآن:
  /// كلمات بلا سجل تقدّم (جديدة) + كلمات حان موعد مراجعتها.
  /// مرتّبة: المستحقّة الأقدم أولاً، ثم الكلمات الجديدة.
  Future<List<Word>> getDueWords() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      LEFT JOIN word_progress p ON p.wordId = w.id
      WHERE p.wordId IS NULL
         OR p.nextReviewAt IS NULL
         OR p.nextReviewAt <= ?
      ORDER BY (p.nextReviewAt IS NULL) ASC, p.nextReviewAt ASC, w.createdAt ASC
      ''',
      [now],
    );
    return result.map((map) => Word.fromMap(map)).toList();
  }

  /// عدد الكلمات المستحقّة للمراجعة الآن (للعرض على الشاشة الرئيسية).
  Future<int> getDueCount() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM words w
      LEFT JOIN word_progress p ON p.wordId = w.id
      WHERE p.wordId IS NULL
         OR p.nextReviewAt IS NULL
         OR p.nextReviewAt <= ?
      ''',
      [now],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// "الكلمات الصعبة": كلمات لها أخطاء مسجَّلة، مرتّبة بالأسوأ دقّةً أولاً.
  /// تُستخدم في وضع "الكلمات الصعبة" (Weak Words) لمراجعة مركَّزة.
  Future<List<Word>> getWeakWords({int limit = 20}) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT w.* FROM words w
      INNER JOIN word_progress p ON p.wordId = w.id
      WHERE p.wrongCount > 0
      ORDER BY (CAST(p.wrongCount AS REAL) / (p.correctCount + p.wrongCount)) DESC,
               p.wrongCount DESC
      LIMIT ?
      ''',
      [limit],
    );
    return result.map((map) => Word.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
