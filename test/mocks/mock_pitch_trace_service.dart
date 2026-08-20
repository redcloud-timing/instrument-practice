import 'dart:async';

import 'package:flute_practice/models/pitch_reading.dart';
import 'package:flute_practice/models/pitch_trace_recording.dart';
import 'package:flute_practice/services/pitch_trace_service.dart';

class MockPitchTraceService implements PitchTraceService {
  final _controller = StreamController<PitchReading>.broadcast();
  final _playbackCompleteController = StreamController<void>.broadcast();
  bool isStarted = false;
  String? stoppedPath;

  @override
  Stream<PitchReading> get readings => _controller.stream;

  @override
  Stream<void> get onPlaybackComplete => _playbackCompleteController.stream;

  @override
  Future<void> start({
    required double minFrequency,
    required double maxFrequency,
    int windowSize = 2048,
    double overlapRatio = 0.5,
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
  Future<Map<String, dynamic>?> playRecording(String path) async {
    return {'name': 'mock.wav', 'durationMs': 1000};
  }

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

  @override
  void dispose() {
    _controller.close();
    _playbackCompleteController.close();
  }
}
