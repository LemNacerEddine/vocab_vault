import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';

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
      version: 6,
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
        createdAt TEXT NOT NULL
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

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
