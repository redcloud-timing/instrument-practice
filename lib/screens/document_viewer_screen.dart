import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/library_controller.dart';
import '../models/library_item.dart';
import 'text_edit_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.itemUri});

  final String itemUri;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final Map<String, Future<Uint8List>> _pdfPageCache = {};

  String? _loadedUri;
  Future<int>? _pdfPageCountFuture;
  Future<Uint8List>? _imageBytesFuture;

  void _prepareDocument(LibraryItem item) {
    if (_loadedUri == item.uri) return;

    final docService = context.read<LibraryController>().documentService;
    _loadedUri = item.uri;
    _pdfPageCache.clear();
    _pdfPageCountFuture = item.isPdf ? docService.pdfPageCount(item) : null;
    _imageBytesFuture = item.isImage ? docService.loadImageBytes(item) : null;
  }

  Future<Uint8List> _loadPdfPage({
    required LibraryItem item,
    required int pageIndex,
    required int renderWidth,
  }) {
    final cacheKey = '${item.uri}|$pageIndex|$renderWidth';
    final cached = _pdfPageCache.remove(cacheKey);
    if (cached != null) {
      _pdfPageCache[cacheKey] = cached;
      return cached;
    }

    if (_pdfPageCache.length >= 12) {
      _pdfPageCache.remove(_pdfPageCache.keys.first);
    }

    final docService = context.read<LibraryController>().documentService;
    final future = docService.renderPdfPage(
      item: item,
      pageIndex: pageIndex,
      maxWidth: renderWidth,
    );
    _pdfPageCache[cacheKey] = future;
    return future;
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

    _prepareDocument(item);

    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: item.isFavorite ? '取消收藏' : '收藏',
            onPressed: () =>
                context.read<LibraryController>().toggleFavorite(item),
            icon: Icon(item.isFavorite ? Icons.star : Icons.star_outline),
          ),
          IconButton(
            tooltip: '资料笔记',
            onPressed: () => _editNote(context, item),
            icon: Icon(
              item.note.isEmpty ? Icons.note_add_outlined : Icons.note,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (item.note.isNotEmpty) _NoteBanner(note: item.note),
          Expanded(
            child: _DocumentBody(item: item, state: this),
          ),
        ],
      ),
    );
  }
}

class _DocumentBody extends StatelessWidget {
  const _DocumentBody({required this.item, required this.state});

  final LibraryItem item;
  final _DocumentViewerScreenState state;

  @override
  Widget build(BuildContext context) {
    if (item.isPdf) {
      return _PdfReader(
        pageCountFuture: state._pdfPageCountFuture!,
        loadPage: ({required int pageIndex, required int renderWidth}) {
          return state._loadPdfPage(
            item: item,
            pageIndex: pageIndex,
            renderWidth: renderWidth,
          );
        },
      );
    }

    if (item.isImage) {
      return _ImageReader(imageBytesFuture: state._imageBytesFuture!);
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

class _PdfReader extends StatelessWidget {
  const _PdfReader({required this.pageCountFuture, required this.loadPage});

  final Future<int> pageCountFuture;
  final Future<Uint8List> Function({
    required int pageIndex,
    required int renderWidth,
  })
  loadPage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: pageCountFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ViewerError(message: '${snapshot.error}');
        }

        final pageCount = snapshot.data ?? 0;
        if (pageCount <= 0) {
          return const Center(child: Text('PDF 没有可显示的页面'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final pixelRatio = MediaQuery.devicePixelRatioOf(context);
            final renderWidth = (constraints.maxWidth * pixelRatio)
                .clamp(900, 2200)
                .round();

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pageCount,
              itemBuilder: (context, index) {
                return _PdfPageImage(
                  pageFuture: loadPage(
                    pageIndex: index,
                    renderWidth: renderWidth,
                  ),
                  pageIndex: index,
                  pageCount: pageCount,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PdfPageImage extends StatelessWidget {
  const _PdfPageImage({
    required this.pageFuture,
    required this.pageIndex,
    required this.pageCount,
  });

  final Future<Uint8List> pageFuture;
  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Text(
            '${pageIndex + 1} / $pageCount',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          FutureBuilder<Uint8List>(
            future: pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _ViewerError(message: '${snapshot.error}');
              }

              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: SizedBox(
                  width: double.infinity,
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.fitWidth,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ImageReader extends StatelessWidget {
  const _ImageReader({required this.imageBytesFuture});

  final Future<Uint8List> imageBytesFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: imageBytesFuture,
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
              snapshot.data!,
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
