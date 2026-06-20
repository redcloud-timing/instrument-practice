import 'dart:typed_data';

import 'package:flute_practice/models/library_item.dart';
import 'package:flute_practice/services/document_library_service.dart';

class MockDocumentLibraryService implements DocumentLibraryService {
  LibraryItem? nextPickResult;
  int pickDocumentCount = 0;
  int pickImageCount = 0;

  @override
  Future<LibraryItem?> pickDocument() async {
    pickDocumentCount++;
    return nextPickResult;
  }

  @override
  Future<LibraryItem?> pickImage() async {
    pickImageCount++;
    return nextPickResult;
  }

  @override
  Future<Uint8List> loadImageBytes(LibraryItem item) async {
    return Uint8List(0);
  }

  @override
  Future<void> deleteItem(LibraryItem item) async {}

  @override
  Future<void> openDocument(LibraryItem item) async {}

  @override
  Future<void> openWithSystemViewer(LibraryItem item) async {}

  @override
  Future<List<Map<String, String>>> getPdfViewerApps() async {
    return [];
  }

  @override
  Future<Uint8List?> getAppIcon(String packageName) async {
    return null;
  }

  @override
  Future<void> openWithSpecificApp(LibraryItem item, String packageName) async {}
}
