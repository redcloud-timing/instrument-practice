import 'package:flutter/services.dart';

import '../models/library_item.dart';

class DocumentLibraryException implements Exception {
  const DocumentLibraryException(this.message);

  final String message;
}

/// 乐谱库原生服务
///
/// 通过 MethodChannel 调用原生文件选择器，支持 PDF 和图片的导入、删除。
class DocumentLibraryService {
  static const MethodChannel _channel = MethodChannel(
    'flute_practice/documents',
  );

  /// 选择乐谱文件（支持多选）
  Future<List<LibraryItem>> pickDocuments() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>?>(
        'pickDocument',
      );
      if (result == null || result.isEmpty) return [];

      final now = DateTime.now().toIso8601String();
      return result.map((item) {
        if (item is! Map) {
          throw const DocumentLibraryException('无法读取所选文件信息。');
        }
        return LibraryItem.fromPickedMap(
          Map<Object?, Object?>.from(item),
          addedAtIso: now,
          openedAtIso: now,
        );
      }).toList();
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '选择乐谱失败。');
    }
  }

  Future<LibraryItem?> pickImage() async {
    try {
      final result = await _channel.invokeMethod<Object?>('pickImage');
      if (result == null) return null;
      if (result is! Map) {
        throw const DocumentLibraryException('无法读取所选文件信息。');
      }

      final now = DateTime.now().toIso8601String();
      final item = LibraryItem.fromPickedMap(
        Map<Object?, Object?>.from(result),
        addedAtIso: now,
        openedAtIso: now,
      );
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

  /// 使用系统自带阅读器打开 PDF
  Future<void> openWithSystemViewer(LibraryItem item) async {
    try {
      await _channel.invokeMethod<void>('openWithSystemViewer', {
        'uri': item.uri,
        'mimeType': item.mimeType,
      });
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '打开失败，请安装 PDF 阅读器。');
    }
  }

  /// 获取已安装的 PDF 阅读器列表
  Future<List<Map<String, String>>> getPdfViewerApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getPdfViewerApps',
      );
      if (result == null) return [];
      return result.map((item) {
        final map = item as Map<dynamic, dynamic>;
        return {
          'packageName': map['packageName'] as String? ?? '',
          'appName': map['appName'] as String? ?? '',
        };
      }).toList();
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '获取应用列表失败。');
    }
  }

  /// 获取应用图标
  Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException {
      return null;
    }
  }

  /// 使用指定应用打开 PDF
  Future<void> openWithSpecificApp(LibraryItem item, String packageName) async {
    try {
      await _channel.invokeMethod<void>('openWithSpecificApp', {
        'uri': item.uri,
        'mimeType': item.mimeType,
        'packageName': packageName,
      });
    } on PlatformException catch (error) {
      throw DocumentLibraryException(error.message ?? '打开失败。');
    }
  }
}
