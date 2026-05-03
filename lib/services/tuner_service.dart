import 'dart:async';

import 'package:flutter/services.dart';

import '../models/tuner_reading.dart';

class TunerException implements Exception {
  const TunerException(this.message);

  final String message;
}

class TunerRecording {
  const TunerRecording({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    required this.durationSeconds,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final int lastModified;
  final int durationSeconds;
}

class TunerService {
  static const MethodChannel _methodChannel = MethodChannel(
    'flute_practice/tuner',
  );
  static const EventChannel _eventChannel = EventChannel(
    'flute_practice/tuner_events',
  );

  Stream<TunerReading>? _readings;

  Stream<TunerReading> get readings {
    _readings ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) {
          return event is Map;
        })
        .map((event) {
          return TunerReading.fromMap(Map<Object?, Object?>.from(event as Map));
        });

    return _readings!;
  }

  Future<void> start() async {
    try {
      await _methodChannel.invokeMethod<void>('start');
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '启动调音器失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持调音器。');
    }
  }

  Future<String?> stop() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('stop');
      return result?['recordingPath'] as String?;
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '停止调音器失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持调音器。');
    }
  }

  Future<List<TunerRecording>> listRecordings() async {
    try {
      final result = await _methodChannel.invokeMethod<List>('listRecordings');
      if (result == null) return [];
      return result.map((item) {
        final m = Map<String, Object?>.from(item as Map);
        return TunerRecording(
          path: m['path'] as String,
          name: m['name'] as String,
          sizeBytes: m['sizeBytes'] as int,
          lastModified: m['lastModified'] as int,
          durationSeconds: m['durationSeconds'] as int,
        );
      }).toList();
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '获取录音列表失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音管理。');
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      await _methodChannel.invokeMethod<void>('deleteRecording', {
        'path': path,
      });
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '删除录音失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音管理。');
    }
  }

  Future<String?> playRecording(String path) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('playRecording', {
        'path': path,
      });
      return result?['name'] as String?;
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '播放录音失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音播放。');
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _methodChannel.invokeMethod<void>('stopPlayback');
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '停止播放失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音播放。');
    }
  }

  Future<void> pausePlayback() async {
    try {
      await _methodChannel.invokeMethod<void>('pausePlayback');
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '暂停播放失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音播放。');
    }
  }

  Future<void> resumePlayback() async {
    try {
      await _methodChannel.invokeMethod<void>('resumePlayback');
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '继续播放失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音播放。');
    }
  }

  Future<void> seekPlayback(int positionMs) async {
    try {
      await _methodChannel.invokeMethod<void>('seekPlayback', {
        'positionMs': positionMs,
      });
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '跳转播放失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音播放。');
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _methodChannel.invokeMethod<void>('pauseRecording');
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '暂停录音失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持录音暂停。');
    }
  }

  Future<void> resumeRecording() async {
    try {
      await _methodChannel.invokeMethod<void>('resumeRecording');
    } on PlatformException catch (error) {
      throw TunerException(error.message ?? '继续录音失败。');
    } on MissingPluginException {
      throw const TunerException('当前设备不支持恢复录音。');
    }
  }
}
