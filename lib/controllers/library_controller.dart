import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../models/library_item.dart';
import '../services/database_service.dart';
import '../services/document_library_service.dart';
import '../utils/app_constants.dart';

/// 乐谱库控制器
///
/// 管理 PDF 乐谱和图片的导入、搜索和删除。
/// 通过 [DatabaseService] 持久化元数据，通过 [DocumentLibraryService] 访问原生文件能力。
///
/// 主要功能：
/// - 从设备导入 PDF/图片
/// - 搜索与过滤
/// - 笔记
/// - 栏目管理
/// - 容量限制（最大 60 条）
class LibraryController extends ChangeNotifier {
  LibraryController(this._databaseService, this._documentService);

  final DatabaseService _databaseService;
  final DocumentLibraryService _documentService;
  DocumentLibraryService get documentService => _documentService;

  bool isLoading = true;
  bool isBusy = false;
  List<LibraryItem> items = [];

  List<LibraryItem> get recentItems {
    final values = List<LibraryItem>.of(items);
    values.sort(_sortByOpenedAtDesc);
    return values;
  }

  LibraryItem? itemByUri(String uri) {
    for (final item in items) {
      if (item.uri == uri) return item;
    }
    return null;
  }

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    final raw = await _databaseService.getSetting(
      AppConstants.libraryDocumentsKey,
    );
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items = [
            for (final value in decoded)
              if (value is Map)
                LibraryItem.fromMap(Map<String, dynamic>.from(value)),
          ].where((item) => item.uri.isNotEmpty).toList();
        }
      } catch (e) {
        debugPrint('LibraryController.init decode error: $e');
        items = [];
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<List<LibraryItem>> addDocumentsFromDevice() async {
    if (isBusy) return [];

    isBusy = true;
    notifyListeners();

    try {
      final pickedList = await _documentService.pickDocuments();
      if (pickedList.isEmpty) return [];

      final now = DateTime.now().toIso8601String();
      final added = <LibraryItem>[];

      for (final picked in pickedList) {
        final existing = itemByUri(picked.uri);
        final next = picked.copyWith(
          addedAtIso: existing?.addedAtIso ?? now,
          openedAtIso: now,
          note: existing?.note ?? '',
        );

        items = [
          next,
          for (final item in items)
            if (item.uri != next.uri) item,
        ];
        added.add(next);
      }

      _trimItems();
      notifyListeners();
      await _save();

      return added;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> markOpened(LibraryItem item) async {
    if (isBusy) return;

    isBusy = true;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();
      items = [
        for (final current in items)
          if (current.uri == item.uri)
            current.copyWith(openedAtIso: now)
          else
            current,
      ];
      notifyListeners();
      await _save();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> saveNote(LibraryItem item, String note) async {
    items = [
      for (final current in items)
        if (current.uri == item.uri)
          current.copyWith(note: note.trim())
        else
          current,
    ];

    notifyListeners();
    await _save();
  }

  Future<void> renameItem(LibraryItem item, String title) async {
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) return;

    items = [
      for (final current in items)
        if (current.uri == item.uri)
          current.copyWith(title: nextTitle)
        else
          current,
    ];

    notifyListeners();
    await _save();
  }

  Future<void> deleteItem(LibraryItem item) async {
    items = [
      for (final current in items)
        if (current.uri != item.uri) current,
    ];

    // 同时删除该乐谱的所有栏目关联
    await _databaseService.removeItemFromAllCategories(item.uri);

    notifyListeners();
    await _save();
  }

  void _trimItems() {
    items.sort(_sortByOpenedAtDesc);
    if (items.length > AppConstants.maxLibraryItems) {
      items = items.take(AppConstants.maxLibraryItems).toList();
    }
  }

  Future<void> _save() async {
    await _databaseService.setSetting(
      AppConstants.libraryDocumentsKey,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }

  static int _sortByOpenedAtDesc(LibraryItem left, LibraryItem right) {
    final leftDate = DateTime.tryParse(left.openedAtIso) ?? DateTime(1970);
    final rightDate = DateTime.tryParse(right.openedAtIso) ?? DateTime(1970);
    return rightDate.compareTo(leftDate);
  }

  // ==================== 栏目管理 ====================

  List<LibraryCategory> _categories = [];
  List<LibraryCategory> get categories => _categories;

  /// 加载所有栏目（按 sort_order 排序）
  Future<void> loadCategories() async {
    _categories = await _databaseService.getAllCategories();
    notifyListeners();
  }

  /// 获取"全部"的 sort_order
  Future<int> getAllCategorySortOrder() async {
    final value = await _databaseService.getSetting(
      AppConstants.allCategorySortOrderKey,
    );
    return int.tryParse(value ?? '') ?? -1;
  }

  /// 设置"全部"的 sort_order
  Future<void> setAllCategorySortOrder(int order) async {
    await _databaseService.setSetting(
      AppConstants.allCategorySortOrderKey,
      order.toString(),
    );
  }

  /// 获取包含"全部"在内的排序后列表（用于标签栏显示）
  Future<List<CategoryDisplayItem>> getSortedCategoryDisplayItems() async {
    final allOrder = await getAllCategorySortOrder();
    final items = <CategoryDisplayItem>[
      CategoryDisplayItem(id: null, name: '全部', sortOrder: allOrder),
      for (final cat in _categories)
        CategoryDisplayItem(
          id: cat.id,
          name: cat.name,
          sortOrder: cat.sortOrder,
        ),
    ];
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  /// 创建栏目（排在最前面）
  Future<LibraryCategory> createCategory(String name) async {
    final category = await _databaseService.createCategory(name);
    // 重新从数据库加载以获取正确的排序
    _categories = await _databaseService.getAllCategories();
    notifyListeners();
    return category;
  }

  /// 更新栏目名称
  Future<void> updateCategory(int id, String name) async {
    await _databaseService.updateCategory(id, name);
    final index = _categories.indexWhere((c) => c.id == id);
    if (index >= 0) {
      _categories[index] = _categories[index].copyWith(name: name);
      notifyListeners();
    }
  }

  /// 删除栏目
  Future<void> deleteCategory(int id) async {
    await _databaseService.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// 交换两个栏目的排序位置
  Future<void> swapCategories(int index1, int index2) async {
    if (index1 < 0 ||
        index2 < 0 ||
        index1 >= _categories.length ||
        index2 >= _categories.length) {
      return;
    }
    final cat1 = _categories[index1];
    final cat2 = _categories[index2];
    await _databaseService.swapCategorySortOrder(
      cat1.id,
      cat1.sortOrder,
      cat2.id,
      cat2.sortOrder,
    );
    // 本地交换
    final temp = _categories[index1];
    _categories[index1] = _categories[index2];
    _categories[index2] = temp;
    notifyListeners();
  }

  /// 将乐谱添加到栏目
  Future<void> addItemToCategory(int categoryId, String itemUri) async {
    await _databaseService.addItemToCategory(categoryId, itemUri);
    notifyListeners();
  }

  /// 将乐谱从栏目移除
  Future<void> removeItemFromCategory(int categoryId, String itemUri) async {
    await _databaseService.removeItemFromCategory(categoryId, itemUri);
    notifyListeners();
  }

  /// 获取指定乐谱所属的栏目 ID 列表
  Future<List<int>> getCategoryIdsForItem(String itemUri) async {
    return await _databaseService.getCategoryIdsForItem(itemUri);
  }
}

/// 栏目显示项（包含"全部"）
class CategoryDisplayItem {
  const CategoryDisplayItem({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  final int? id; // null 表示"全部"
  final String name;
  final int sortOrder;
}
