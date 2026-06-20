import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/library_controller.dart';
import '../models/category.dart';
import '../models/library_item.dart';
import '../services/database_service.dart';
import 'document_viewer_screen.dart';
import 'text_edit_screen.dart';

enum _LibraryTileAction { rename, delete, addToCategory }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  Uint8List? _defaultAppIcon;
  bool _searchExpanded = false;
  int? _selectedCategoryId; // null 表示"全部"
  Set<String> _categoryItemUris = {}; // 当前选中栏目下的乐谱 URI 集合
  List<CategoryDisplayItem> _sortedDisplayItems = []; // 排序后的栏目显示列表

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addObserver(this);
    _loadDefaultAppIcon();
    _loadCategories();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDefaultAppIcon();
    }
  }

  Future<void> _loadDefaultAppIcon() async {
    try {
      final dbService = context.read<DatabaseService>();
      final docService = context.read<LibraryController>().documentService;
      final packageName = await dbService.getSetting('default_pdf_viewer');

      if (packageName != null && packageName.isNotEmpty) {
        final iconBytes = await docService.getAppIcon(packageName);
        if (mounted) {
          setState(() {
            _defaultAppIcon = iconBytes;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _defaultAppIcon = null;
          });
        }
      }
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _loadCategories() async {
    final controller = context.read<LibraryController>();
    await controller.loadCategories();
    final items = await controller.getSortedCategoryDisplayItems();
    if (mounted) {
      setState(() {
        _sortedDisplayItems = items;
      });
    }
  }

  Future<void> _loadCategoryItems(int categoryId) async {
    final dbService = context.read<DatabaseService>();
    final uris = await dbService.getCategoryItemUris(categoryId);
    if (mounted) {
      setState(() {
        _categoryItemUris = uris.toSet();
      });
    }
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _categoryItemUris = {};
    });
    if (categoryId != null) {
      _loadCategoryItems(categoryId);
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  Future<void> _addDocument(BuildContext context) async {
    final controller = context.read<LibraryController>();

    try {
      final item = await controller.addDocumentFromDevice();
      if (!context.mounted || item == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加：${item.title}')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _openItem(BuildContext context, LibraryItem item) {
    context.read<LibraryController>().markOpened(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(itemUri: item.uri),
      ),
    );
  }

  Future<void> _renameItem(BuildContext context, LibraryItem item) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditScreen(
          title: '重命名乐谱',
          initialText: item.title,
          hintText: '输入新名称',
          selectAllOnOpen: true,
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!context.mounted) return;

    if (result.trim().isEmpty) {
      _showMessage(context, '乐谱名称不能为空。');
      return;
    }

    await context.read<LibraryController>().renameItem(item, result);
  }

  Future<void> _editNote(BuildContext context, LibraryItem item) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditScreen(
          title: '乐谱笔记',
          initialText: item.note,
          hintText: '写下指法、节奏、换气或练习提醒',
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!context.mounted) return;
    await context.read<LibraryController>().saveNote(item, result);
  }

  Future<void> _deleteItem(BuildContext context, LibraryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('移除乐谱'),
          content: Text('从列表中移除「${item.title}」？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<LibraryController>().deleteItem(item);
  }

  Future<void> _showAddToCategoryDialog(
    BuildContext context,
    LibraryItem item,
  ) async {
    final controller = context.read<LibraryController>();
    final categories = controller.categories;

    if (categories.isEmpty) {
      _showMessage(context, '还没有创建栏目，请先创建栏目');
      return;
    }

    // 获取该乐谱当前所属的栏目
    final currentCategoryIds = await controller.getCategoryIdsForItem(item.uri);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '将「${item.title}」添加到栏目',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isAdded = currentCategoryIds.contains(category.id);
                      return ListTile(
                        leading: Icon(
                          isAdded
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isAdded
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(category.name),
                        onTap: () async {
                          if (isAdded) {
                            await controller.removeItemFromCategory(
                              category.id,
                              item.uri,
                            );
                            _showMessage(context, '已从「${category.name}」移除');
                          } else {
                            await controller.addItemToCategory(
                              category.id,
                              item.uri,
                            );
                            _showMessage(context, '已添加到「${category.name}」');
                          }
                          // 刷新当前栏目筛选
                          if (_selectedCategoryId == category.id) {
                            _loadCategoryItems(category.id);
                          }
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 栏目管理底部弹出面板：支持删除、重命名、排序
  void _showCategoryManageSheet(
    BuildContext context,
    List<LibraryCategory> categories,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return _CategoryManageSheet(
              categories: categories,
              scrollController: scrollController,
            );
          },
        );
      },
    ).whenComplete(() {
      // 关闭面板后刷新标签栏排序
      _loadCategories();
    });
  }

  List<LibraryItem> _filteredItems(Iterable<LibraryItem> source) {
    return [
      for (final item in source)
        if (_matchesCategory(item) && _matchesQuery(item)) item,
    ];
  }

  bool _matchesCategory(LibraryItem item) {
    if (_selectedCategoryId == null) return true;
    return _categoryItemUris.contains(item.uri);
  }

  bool _matchesQuery(LibraryItem item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    return item.title.toLowerCase().contains(query) ||
        item.note.toLowerCase().contains(query);
  }

  bool get _isFiltering {
    return _selectedCategoryId != null ||
        _searchController.text.trim().isNotEmpty;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPdfViewerSettings(BuildContext context) async {
    final dbService = context.read<DatabaseService>();
    final docService = context.read<LibraryController>().documentService;

    List<Map<String, String>> apps = [];
    try {
      apps = await docService.getPdfViewerApps();
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '获取应用列表失败');
      }
      return;
    }

    final currentDefault = await dbService.getSetting('default_pdf_viewer');

    // 获取每个应用的图标
    final appIcons = <String, Uint8List>{};
    for (final app in apps) {
      final icon = await docService.getAppIcon(app['packageName'] ?? '');
      if (icon != null) {
        appIcons[app['packageName'] ?? ''] = icon;
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '选择默认 PDF 阅读器',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone_android),
                        title: const Text('每次选择'),
                        subtitle: const Text('打开时弹出选择器'),
                        trailing:
                            currentDefault == null || currentDefault.isEmpty
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () async {
                          await dbService.setSetting('default_pdf_viewer', '');
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (mounted) {
                            setState(() {
                              _defaultAppIcon = null;
                            });
                            _showMessage(context, '已清除默认应用');
                          }
                        },
                      ),
                      for (final app in apps)
                        ListTile(
                          leading: appIcons[app['packageName']] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    appIcons[app['packageName']]!,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          title: Text(app['appName'] ?? ''),
                          trailing: currentDefault == app['packageName']
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () async {
                            await dbService.setSetting(
                              'default_pdf_viewer',
                              app['packageName'] ?? '',
                            );
                            final iconBytes = await docService.getAppIcon(
                              app['packageName'] ?? '',
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted) {
                              setState(() {
                                _defaultAppIcon = iconBytes;
                              });
                              _showMessage(
                                context,
                                '已设置默认阅读器：${app['appName']}',
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = controller.categories;

    // 获取排序后的栏目显示列表（如果还没加载完成，用 categories 构建临时列表）
    final displayItems = _sortedDisplayItems.isNotEmpty
        ? _sortedDisplayItems
        : [
            CategoryDisplayItem(id: null, name: '全部', sortOrder: -1),
            for (final cat in categories)
              CategoryDisplayItem(
                id: cat.id,
                name: cat.name,
                sortOrder: cat.sortOrder,
              ),
          ];

    // 根据选中的栏目过滤乐谱
    final visibleItems = _filteredItems(controller.recentItems);

    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // 合并标题栏：标题 + 统计 + 操作按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: colorScheme.surface,
            child: Column(
              children: [
                // 第一行：标题 + 统计 + 操作按钮
                Row(
                  children: [
                    Icon(
                      Icons.library_music_outlined,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '乐谱库(${controller.items.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    // 搜索按钮
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _searchExpanded = !_searchExpanded;
                          if (!_searchExpanded) {
                            _searchController.clear();
                          }
                        });
                      },
                      icon: Icon(
                        _searchExpanded ? Icons.close : Icons.search,
                        size: 22,
                      ),
                      tooltip: _searchExpanded ? '关闭搜索' : '搜索',
                    ),
                    // 默认阅读器图标
                    GestureDetector(
                      onTap: () => _showPdfViewerSettings(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        child: _defaultAppIcon != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(
                                  _defaultAppIcon!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 添加按钮
                    SizedBox(
                      height: 32,
                      child: FilledButton.icon(
                        onPressed: controller.isBusy
                            ? null
                            : () => _addDocument(context),
                        icon: controller.isBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add, size: 18),
                        label: Text(
                          controller.isBusy ? '处理中' : '添加',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                // 搜索框（展开时显示）
                if (_searchExpanded) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '搜索乐谱名称或笔记...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.clear, size: 18),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 栏目标签栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final displayItem in displayItems) ...[
                          if (displayItems.indexOf(displayItem) > 0)
                            const SizedBox(width: 8),
                          _CategoryChip(
                            label: displayItem.name,
                            selected: displayItem.id == null
                                ? _selectedCategoryId == null
                                : _selectedCategoryId == displayItem.id,
                            onTap: () => _onCategoryChanged(displayItem.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 栏目管理设置按钮
                GestureDetector(
                  onTap: () => _showCategoryManageSheet(context, categories),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _SettingsIconPainter(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 乐谱列表
          Expanded(
            child: _buildItemList(
              context,
              controller,
              visibleItems,
              categories,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(
    BuildContext context,
    LibraryController controller,
    List<LibraryItem> visibleItems,
    List<LibraryCategory> categories,
  ) {
    if (visibleItems.isEmpty) {
      return const _EmptyLibrary(message: '暂无乐谱，点击上方「添加」导入');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        return _LibraryTile(
          item: item,
          busy: controller.isBusy,
          categories: categories,
          onOpen: () => _openItem(context, item),
          onNote: () => _editNote(context, item),
          onRename: () => _renameItem(context, item),
          onDelete: () => _deleteItem(context, item),
          onAddToCategory: () => _showAddToCategoryDialog(context, item),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.item,
    required this.busy,
    required this.categories,
    required this.onOpen,
    required this.onNote,
    required this.onRename,
    required this.onDelete,
    required this.onAddToCategory,
  });

  final LibraryItem item;
  final bool busy;
  final List<LibraryCategory> categories;
  final VoidCallback onOpen;
  final VoidCallback onNote;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddToCategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasNote = item.note.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onOpen,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.isPdf
                ? colorScheme.primaryContainer
                : colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            item.isPdf ? Icons.picture_as_pdf : Icons.image,
            color: item.isPdf
                ? colorScheme.onPrimaryContainer
                : colorScheme.onTertiaryContainer,
            size: 20,
          ),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${item.sizeLabel} · ${item.openedAtLabel}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 笔记按钮（替代原来的收藏按钮）
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onNote,
                  icon: Icon(
                    hasNote ? Icons.note : Icons.note_add_outlined,
                    color: hasNote ? colorScheme.primary : null,
                    size: 20,
                  ),
                  tooltip: hasNote ? '查看笔记' : '添加笔记',
                ),
                if (hasNote)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            PopupMenuButton<_LibraryTileAction>(
              onSelected: (action) {
                switch (action) {
                  case _LibraryTileAction.rename:
                    onRename();
                  case _LibraryTileAction.delete:
                    onDelete();
                  case _LibraryTileAction.addToCategory:
                    onAddToCategory();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _LibraryTileAction.rename,
                  child: Text('重命名'),
                ),
                const PopupMenuItem(
                  value: _LibraryTileAction.addToCategory,
                  child: Text('添加到栏目'),
                ),
                const PopupMenuItem(
                  value: _LibraryTileAction.delete,
                  child: Text('移除'),
                ),
              ],
              icon: const Icon(Icons.more_vert, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// 栏目管理面板：支持重命名、删除、排序栏目
class _CategoryManageSheet extends StatefulWidget {
  const _CategoryManageSheet({
    required this.categories,
    required this.scrollController,
  });

  final List<LibraryCategory> categories;
  final ScrollController scrollController;

  @override
  State<_CategoryManageSheet> createState() => _CategoryManageSheetState();
}

class _CategoryManageSheetState extends State<_CategoryManageSheet>
    with SingleTickerProviderStateMixin {
  late List<_ManageItem> _items;
  late AnimationController _animController;
  int _movingUpIndex = -1; // 正在上移的 item 索引
  int _movingDownIndex = -1; // 正在下移的 item 索引（上面那个）
  Map<int, int> _itemCounts = {}; // 栏目ID -> 乐谱数量
  int _itemCountForAll = 0; // 全部乐谱数量

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buildItems();
  }

  Future<void> _buildItems() async {
    final controller = context.read<LibraryController>();
    final dbService = context.read<DatabaseService>();
    final sortedItems = await controller.getSortedCategoryDisplayItems();

    // 加载每个栏目的乐谱数量
    final counts = <int, int>{};
    for (final cat in controller.categories) {
      final uris = await dbService.getCategoryItemUris(cat.id);
      counts[cat.id] = uris.length;
    }

    if (mounted) {
      setState(() {
        _itemCounts = counts;
        _itemCountForAll = controller.items.length;
        _items = [
          for (final displayItem in sortedItems)
            _ManageItem(
              category: displayItem.id != null
                  ? LibraryCategory(
                      id: displayItem.id!,
                      name: displayItem.name,
                      sortOrder: displayItem.sortOrder,
                      createdAtIso: '',
                    )
                  : null,
              isAll: displayItem.id == null,
            ),
        ];
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 点击上移
  Future<void> _moveUp(int index) async {
    if (index <= 0) return; // 已在最顶部
    if (_movingUpIndex != -1) return; // 动画中

    final controller = context.read<LibraryController>();

    // 先获取需要交换的数据（在动画开始前）
    final item = _items[index];
    final aboveItem = _items[index - 1];

    final itemOrder = item.isAll
        ? await controller.getAllCategorySortOrder()
        : item.category?.sortOrder ?? 0;
    final aboveOrder = aboveItem.isAll
        ? await controller.getAllCategorySortOrder()
        : aboveItem.category?.sortOrder ?? 0;

    // 启动动画
    setState(() {
      _movingUpIndex = index;
      _movingDownIndex = index - 1;
    });

    // 等动画真正完成（用动画控制器的 future，不用 Future.delayed）
    await _animController.forward(from: 0).orCancel;

    // 动画完成后，交换 sort_order
    if (item.isAll) {
      await controller.setAllCategorySortOrder(aboveOrder);
      if (aboveItem.category != null) {
        final dbService = context.read<DatabaseService>();
        await dbService.updateCategorySortOrder(
          aboveItem.category!.id,
          itemOrder,
        );
      }
    } else if (aboveItem.isAll) {
      await controller.setAllCategorySortOrder(itemOrder);
      final dbService = context.read<DatabaseService>();
      await dbService.updateCategorySortOrder(item.category!.id, aboveOrder);
    } else {
      final dbService = context.read<DatabaseService>();
      await dbService.swapCategorySortOrder(
        item.category!.id,
        itemOrder,
        aboveItem.category!.id,
        aboveOrder,
      );
    }

    if (mounted) {
      setState(() {
        // 交换列表数据 + 重置动画索引（原子操作，一次重建完成）
        final temp = _items[index];
        _items[index] = _items[index - 1];
        _items[index - 1] = temp;
        _movingUpIndex = -1;
        _movingDownIndex = -1;
      });
      _animController.reset();
    }
  }

  Future<void> _renameCategory(LibraryCategory category) async {
    final controller = context.read<LibraryController>();
    final TextEditingController nameController = TextEditingController(
      text: category.name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('重命名栏目'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入新名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext, name);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) return;

    await controller.updateCategory(category.id, result);
    setState(() {
      final index = _items.indexWhere(
        (item) => !item.isAll && item.category?.id == category.id,
      );
      if (index >= 0) {
        _items[index] = _ManageItem(
          category: _items[index].category!.copyWith(name: result),
          isAll: false,
        );
      }
    });
  }

  Future<void> _deleteCategory(LibraryCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定删除栏目「${category.name}」？\n栏目中的乐谱不会被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final controller = context.read<LibraryController>();
    await controller.deleteCategory(category.id);
    setState(() {
      _items.removeWhere(
        (item) => !item.isAll && item.category?.id == category.id,
      );
    });
  }

  Future<void> _createCategory() async {
    final TextEditingController nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('创建新栏目'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入栏目名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext, name);
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) return;

    final controller = context.read<LibraryController>();
    await controller.createCategory(result);
    await _buildItems();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '栏目管理',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () => _createCategory(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加栏目', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final isMovingUp = index == _movingUpIndex;
              final isMovingDown = index == _movingDownIndex;
              final isAtTop = index == 0;

              Widget tile;
              if (item.isAll) {
                // "全部"栏目
                tile = Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.select_all, color: colorScheme.primary),
                    title: Text(
                      '全部',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Text(
                      '$_itemCountForAll 首',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: isAtTop ? null : () => _moveUp(index),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } else {
                final category = item.category!;
                final count = _itemCounts[category.id] ?? 0;
                tile = Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: colorScheme.primary,
                    ),
                    title: Text(category.name),
                    subtitle: Text(
                      '$count 首',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: isAtTop ? null : () => _moveUp(index),
                    trailing: SizedBox(
                      width: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 重命名按钮（更大点击区域）
                          InkWell(
                            onTap: () => _renameCategory(category),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 22,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 删除按钮
                          InkWell(
                            onTap: () => _deleteCategory(category),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.delete_outline,
                                size: 22,
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }

              // 动画：被点击的 item 向上滑动
              if (isMovingUp) {
                return SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: Offset.zero,
                        end: const Offset(0, -1),
                      ).animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                  child: tile,
                );
              }

              // 动画：上方的 item 向下滑动
              if (isMovingDown) {
                return SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: Offset.zero,
                        end: const Offset(0, 1),
                      ).animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                  child: tile,
                );
              }

              return tile;
            },
          ),
        ),
      ],
    );
  }
}

/// 管理面板中的条目
class _ManageItem {
  const _ManageItem({required this.category, required this.isAll});
  final LibraryCategory? category;
  final bool isAll;
}

/// 设置图标绘制器：三条线，每条线前面有一个点
class _SettingsIconPainter extends CustomPainter {
  _SettingsIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final dotRadius = 2.0;
    final dotX = size.width * 0.2;
    final lineStartX = size.width * 0.35;
    final lineEndX = size.width * 0.8;
    final spacing = size.height / 4;

    for (int i = 0; i < 3; i++) {
      final y = spacing * (i + 1);
      // 画点
      canvas.drawCircle(Offset(dotX, y), dotRadius, dotPaint);
      // 画线
      canvas.drawLine(Offset(lineStartX, y), Offset(lineEndX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
