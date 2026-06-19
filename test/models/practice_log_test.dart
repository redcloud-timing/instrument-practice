import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/models/practice_log.dart';

void main() {
  group('PracticeLog', () {
    test('fromMap 正常数据', () {
      final log = PracticeLog.fromMap({
        'id': 1,
        'practice_date': '2026-06-15',
        'duration_seconds': 1800,
        'note': '练习长音',
        'created_at': '2026-06-15T10:00:00',
        'updated_at': '2026-06-15T10:30:00',
      });

      expect(log.id, equals(1));
      expect(log.practiceDate, equals('2026-06-15'));
      expect(log.durationSeconds, equals(1800));
      expect(log.note, equals('练习长音'));
    });

    test('fromMap 缺失字段使用默认值', () {
      final log = PracticeLog.fromMap({
        'practice_date': '2026-06-15',
        'created_at': '2026-06-15T10:00:00',
        'updated_at': '2026-06-15T10:00:00',
      });

      expect(log.id, isNull);
      expect(log.durationSeconds, equals(0));
      expect(log.note, equals(''));
    });

    test('toMap 与 fromMap 对称', () {
      final original = PracticeLog(
        id: 42,
        practiceDate: '2026-06-15',
        durationSeconds: 3600,
        note: '音阶练习',
        createdAt: '2026-06-15T08:00:00',
        updatedAt: '2026-06-15T09:00:00',
      );

      final restored = PracticeLog.fromMap(original.toMap());

      expect(restored.id, equals(original.id));
      expect(restored.practiceDate, equals(original.practiceDate));
      expect(restored.durationSeconds, equals(original.durationSeconds));
      expect(restored.note, equals(original.note));
    });

    test('hasPractice 为 true 当 durationSeconds > 0', () {
      final log = PracticeLog.fromMap({
        'practice_date': '2026-06-15',
        'duration_seconds': 60,
        'created_at': '',
        'updated_at': '',
      });
      expect(log.hasPractice, isTrue);
    });

    test('hasPractice 为 false 当 durationSeconds == 0', () {
      final log = PracticeLog.fromMap({
        'practice_date': '2026-06-15',
        'duration_seconds': 0,
        'created_at': '',
        'updated_at': '',
      });
      expect(log.hasPractice, isFalse);
    });
  });
}
