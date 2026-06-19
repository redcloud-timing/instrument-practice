import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/controllers/metronome_controller.dart';
import 'package:flute_practice/controllers/pitch_trace_controller.dart';

import '../mocks/mock_database_service.dart';
import '../mocks/mock_metronome_sound_service.dart';
import '../mocks/mock_pitch_trace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetronomeController 生命周期', () {
    late MockDatabaseService mockDb;
    late MockMetronomeSoundService mockSound;
    late MetronomeController controller;

    setUp(() async {
      mockDb = MockDatabaseService();
      mockSound = MockMetronomeSoundService();
      controller = MetronomeController(mockDb, mockSound);
      await controller.init();
      controller.attachLifecycleObserver();
    });

    tearDown(() {
      controller.dispose();
    });

    test('后台暂停：运行中切后台自动停止', () {
      controller.start();
      expect(controller.isRunning, isTrue);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(controller.isRunning, isFalse);
    });

    test('前台恢复：后台暂停后切回前台自动恢复', () {
      controller.start();
      expect(controller.isRunning, isTrue);

      final binding = TestWidgetsFlutterBinding.instance;
      // 进入后台
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(controller.isRunning, isFalse);

      // 回到前台
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.isRunning, isTrue);
    });

    test('手动停止后不自动恢复', () {
      controller.start();
      controller.stop(); // 手动停止
      expect(controller.isRunning, isFalse);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // 手动停止后不应自动恢复
      expect(controller.isRunning, isFalse);
    });

    test('未运行时切后台再恢复，不自动启动', () {
      expect(controller.isRunning, isFalse);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(controller.isRunning, isFalse);
    });

    test('hidden 状态也触发暂停', () {
      controller.start();

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      expect(controller.isRunning, isFalse);
    });
  });

  group('PitchTraceController 生命周期', () {
    late MockDatabaseService mockDb;
    late MockPitchTraceService mockPitchService;
    late PitchTraceController controller;

    setUp(() async {
      mockDb = MockDatabaseService();
      mockPitchService = MockPitchTraceService();
      controller = PitchTraceController(mockDb, mockPitchService);
      await controller.init();
      controller.attachLifecycleObserver();
    });

    tearDown(() {
      controller.dispose();
      mockPitchService.dispose();
    });

    test('后台暂停：运行中切后台自动停止', () async {
      await controller.start();
      expect(controller.isRunning, isTrue);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // 等待异步停止完成
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isRunning, isFalse);
    });

    test('前台恢复：后台暂停后切回前台自动恢复', () async {
      await controller.start();
      expect(controller.isRunning, isTrue);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isRunning, isFalse);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isRunning, isTrue);
    });

    test('手动停止后不自动恢复', () async {
      await controller.start();
      await controller.stop();
      expect(controller.isRunning, isFalse);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.isRunning, isFalse);
    });

    test('未运行时切后台再恢复，不自动启动', () {
      expect(controller.isRunning, isFalse);

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(controller.isRunning, isFalse);
    });
  });
}
