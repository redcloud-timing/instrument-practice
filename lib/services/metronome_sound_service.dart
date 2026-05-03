import 'package:flutter/services.dart';

import '../models/metronome_preset.dart';

enum MetronomeSoundRole { downbeat, upbeat, subdivision, rest }

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
    } on MissingPluginException {
      if (role != MetronomeSoundRole.rest &&
          soundStyle != MetronomeSoundStyle.silent) {
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }
}
