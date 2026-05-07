import 'package:flutter/services.dart';

import '../models/library_item.dart';

class DocumentLibraryException implements Exception {
  const DocumentLibraryException(this.message);

  final String message;
}

class DocumentLibraryService {
  static const MethodChannel _channel = MethodChannel(
    'flute_practice/documents',
  );

  Future<LibraryItem?> pickDocument() async {
    try {
      final result = await _channel.invokeMethod<Object?>('pickDocument');
      if (result == null) return null;
      if (result is! Map) {
        throw const DocumentLibraryException('无法读取所选文件信息。');
      }

      final now = DateTime.now().toIso8601String();
      return LibraryItem.fromPickedMap(
        Map<Object?, Object?>.from(result),
        addedAtIso: now,
        openedAtIso: now,
      );
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '选择资料失败。');
    }
  }

  Future<LibraryItem?> pickImage() async {
    try {
      final result = await _channel.invokeMethod<Object?>('pickImage');
      if (result == null) return null;
      if (result is! Map) {
        throw const DocumentLibraryException('无法读取所选图片信息。');
      }

      final now = DateTime.now().toIso8601String();
      final item = LibraryItem.fromPickedMap(
        Map<Object?, Object?>.from(result),
        addedAtIso: now,
        openedAtIso: now,
      );
      if (!item.isImage) {
        throw const DocumentLibraryException('请选择图片文件。');
      }
      return item;
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '选择图片失败。');
    }
  }

  Future<Uint8List> loadImageBytes(LibraryItem item) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('loadImage', {
        'uri': item.uri,
      });
      if (result == null || result.isEmpty) {
        throw const DocumentLibraryException('图片内容为空。');
      }
      return result;
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '读取图片失败。');
    }
  }

  Future<int> pdfPageCount(LibraryItem item) async {
    try {
      final result = await _channel.invokeMethod<int>('pdfPageCount', {
        'uri': item.uri,
      });
      return result ?? 0;
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '读取 PDF 失败。');
    }
  }

  Future<Uint8List> renderPdfPage({
    required LibraryItem item,
    required int pageIndex,
    required int maxWidth,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('renderPdfPage', {
        'uri': item.uri,
        'pageIndex': pageIndex,
        'maxWidth': maxWidth,
      });
      if (result == null || result.isEmpty) {
        throw const DocumentLibraryException('PDF 页面为空。');
      }
      return result;
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '渲染 PDF 失败。');
    }
  }

  Future<void> openDocument(LibraryItem item) async {
    try {
      await _channel.invokeMethod<void>('openDocument', {
        'uri': item.uri,
        'mimeType': item.mimeType,
      });
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '打开资料失败。');
    }
  }
}
