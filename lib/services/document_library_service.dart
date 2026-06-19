import 'package:flutter/services.dart';

import '../models/library_item.dart';

class DocumentLibraryException implements Exception {
  const DocumentLibraryException(this.message);

  final String message;
}

/// 文档资料库原生服务
///
/// 通过 MethodChannel 调用原生文件选择器，支持 PDF 和图片的导入、渲染和删除。
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

  /// 加载 PDF 文件的完整字节
  ///
  /// 用于 SfPdfViewer.memory 渲染。
  Future<Uint8List> loadPdfBytes(LibraryItem item) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('loadPdfBytes', {
        'uri': item.uri,
      });
      if (result == null || result.isEmpty) {
        throw const DocumentLibraryException('PDF 文件内容为空。');
      }
      return result;
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '读取 PDF 失败。');
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
