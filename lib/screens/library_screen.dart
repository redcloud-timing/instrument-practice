import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/library_controller.dart';
import '../models/library_item.dart';
import '../services/document_library_service.dart';
import 'document_viewer_screen.dart';
import 'text_edit_screen.dart';

enum _LibraryFilter { all, favorites, pdf, image }

enum _LibraryTileAction { rename, delete }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
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
    } on DocumentLibraryException catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.message);
    }
  }

  Future<void> _openItem(BuildContext context, LibraryItem item) async {
    await context.read<LibraryController>().markOpened(item);

    if (!context.mounted) return;
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
          title: '重命名资料',
          initialText: item.title,
          hintText: '输入资料名称',
          minLines: 1,
          maxLines: 1,
          textInputAction: TextInputAction.done,
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!context.mounted) return;

    if (result.trim().isEmpty) {
      _showMessage(context, '资料名称不能为空。');
      return;
    }

    await context.read<LibraryController>().renameItem(item, result);
  }

  Future<void> _editNote(BuildContext context, LibraryItem item) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditScreen(
          title: '资料笔记',
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
          title: const Text('移除资料'),
          content: Text('从列表中移除「${item.title}」？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
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

  List<LibraryItem> _filteredItems(Iterable<LibraryItem> source) {
    return [
      for (final item in source)
        if (_matchesFilter(item) && _matchesQuery(item)) item,
    ];
  }

  bool _matchesFilter(LibraryItem item) {
    return switch (_filter) {
      _LibraryFilter.all => true,
      _LibraryFilter.favorites => item.isFavorite,
      _LibraryFilter.pdf => item.isPdf,
      _LibraryFilter.image => item.isImage,
    };
  }

  bool _matchesQuery(LibraryItem item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    return item.title.toLowerCase().contains(query) ||
        item.note.toLowerCase().contains(query);
  }

  bool get _isFiltering {
    return _filter != _LibraryFilter.all ||
        _searchController.text.trim().isNotEmpty;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleRecentItems = _filteredItems(controller.recentItems);
    final visibleFavoriteItems = _filteredItems(controller.favoriteItems);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LibraryHeader(
            itemCount: controller.items.length,
            favoriteCount: controller.favoriteItems.length,
            busy: controller.isBusy,
            onAdd: () => _addDocument(context),
          ),
          const SizedBox(height: 12),
          _LibrarySearchControls(
            controller: _searchController,
            filter: _filter,
            onClearSearch: _searchController.clear,
            onFilterChanged: (filter) => setState(() => _filter = filter),
          ),
          if (_isFiltering) ...[
            const SizedBox(height: 20),
            const _SectionTitle('筛选结果'),
            const SizedBox(height: 8),
            if (visibleRecentItems.isEmpty)
              const _EmptyLibrary(message: '没有找到匹配资料')
            else
              for (final item in visibleRecentItems)
                _LibraryTile(
                  item: item,
                  busy: controller.isBusy,
                  onOpen: () => _openItem(context, item),
                  onFavorite: () =>
                      context.read<LibraryController>().toggleFavorite(item),
                  onNote: () => _editNote(context, item),
                  onRename: () => _renameItem(context, item),
                  onDelete: () => _deleteItem(context, item),
                ),
          ] else ...[
            if (visibleFavoriteItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionTitle('收藏'),
              const SizedBox(height: 8),
              for (final item in visibleFavoriteItems)
                _LibraryTile(
                  item: item,
                  busy: controller.isBusy,
                  onOpen: () => _openItem(context, item),
                  onFavorite: () =>
                      context.read<LibraryController>().toggleFavorite(item),
                  onNote: () => _editNote(context, item),
                  onRename: () => _renameItem(context, item),
                  onDelete: () => _deleteItem(context, item),
                ),
            ],
            const SizedBox(height: 20),
            const _SectionTitle('最近'),
            const SizedBox(height: 8),
            if (visibleRecentItems.isEmpty)
              const _EmptyLibrary(message: '暂无资料')
            else
              for (final item in visibleRecentItems)
                _LibraryTile(
                  item: item,
                  busy: controller.isBusy,
                  onOpen: () => _openItem(context, item),
                  onFavorite: () =>
                      context.read<LibraryController>().toggleFavorite(item),
                  onNote: () => _editNote(context, item),
                  onRename: () => _renameItem(context, item),
                  onDelete: () => _deleteItem(context, item),
                ),
          ],
        ],
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.itemCount,
    required this.favoriteCount,
    required this.busy,
    required this.onAdd,
  });

  final int itemCount;
  final int favoriteCount;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.library_music_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('乐谱资料', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(
                  icon: Icons.picture_as_pdf_outlined,
                  label: '$itemCount',
                ),
                _CountChip(icon: Icons.star_outline, label: '$favoriteCount'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '支持 PDF 和图片，可收藏、加笔记、在 App 内查看。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onAdd,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(busy ? '处理中' : '添加资料'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySearchControls extends StatelessWidget {
  const _LibrarySearchControls({
    required this.controller,
    required this.filter,
    required this.onClearSearch,
    required this.onFilterChanged,
  });

  static const _filters = [
    _LibraryFilter.all,
    _LibraryFilter.favorites,
    _LibraryFilter.pdf,
    _LibraryFilter.image,
  ];

  final TextEditingController controller;
  final _LibraryFilter filter;
  final VoidCallback onClearSearch;
  final ValueChanged<_LibraryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            hintText: '按名称或笔记搜索',
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _filters)
              ChoiceChip(
                label: Text(value.label),
                selected: filter == value,
                onSelected: (_) => onFilterChanged(value),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

extension on _LibraryFilter {
  String get label {
    return switch (this) {
      _LibraryFilter.all => '全部',
      _LibraryFilter.favorites => '收藏',
      _LibraryFilter.pdf => 'PDF',
      _LibraryFilter.image => '图片',
    };
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.folder_open,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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
    required this.onOpen,
    required this.onFavorite,
    required this.onNote,
    required this.onRename,
    required this.onDelete,
  });

  final LibraryItem item;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onNote;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sizeLabel = item.sizeLabel;
    final subtitle = [
      item.typeLabel,
      if (sizeLabel.isNotEmpty) sizeLabel,
      if (item.note.isNotEmpty) '有笔记',
      if (item.isPdf && item.lastPageIndex > 0)
        '上次第 ${item.lastPageIndex + 1} 页',
      item.openedAtLabel,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: Icon(
            item.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: SizedBox(
            width: 144,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: item.isFavorite ? '取消收藏' : '收藏',
                  onPressed: busy ? null : onFavorite,
                  icon: Icon(item.isFavorite ? Icons.star : Icons.star_outline),
                ),
                IconButton(
                  tooltip: '资料笔记',
                  onPressed: busy ? null : onNote,
                  icon: Icon(
                    item.note.isEmpty ? Icons.note_add_outlined : Icons.note,
                  ),
                ),
                PopupMenuButton<_LibraryTileAction>(
                  tooltip: '更多操作',
                  enabled: !busy,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case _LibraryTileAction.rename:
                        onRename();
                      case _LibraryTileAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _LibraryTileAction.rename,
                      child: ListTile(
                        leading: Icon(Icons.drive_file_rename_outline),
                        title: Text('重命名'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _LibraryTileAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('移除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          onTap: busy ? null : onOpen,
        ),
      ),
    );
  }
}
