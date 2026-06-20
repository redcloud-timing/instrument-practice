import 'package:flute_practice/models/category.dart';
import 'package:flute_practice/models/practice_log.dart';
import 'package:flute_practice/services/database_service.dart';

class MockDatabaseService implements DatabaseService {
  final Map<String, String> _settings = {};
  final Map<String, PracticeLog> _logs = {};
  final Map<int, LibraryCategory> _categories = {};
  final Map<int, List<String>> _categoryItems = {};
  int _nextCategoryId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<List<PracticeLog>> getAllLogs() async {
    return _logs.values.toList()
      ..sort((a, b) => b.practiceDate.compareTo(a.practiceDate));
  }

  @override
  Future<PracticeLog?> getLogByDate(String practiceDate) async {
    return _logs[practiceDate];
  }

  @override
  Future<void> upsertLog({
    required String practiceDate,
    required int durationSeconds,
    required String note,
  }) async {
    final now = DateTime.now().toIso8601String();
    _logs[practiceDate] = PracticeLog(
      id: _logs.length + 1,
      practiceDate: practiceDate,
      durationSeconds: durationSeconds,
      note: note,
      createdAt: _logs[practiceDate]?.createdAt ?? now,
      updatedAt: now,
    );
  }

  @override
  Future<void> addDurationToDate({
    required String practiceDate,
    required int addedSeconds,
  }) async {
    final existing = _logs[practiceDate];
    if (existing == null) {
      await upsertLog(
        practiceDate: practiceDate,
        durationSeconds: addedSeconds,
        note: '',
      );
      return;
    }

    await upsertLog(
      practiceDate: practiceDate,
      durationSeconds: existing.durationSeconds + addedSeconds,
      note: existing.note,
    );
  }

  @override
  Future<String?> getSetting(String key) async {
    return _settings[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _settings.remove(key);
  }

  // ==================== 栏目管理 ====================

  @override
  Future<List<LibraryCategory>> getAllCategories() async {
    return _categories.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<LibraryCategory?> getCategoryById(int id) async {
    return _categories[id];
  }

  @override
  Future<LibraryCategory> createCategory(String name) async {
    final id = _nextCategoryId++;
    final now = DateTime.now().toIso8601String();
    // 将所有现有栏目的 sort_order +1
    for (final key in _categories.keys) {
      _categories[key] = _categories[key]!.copyWith(
        sortOrder: _categories[key]!.sortOrder + 1,
      );
    }
    final category = LibraryCategory(
      id: id,
      name: name,
      sortOrder: 0,
      createdAtIso: now,
    );
    _categories[id] = category;
    return category;
  }

  @override
  Future<void> updateCategory(int id, String name) async {
    final category = _categories[id];
    if (category != null) {
      _categories[id] = category.copyWith(name: name);
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    _categories.remove(id);
    _categoryItems.remove(id);
  }

  @override
  Future<void> swapCategorySortOrder(
    int id1,
    int order1,
    int id2,
    int order2,
  ) async {
    final cat1 = _categories[id1];
    final cat2 = _categories[id2];
    if (cat1 != null) _categories[id1] = cat1.copyWith(sortOrder: order2);
    if (cat2 != null) _categories[id2] = cat2.copyWith(sortOrder: order1);
  }

  @override
  Future<void> updateCategorySortOrder(int id, int sortOrder) async {
    final cat = _categories[id];
    if (cat != null) {
      _categories[id] = cat.copyWith(sortOrder: sortOrder);
    }
  }

  @override
  Future<List<String>> getCategoryItemUris(int categoryId) async {
    return _categoryItems[categoryId] ?? [];
  }

  @override
  Future<List<int>> getCategoryIdsForItem(String itemUri) async {
    final result = <int>[];
    for (final entry in _categoryItems.entries) {
      if (entry.value.contains(itemUri)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  @override
  Future<void> addItemToCategory(int categoryId, String itemUri) async {
    _categoryItems.putIfAbsent(categoryId, () => []);
    if (!_categoryItems[categoryId]!.contains(itemUri)) {
      _categoryItems[categoryId]!.add(itemUri);
    }
  }

  @override
  Future<void> removeItemFromCategory(int categoryId, String itemUri) async {
    _categoryItems[categoryId]?.remove(itemUri);
  }

  @override
  Future<void> removeItemFromAllCategories(String itemUri) async {
    for (final key in _categoryItems.keys) {
      _categoryItems[key]?.remove(itemUri);
    }
  }
}
