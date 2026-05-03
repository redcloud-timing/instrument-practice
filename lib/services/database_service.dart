import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/practice_log.dart';

class DatabaseService {
  Database? _database;

  Future<void> init() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, 'flute_practice.db');

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE practice_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            practice_date TEXT NOT NULL UNIQUE,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            note TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_practice_logs_date
          ON practice_logs(practice_date)
        ''');

        await db.execute('''
          CREATE TABLE app_settings (
            setting_key TEXT PRIMARY KEY,
            setting_value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<Database> get _db async {
    await init();
    return _database!;
  }

  Future<List<PracticeLog>> getAllLogs() async {
    final db = await _db;
    final rows = await db.query('practice_logs', orderBy: 'practice_date DESC');
    return rows.map(PracticeLog.fromMap).toList();
  }

  Future<PracticeLog?> getLogByDate(String practiceDate) async {
    final db = await _db;
    final rows = await db.query(
      'practice_logs',
      where: 'practice_date = ?',
      whereArgs: [practiceDate],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return PracticeLog.fromMap(rows.first);
  }

  Future<void> upsertLog({
    required String practiceDate,
    required int durationSeconds,
    required String note,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final existing = await getLogByDate(practiceDate);

    if (existing == null) {
      await db.insert('practice_logs', {
        'practice_date': practiceDate,
        'duration_seconds': durationSeconds,
        'note': note,
        'created_at': now,
        'updated_at': now,
      });
      return;
    }

    await db.update(
      'practice_logs',
      {'duration_seconds': durationSeconds, 'note': note, 'updated_at': now},
      where: 'practice_date = ?',
      whereArgs: [practiceDate],
    );
  }

  Future<void> addDurationToDate({
    required String practiceDate,
    required int addedSeconds,
  }) async {
    final existing = await getLogByDate(practiceDate);

    await upsertLog(
      practiceDate: practiceDate,
      durationSeconds: (existing?.durationSeconds ?? 0) + addedSeconds,
      note: existing?.note ?? '',
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['setting_value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert('app_settings', {
      'setting_key': key,
      'setting_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSetting(String key) async {
    final db = await _db;
    await db.delete('app_settings', where: 'setting_key = ?', whereArgs: [key]);
  }
}
