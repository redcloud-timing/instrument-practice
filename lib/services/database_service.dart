import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/practice_log.dart';
import '../utils/app_constants.dart';

/// 数据库服务
///
/// 封装 SQLite 数据库操作，提供练习日志和应用设置的持久化。
/// 使用 sqflite 插件，数据库文件名为 [AppConstants.databaseName]。
class DatabaseService {
  Database? _database;

  Future<void> init() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, AppConstants.databaseName);

    _database = await openDatabase(
      databasePath,
      version: AppConstants.databaseVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCategoryTables(db);
        }
        if (oldVersion < 3) {
          await _addCategorySortOrder(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
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

    await _createCategoryTables(db);
  }

  Future<void> _createCategoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE category_items (
        category_id INTEGER NOT NULL,
        item_uri TEXT NOT NULL,
        PRIMARY KEY (category_id, item_uri),
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _addCategorySortOrder(Database db) async {
    await db.execute(
      'ALTER TABLE categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
    );
    // 为已有栏目设置 sort_order（按 created_at 降序，新创建的在前）
    final rows = await db.query('categories', orderBy: 'created_at DESC');
    for (int i = 0; i < rows.length; i++) {
      await db.update(
        'categories',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
    }
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

  // ==================== 栏目管理 ====================

  /// 获取所有栏目
  Future<List<LibraryCategory>> getAllCategories() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'sort_order ASC');
    return rows.map(LibraryCategory.fromMap).toList();
  }

  /// 根据 ID 获取栏目
  Future<LibraryCategory?> getCategoryById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return LibraryCategory.fromMap(rows.first);
  }

  /// 创建栏目（排在最前面）
  Future<LibraryCategory> createCategory(String name) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    // 将所有现有栏目的 sort_order +1
    await db.rawUpdate('UPDATE categories SET sort_order = sort_order + 1');
    final id = await db.insert('categories', {
      'name': name,
      'sort_order': 0,
      'created_at': now,
    });
    return LibraryCategory(id: id, name: name, sortOrder: 0, createdAtIso: now);
  }

  /// 更新栏目名称
  Future<void> updateCategory(int id, String name) async {
    final db = await _db;
    await db.update(
      'categories',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 交换两个栏目的 sort_order
  Future<void> swapCategorySortOrder(
    int id1,
    int order1,
    int id2,
    int order2,
  ) async {
    final db = await _db;
    await db.update(
      'categories',
      {'sort_order': order2},
      where: 'id = ?',
      whereArgs: [id1],
    );
    await db.update(
      'categories',
      {'sort_order': order1},
      where: 'id = ?',
      whereArgs: [id2],
    );
  }

  /// 更新单个栏目的 sort_order
  Future<void> updateCategorySortOrder(int id, int sortOrder) async {
    final db = await _db;
    await db.update(
      'categories',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除栏目
  Future<void> deleteCategory(int id) async {
    final db = await _db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// 获取指定栏目的乐谱 URI 列表
  Future<List<String>> getCategoryItemUris(int categoryId) async {
    final db = await _db;
    final rows = await db.query(
      'category_items',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    return rows.map((row) => row['item_uri'] as String).toList();
  }

  /// 获取指定乐谱所属的栏目 ID 列表
  Future<List<int>> getCategoryIdsForItem(String itemUri) async {
    final db = await _db;
    final rows = await db.query(
      'category_items',
      where: 'item_uri = ?',
      whereArgs: [itemUri],
    );
    return rows.map((row) => row['category_id'] as int).toList();
  }

  /// 将乐谱添加到栏目
  Future<void> addItemToCategory(int categoryId, String itemUri) async {
    final db = await _db;
    await db.insert('category_items', {
      'category_id': categoryId,
      'item_uri': itemUri,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 将乐谱从栏目移除
  Future<void> removeItemFromCategory(int categoryId, String itemUri) async {
    final db = await _db;
    await db.delete(
      'category_items',
      where: 'category_id = ? AND item_uri = ?',
      whereArgs: [categoryId, itemUri],
    );
  }

  /// 将乐谱从所有栏目移除
  Future<void> removeItemFromAllCategories(String itemUri) async {
    final db = await _db;
    await db.delete(
      'category_items',
      where: 'item_uri = ?',
      whereArgs: [itemUri],
    );
  }
}
