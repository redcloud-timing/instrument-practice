import 'package:flutter/services.dart';

import '../models/metronome_preset.dart';

enum MetronomeSoundRole { downbeat, upbeat, subdivision, rest }

/// 节拍器音效服务
///
/// 通过 MethodChannel 调用原生音频播放，支持多种音效风格和震动反馈。
class MetronomeSoundService {
  static const MethodChannel _channel = MethodChannel(
    'flute_practice/metronome',
  );

  Future<void> playTick({
    required MetronomeSoundRole role,
    required MetronomeSoundStyle soundStyle,
    required bool vibrate,
  }) async {
    if (role == MetronomeSoundRole.rest && !vibrate) return;

    try {
      await _channel.invokeMethod<void>('tick', {
        'role': role.name,
        'soundStyle': soundStyle.name,
        'vibrate': vibrate,
      });
    } on PlatformException {
      if (role != MetronomeSoundRole.rest &&
          soundStyle != MetronomeSoundStyle.silent) {
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }
}
