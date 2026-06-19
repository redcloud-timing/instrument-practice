import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/controllers/practice_controller.dart';

import '../mocks/mock_database_service.dart';

void main() {
  late MockDatabaseService mockDb;
  late PracticeController controller;

  setUp(() async {
    mockDb = MockDatabaseService();
    controller = PracticeController(mockDb);
    await controller.init();
  });

  tearDown(() {
    controller.dispose();
  });

  group('PracticeController 初始化', () {
    test('init 完成后 isLoading 为 false', () {
      expect(controller.isLoading, isFalse);
    });

    test('初始状态无运行计时器', () {
      expect(controller.isTimerRunning, isFalse);
    });
  });

  group('练习计时器', () {
    test('startTimer 启动计时器', () async {
      await controller.startTimer();
      expect(controller.isTimerRunning, isTrue);
    });

    test('stopTimerAndSave 停止计时器并返回秒数', () async {
      await controller.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final seconds = await controller.stopTimerAndSave();

      expect(controller.isTimerRunning, isFalse);
      expect(seconds, greaterThanOrEqualTo(1));
    });

    test('stopTimerAndSave 将数据写入数据库', () async {
      await controller.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await controller.stopTimerAndSave();

      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final savedLog = await mockDb.getLogByDate(dateStr);
      expect(savedLog, isNotNull);
      expect(savedLog!.durationSeconds, greaterThanOrEqualTo(1));
    });
  });

  group('练习日志', () {
    test('logForDate 返回指定日期的日志', () async {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await mockDb.upsertLog(
        practiceDate: dateStr,
        durationSeconds: 3600,
        note: '音阶练习',
      );
      await controller.init();

      final log = controller.logForDate(now);
      expect(log, isNotNull);
      expect(log!.durationSeconds, equals(3600));
    });

    test('logForDate 无数据时返回 null', () {
      final futureDate = DateTime(2099, 12, 25);
      expect(controller.logForDate(futureDate), isNull);
    });
  });

  group('每日阅读', () {
    test('dailyRead 默认为空', () {
      expect(controller.dailyRead, equals(''));
    });

    test('saveDailyRead 保存文本', () async {
      await controller.saveDailyRead('今日练习：长音训练');
      expect(controller.dailyRead, equals('今日练习：长音训练'));

      final saved = await mockDb.getSetting('daily_read');
      expect(saved, isNotNull);
    });
  });
}
