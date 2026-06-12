import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sera_wellbeing.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE moods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        mood TEXT NOT NULL,
        score REAL NOT NULL
      )
    ''');

    // Pre-populate with some sample history for the previous 6 days
    final now = DateTime.now();
    final sampleMoods = [
      {'daysAgo': 6, 'mood': 'Sad', 'score': 0.35},
      {'daysAgo': 5, 'mood': 'Calm', 'score': 0.80},
      {'daysAgo': 4, 'mood': 'Anxious', 'score': 0.40},
      {'daysAgo': 3, 'mood': 'Happy', 'score': 0.95},
      {'daysAgo': 2, 'mood': 'Angry', 'score': 0.55},
      {'daysAgo': 1, 'mood': 'Calm', 'score': 0.80},
    ];

    for (var sample in sampleMoods) {
      final daysAgo = sample['daysAgo'] as int;
      final date = now.subtract(Duration(days: daysAgo));
      await db.insert('moods', {
        'timestamp': date.toIso8601String(),
        'mood': sample['mood'] as String,
        'score': sample['score'] as double,
      });
    }
  }

  Future<int> insertMood(String mood, double score) async {
    final db = await instance.database;
    return await db.insert('moods', {
      'timestamp': DateTime.now().toIso8601String(),
      'mood': mood,
      'score': score,
    });
  }

  Future<List<Map<String, dynamic>>> getLatestMoods(int limit) async {
    final db = await instance.database;
    // Get the latest check-ins, sorted DESC by timestamp to get newest
    final List<Map<String, dynamic>> maps = await db.query(
      'moods',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    // Reverse the list so it flows chronologically on the chart (oldest to newest)
    return maps.reversed.toList();
  }

  Future<Map<String, dynamic>?> getLatestSingleMood() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'moods',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> clearAllMoods() async {
    final db = await database;
    await db.delete('moods');
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('moods');

    final now = DateTime.now();
    final sampleMoods = [
      {'daysAgo': 6, 'mood': 'Sad', 'score': 0.35},
      {'daysAgo': 5, 'mood': 'Calm', 'score': 0.80},
      {'daysAgo': 4, 'mood': 'Anxious', 'score': 0.40},
      {'daysAgo': 3, 'mood': 'Happy', 'score': 0.95},
      {'daysAgo': 2, 'mood': 'Angry', 'score': 0.55},
      {'daysAgo': 1, 'mood': 'Calm', 'score': 0.80},
    ];

    for (var sample in sampleMoods) {
      final daysAgo = sample['daysAgo'] as int;
      final date = now.subtract(Duration(days: daysAgo));
      await db.insert('moods', {
        'timestamp': date.toIso8601String(),
        'mood': sample['mood'] as String,
        'score': sample['score'] as double,
      });
    }
  }
}
