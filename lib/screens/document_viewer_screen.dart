import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  String? _loadedUri;
  Uint8List? _pdfBytes;
  Future<Uint8List>? _imageBytesFuture;
  PdfViewerController? _pdfController;
  bool _jumpScheduled = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  void _prepareDocument(LibraryItem item) {
    if (_loadedUri == item.uri) return;

    final docService = context.read<LibraryController>().documentService;
    _loadedUri = item.uri;
    _jumpScheduled = false;

    if (item.isPdf) {
      docService.loadPdfBytes(item).then((bytes) {
        if (mounted && _loadedUri == item.uri) {
          setState(() {
            _pdfBytes = bytes;
          });
        }
      });
    } else if (item.isImage) {
      _imageBytesFuture = docService.loadImageBytes(item);
    }
  }

  void _onPdfDocumentLoaded(PdfDocumentLoadedDetails details) {
    final item = context.read<LibraryController>().itemByUri(widget.itemUri);
    if (item == null) return;

    final targetPage = item.lastPageIndex + 1; // SfPdfViewer 页码从 1 开始
    if (targetPage > 1 && targetPage <= details.document.pages.count) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_jumpScheduled) {
          _jumpScheduled = true;
          _pdfController?.jumpToPage(targetPage);
        }
      });
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final item = context.read<LibraryController>().itemByUri(widget.itemUri);
    if (item != null) {
      context.read<LibraryController>().saveLastPageIndex(
        item,
        details.newPageNumber - 1,
      );
    }
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
            icon: const Icon(Icons.edit_note),
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
      if (state._pdfBytes == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return SfPdfViewer.memory(
        state._pdfBytes!,
        controller: state._pdfController,
        onDocumentLoaded: state._onPdfDocumentLoaded,
        onPageChanged: state._onPageChanged,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
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
