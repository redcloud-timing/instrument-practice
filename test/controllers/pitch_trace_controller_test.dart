import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/controllers/pitch_trace_controller.dart';

import '../mocks/mock_database_service.dart';
import '../mocks/mock_pitch_trace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService mockDb;
  late MockPitchTraceService mockPitchService;
  late PitchTraceController controller;

  setUp(() async {
    mockDb = MockDatabaseService();
    mockPitchService = MockPitchTraceService();
    controller = PitchTraceController(mockDb, mockPitchService);
    await controller.init();
  });

  tearDown(() {
    controller.dispose();
    mockPitchService.dispose();
  });

  group('PitchTraceController 初始化', () {
    test('初始状态未运行', () {
      expect(controller.isRunning, isFalse);
    });

    test('初始 history 为空', () {
      expect(controller.history, isEmpty);
    });

    test('初始无错误', () {
      expect(controller.errorMessage, isNull);
    });

    test('默认最小频率为 80 Hz', () {
      expect(controller.minFrequency, equals(80.0));
    });

    test('默认最大频率为 2200 Hz', () {
      expect(controller.maxFrequency, equals(2200.0));
    });
  });

  group('启停控制', () {
    test('start 启动原生服务', () async {
      await controller.start();
      expect(controller.isRunning, isTrue);
      expect(mockPitchService.isStarted, isTrue);
    });

    test('stop 停止原生服务', () async {
      await controller.start();
      await controller.stop();
      expect(controller.isRunning, isFalse);
      expect(mockPitchService.isStarted, isFalse);
    });

    test('重复 start 不报错', () async {
      await controller.start();
      await controller.start();
      expect(controller.isRunning, isTrue);
    });
  });

  group('频率范围设置', () {
    test('setFrequencyRange 更新频率范围', () {
      controller.setFrequencyRange(100.0, 2000.0);
      expect(controller.minFrequency, equals(100.0));
      expect(controller.maxFrequency, equals(2000.0));
    });

    test('setFrequencyRange 限制最小边界', () {
      controller.setFrequencyRange(10.0, 2000.0);
      expect(
        controller.minFrequency,
        equals(PitchTraceController.minAllowedFrequency),
      );
    });

    test('setFrequencyRange 限制最大边界', () {
      controller.setFrequencyRange(100.0, 5000.0);
      expect(
        controller.maxFrequency,
        equals(PitchTraceController.maxAllowedFrequency),
      );
    });

    test('resetFrequencyRange 恢复默认值', () {
      controller.setFrequencyRange(100.0, 2000.0);
      controller.resetFrequencyRange();
      expect(controller.minFrequency, equals(80.0));
      expect(controller.maxFrequency, equals(2200.0));
    });
  });
}
