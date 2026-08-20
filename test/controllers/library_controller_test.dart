import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/controllers/library_controller.dart';
import 'package:flute_practice/models/library_item.dart';

import '../mocks/mock_database_service.dart';
import '../mocks/mock_document_library_service.dart';

void main() {
  late MockDatabaseService mockDb;
  late MockDocumentLibraryService mockDocService;
  late LibraryController controller;

  setUp(() async {
    mockDb = MockDatabaseService();
    mockDocService = MockDocumentLibraryService();
    controller = LibraryController(mockDb, mockDocService);
    await controller.init();
  });

  tearDown(() {
    controller.dispose();
  });

  LibraryItem makeItem({
    String uri = 'file:///test.pdf',
    String title = '测试乐谱',
    String mimeType = 'application/pdf',
  }) {
    return LibraryItem(
      uri: uri,
      title: title,
      mimeType: mimeType,
      addedAtIso: '2026-06-15T09:00:00',
      openedAtIso: '2026-06-15T10:00:00',
      note: '',
    );
  }

  group('LibraryController 初始化', () {
    test('init 完成后 isLoading 为 false', () {
      expect(controller.isLoading, isFalse);
    });

    test('初始 items 为空', () {
      expect(controller.items, isEmpty);
    });
  });

  group('资料管理', () {
    test('addDocumentsFromDevice 添加资料到列表', () async {
      mockDocService.nextPickResults = [makeItem()];
      final items = await controller.addDocumentsFromDevice();

      expect(items, isNotEmpty);
      expect(items.length, equals(1));
      expect(controller.items.length, equals(1));
      expect(controller.items[0].title, equals('测试乐谱'));
    });

    test('addDocumentsFromDevice 用户取消时不添加', () async {
      mockDocService.nextPickResults = [];
      final items = await controller.addDocumentsFromDevice();

      expect(items, isEmpty);
      expect(controller.items, isEmpty);
    });

    test('addDocumentsFromDevice 支持一次添加多个', () async {
      mockDocService.nextPickResults = [
        makeItem(uri: 'file:///a.pdf', title: '乐谱A'),
        makeItem(uri: 'file:///b.pdf', title: '乐谱B'),
      ];
      final items = await controller.addDocumentsFromDevice();

      expect(items.length, equals(2));
      expect(controller.items.length, equals(2));
    });

    test('deleteItem 移除指定资料', () async {
      mockDocService.nextPickResults = [makeItem(uri: 'file:///a.pdf')];
      final added = await controller.addDocumentsFromDevice();
      expect(controller.items.length, equals(1));

      await controller.deleteItem(added.first);
      expect(controller.items, isEmpty);
    });
  });

  group('查询', () {
    test('itemByUri 返回匹配项', () async {
      mockDocService.nextPickResults = [makeItem(uri: 'file:///find.pdf')];
      await controller.addDocumentsFromDevice();

      final found = controller.itemByUri('file:///find.pdf');
      expect(found, isNotNull);
      expect(found!.title, equals('测试乐谱'));
    });

    test('itemByUri 不存在时返回 null', () {
      expect(controller.itemByUri('file:///missing.pdf'), isNull);
    });
  });

  group('持久化', () {
    test('添加资料后保存到数据库', () async {
      mockDocService.nextPickResults = [makeItem()];
      await controller.addDocumentsFromDevice();

      final saved = await mockDb.getSetting('library_documents_v1');
      expect(saved, isNotNull);
      expect(saved!, contains('file:///test.pdf'));
    });
  });
}
