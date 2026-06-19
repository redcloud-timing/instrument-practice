import 'dart:async';

import 'package:flute_practice/models/pitch_reading.dart';
import 'package:flute_practice/models/pitch_trace_recording.dart';
import 'package:flute_practice/services/pitch_trace_service.dart';

class MockPitchTraceService implements PitchTraceService {
  final _controller = StreamController<PitchReading>.broadcast();
  bool isStarted = false;
  String? stoppedPath;

  @override
  Stream<PitchReading> get readings => _controller.stream;

  @override
  Future<void> start({
    required double minFrequency,
    required double maxFrequency,
  }) async {
    isStarted = true;
  }

  @override
  Future<String?> stop() async {
    isStarted = false;
    stoppedPath = '/mock/recording.wav';
    return stoppedPath;
  }

  @override
  Future<List<PitchTraceRecording>> listRecordings() async => [];

  @override
  Future<void> deleteRecording(String path) async {}

  @override
  Future<String?> playRecording(String path) async => null;

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> pausePlayback() async {}

  @override
  Future<void> resumePlayback() async {}

  @override
  Future<void> seekPlayback(int positionMs) async {}

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}

  /// 测试辅助：模拟推送音高数据
  void emitReading(PitchReading reading) {
    _controller.add(reading);
  }

  void dispose() {
    _controller.close();
  }
}
