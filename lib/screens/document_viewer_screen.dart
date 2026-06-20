import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/library_controller.dart';
import '../models/library_item.dart';
import '../services/database_service.dart';
import '../services/document_library_service.dart';
import 'text_edit_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.itemUri});

  final String itemUri;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  String? _loadedUri;

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

  Future<void> _openPdf(LibraryItem item) async {
    try {
      final docService = context.read<LibraryController>().documentService;
      final dbService = context.read<DatabaseService>();

      // 读取默认应用
      final defaultPackage = await dbService.getSetting('default_pdf_viewer');

      if (defaultPackage != null && defaultPackage.isNotEmpty) {
        // 有默认应用，直接打开
        await docService.openWithSpecificApp(item, defaultPackage);
        // 自动返回「资料」界面
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // 没有默认应用，显示选择器
        await _showAppPickerAndOpen(item, docService, dbService);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showAppPickerAndOpen(
    LibraryItem item,
    DocumentLibraryService docService,
    DatabaseService dbService,
  ) async {
    // 获取已安装的 PDF 阅读器
    List<Map<String, String>> apps = [];
    try {
      apps = await docService.getPdfViewerApps();
    } catch (_) {
      // 获取失败，使用系统选择器
      await docService.openWithSystemViewer(item);
      return;
    }

    if (apps.isEmpty) {
      // 没有找到应用，使用系统选择器
      await docService.openWithSystemViewer(item);
      return;
    }

    if (!mounted) return;

    // 获取每个应用的图标
    final appIcons = <String, Uint8List>{};
    for (final app in apps) {
      final icon = await docService.getAppIcon(app['packageName'] ?? '');
      if (icon != null) {
        appIcons[app['packageName'] ?? ''] = icon;
      }
    }

    if (!mounted) return;

    // 显示底部选择器
    final selected = await showModalBottomSheet<Map<String, String>>(
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
                    '选择 PDF 阅读器',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
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
                          onTap: () => Navigator.pop(sheetContext, app),
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

    if (selected != null && mounted) {
      final packageName = selected['packageName'] ?? '';
      // 保存为默认应用
      await dbService.setSetting('default_pdf_viewer', packageName);
      // 打开 PDF
      await docService.openWithSpecificApp(item, packageName);
      // 自动返回「资料」界面
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final item = controller.itemByUri(widget.itemUri);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资料')),
        body: const Center(child: Text('资料已被移除')),
      );
    }

    // PDF 自动打开
    if (item.isPdf && _loadedUri != item.uri) {
      _loadedUri = item.uri;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPdf(item);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '用其他应用打开',
            onPressed: () => _openPdf(item),
            icon: const Icon(Icons.open_in_new),
          ),
          IconButton(
            tooltip: '资料笔记',
            onPressed: () => _editNote(context, item),
            icon: Icon(
              item.note.trim().isNotEmpty
                  ? Icons.note
                  : Icons.note_add_outlined,
              color: item.note.trim().isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (item.note.isNotEmpty) _NoteBanner(note: item.note),
          Expanded(
            child: _DocumentBody(item: item, onOpenPdf: () => _openPdf(item)),
          ),
        ],
      ),
    );
  }
}

class _DocumentBody extends StatelessWidget {
  const _DocumentBody({required this.item, required this.onOpenPdf});

  final LibraryItem item;
  final VoidCallback onOpenPdf;

  @override
  Widget build(BuildContext context) {
    if (item.isPdf) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(item.sizeLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenPdf,
              icon: const Icon(Icons.open_in_new),
              label: const Text('用外部应用打开'),
            ),
          ],
        ),
      );
    }

    if (item.isImage) {
      return _ImageReader(item: item);
    }

    return const Center(child: Text('暂不支持这种资料格式'));
  }
}

class _NoteBanner extends StatelessWidget {
  const _NoteBanner({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        note,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ImageReader extends StatelessWidget {
  const _ImageReader({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final docService = context.read<LibraryController>().documentService;
    return FutureBuilder<List<int>>(
      future: docService.loadImageBytes(item),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ViewerError(message: '${snapshot.error}');
        }

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.memory(
              snapshot.data as dynamic,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        );
      },
    );
  }
}

class _ViewerError extends StatelessWidget {
  const _ViewerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
