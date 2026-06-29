import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // الحصول على قاعدة البيانات (إنشاؤها إذا لم تكن موجودة)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vocab_vault.db');
    return _database!;
  }

  // تهيئة قاعدة البيانات
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // تحديث الإصدار للمرحلة الثانية
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // إنشاء الجداول (للتثبيت الجديد)
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        definition TEXT,
        example TEXT,
        phonetic TEXT,
        audioUrl TEXT,
        partOfSpeech TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // ترقية قاعدة البيانات (للمستخدمين الذين لديهم النسخة القديمة)
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE words ADD COLUMN definition TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN example TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN phonetic TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN audioUrl TEXT');
      await db.execute('ALTER TABLE words ADD COLUMN partOfSpeech TEXT');
    }
  }

  // إضافة كلمة جديدة
  Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('words', word.toMap());
  }

  // جلب جميع الكلمات
  Future<List<Word>> getAllWords() async {
    final db = await database;
    final result = await db.query('words', orderBy: 'createdAt DESC');
    return result.map((map) => Word.fromMap(map)).toList();
  }

  // جلب كلمة واحدة بالـ ID
  Future<Word?> getWordById(int id) async {
    final db = await database;
    final result = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Word.fromMap(result.first);
  }

  // حذف كلمة
  Future<int> deleteWord(int id) async {
    final db = await database;
    return await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  // تحديث كلمة
  Future<int> updateWord(Word word) async {
    final db = await database;
    return await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  // البحث عن كلمة
  Future<List<Word>> searchWords(String query) async {
    final db = await database;
    final result = await db.query(
      'words',
      where: 'word LIKE ? OR translation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return result.map((map) => Word.fromMap(map)).toList();
  }

  // عدد الكلمات
  Future<int> getWordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    return result.first['count'] as int;
  }

  // التحقق من وجود كلمة مسبقاً
  Future<bool> wordExists(String word) async {
    final db = await database;
    final result = await db.query(
      'words',
      where: 'LOWER(word) = ?',
      whereArgs: [word.toLowerCase()],
    );
    return result.isNotEmpty;
  }

  // إغلاق قاعدة البيانات
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
