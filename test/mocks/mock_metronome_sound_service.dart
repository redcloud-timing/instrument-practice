import 'package:flute_practice/models/metronome_preset.dart';
import 'package:flute_practice/services/metronome_sound_service.dart';

class MockMetronomeSoundService implements MetronomeSoundService {
  int playCount = 0;
  MetronomeSoundRole? lastRole;
  MetronomeSoundStyle? lastStyle;
  bool? lastVibrate;

  @override
  Future<void> playTick({
    required MetronomeSoundRole role,
    required MetronomeSoundStyle soundStyle,
    required bool vibrate,
  }) async {
    playCount++;
    lastRole = role;
    lastStyle = soundStyle;
    lastVibrate = vibrate;
  }
}
