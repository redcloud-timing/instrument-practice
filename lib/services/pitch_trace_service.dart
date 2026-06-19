import 'dart:async';

import 'package:flutter/services.dart';

import '../models/pitch_reading.dart';
import '../models/pitch_trace_recording.dart';

class PitchTraceException implements Exception {
  const PitchTraceException(this.message);

  final String message;
}

/// 音高轨迹原生服务
///
/// 通过 MethodChannel 与原生平台通信，提供实时音高检测、录音和回放能力。
/// 音高数据通过 EventChannel 以流的形式推送到 Dart 层。
class PitchTraceService {
  static const MethodChannel _methodChannel = MethodChannel(
    'flute_practice/pitch_trace',
  );
  static const EventChannel _eventChannel = EventChannel(
    'flute_practice/pitch_trace_events',
  );

  Stream<PitchReading>? _readings;

  Stream<PitchReading> get readings {
    _readings ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) {
          return event is Map;
        })
        .map((event) {
          return PitchReading.fromMap(Map<Object?, Object?>.from(event as Map));
        });

    return _readings!;
  }

  Future<void> start({
    required double minFrequency,
    required double maxFrequency,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('start', {
        'minFrequency': minFrequency,
        'maxFrequency': maxFrequency,
      });
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '启动音高轨迹失败。');
    }
  }

  Future<String?> stop() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('stop');
      return result?['recordingPath'] as String?;
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '停止音高轨迹失败。');
    }
  }

  Future<List<PitchTraceRecording>> listRecordings() async {
    try {
      final result = await _methodChannel.invokeMethod<List>('listRecordings');
      if (result == null) return [];
      return result.map((item) {
        final m = Map<String, Object?>.from(item as Map);
        return PitchTraceRecording(
          path: m['path'] as String,
          name: m['name'] as String,
          sizeBytes: m['sizeBytes'] as int,
          lastModified: m['lastModified'] as int,
          durationSeconds: m['durationSeconds'] as int,
        );
      }).toList();
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '获取录音列表失败。');
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      await _methodChannel.invokeMethod<void>('deleteRecording', {
        'path': path,
      });
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '删除录音失败。');
    }
  }

  Future<String?> playRecording(String path) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('playRecording', {
        'path': path,
      });
      return result?['name'] as String?;
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '播放录音失败。');
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _methodChannel.invokeMethod<void>('stopPlayback');
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '停止播放失败。');
    }
  }

  Future<void> pausePlayback() async {
    try {
      await _methodChannel.invokeMethod<void>('pausePlayback');
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '暂停播放失败。');
    }
  }

  Future<void> resumePlayback() async {
    try {
      await _methodChannel.invokeMethod<void>('resumePlayback');
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '继续播放失败。');
    }
  }

  Future<void> seekPlayback(int positionMs) async {
    try {
      await _methodChannel.invokeMethod<void>('seekPlayback', {
        'positionMs': positionMs,
      });
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '跳转播放失败。');
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _methodChannel.invokeMethod<void>('pauseRecording');
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '暂停录音失败。');
    }
  }

  Future<void> resumeRecording() async {
    try {
      await _methodChannel.invokeMethod<void>('resumeRecording');
    } on PlatformException catch (error) {
      throw PitchTraceException(error.message ?? '继续录音失败。');
    }
  }
}
