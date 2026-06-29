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
      version: 1,
      onCreate: _createDB,
    );
  }

  // إنشاء الجداول
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
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

  // إغلاق قاعدة البيانات
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
