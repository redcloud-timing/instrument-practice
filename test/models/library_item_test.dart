import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/models/library_item.dart';

void main() {
  group('LibraryItem', () {
    test('isPdf 判断正确', () {
      const item = LibraryItem(
        uri: 'file:///test.pdf',
        title: 'Test',
        mimeType: 'application/pdf',
        addedAtIso: '',
        openedAtIso: '',
        note: '',
      );
      expect(item.isPdf, isTrue);
      expect(item.isImage, isFalse);
    });

    test('isImage 判断正确', () {
      const item = LibraryItem(
        uri: 'file:///test.png',
        title: 'Test',
        mimeType: 'image/png',
        addedAtIso: '',
        openedAtIso: '',
        note: '',
      );
      expect(item.isImage, isTrue);
      expect(item.isPdf, isFalse);
    });

    test('toMap / fromMap 对称', () {
      const original = LibraryItem(
        uri: 'file:///test.pdf',
        title: '乐谱',
        mimeType: 'application/pdf',
        addedAtIso: '2026-06-15T10:00:00',
        openedAtIso: '2026-06-15T11:00:00',
        note: '重要',
        sizeBytes: 102400,
      );

      final restored = LibraryItem.fromMap(original.toMap());

      expect(restored.uri, equals(original.uri));
      expect(restored.title, equals(original.title));
      expect(restored.mimeType, equals(original.mimeType));
      expect(restored.note, equals('重要'));
      expect(restored.sizeBytes, equals(102400));
    });

    test('fromMap 缺失字段使用默认值', () {
      final item = LibraryItem.fromMap({'uri': 'file:///test.pdf'});

      expect(item.title, equals('未命名乐谱'));
      expect(item.mimeType, equals('application/pdf'));
      expect(item.note, equals(''));
    });

    test('copyWith 部分更新', () {
      const original = LibraryItem(
        uri: 'file:///test.pdf',
        title: '原名',
        mimeType: 'application/pdf',
        addedAtIso: '',
        openedAtIso: '',
        note: '',
      );

      final updated = original.copyWith(title: '新名', note: '新笔记');

      expect(updated.title, equals('新名'));
      expect(updated.note, equals('新笔记'));
      expect(updated.uri, equals(original.uri));
    });

    test('sizeLabel 格式化 KB', () {
      const item = LibraryItem(
        uri: '',
        title: '',
        mimeType: '',
        addedAtIso: '',
        openedAtIso: '',
        note: '',
        sizeBytes: 512 * 1024,
      );
      expect(item.sizeLabel, equals('512 KB'));
    });

    test('sizeLabel 格式化 MB', () {
      const item = LibraryItem(
        uri: '',
        title: '',
        mimeType: '',
        addedAtIso: '',
        openedAtIso: '',
        note: '',
        sizeBytes: 2 * 1024 * 1024,
      );
      expect(item.sizeLabel, equals('2.0 MB'));
    });

    test('sizeLabel 为空当 sizeBytes 为 null', () {
      const item = LibraryItem(
        uri: '',
        title: '',
        mimeType: '',
        addedAtIso: '',
        openedAtIso: '',
        note: '',
      );
      expect(item.sizeLabel, equals(''));
    });
  });
}
