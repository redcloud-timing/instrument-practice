import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/models/metronome_preset.dart';

void main() {
  group('BeatType', () {
    test('fromValue 正确映射', () {
      expect(BeatType.fromValue(0), equals(BeatType.rest));
      expect(BeatType.fromValue(1), equals(BeatType.normal));
      expect(BeatType.fromValue(2), equals(BeatType.accent));
      expect(BeatType.fromValue(3), equals(BeatType.subaccent));
    });

    test('fromValue 未知值返回 normal', () {
      expect(BeatType.fromValue(99), equals(BeatType.normal));
    });

    test('next 循环正确', () {
      expect(BeatType.accent.next, equals(BeatType.subaccent));
      expect(BeatType.subaccent.next, equals(BeatType.normal));
      expect(BeatType.normal.next, equals(BeatType.rest));
      expect(BeatType.rest.next, equals(BeatType.accent));
    });

    test('value 循环对称', () {
      for (final beat in BeatType.values) {
        expect(BeatType.fromValue(beat.value), equals(beat));
      }
    });
  });

  group('MetronomePreset', () {
    test('toMap / fromMap 对称', () {
      const preset = MetronomePreset(
        name: '4/4 标准',
        bpm: 120,
        beats: [BeatType.accent, BeatType.normal, BeatType.normal, BeatType.normal],
        subdivisionBeats: [[], [], [], []],
      );

      final restored = MetronomePreset.fromMap(preset.toMap());

      expect(restored.name, equals(preset.name));
      expect(restored.bpm, equals(preset.bpm));
      expect(restored.beats, equals(preset.beats));
      expect(restored.subdivisionBeats, equals(preset.subdivisionBeats));
    });

    test('fromMap 缺失字段使用默认值', () {
      final preset = MetronomePreset.fromMap({});

      expect(preset.name, equals(''));
      expect(preset.bpm, equals(80));
      expect(preset.beats.length, equals(4));
      expect(preset.beats[0], equals(BeatType.accent));
    });

    test('fromMap subdivisionBeats 非 List 时使用空列表', () {
      final preset = MetronomePreset.fromMap({
        'name': 'test',
        'bpm': 100,
        'beats': [2, 1, 1, 1],
        'subdivisionBeats': 'invalid',
      });

      expect(preset.subdivisionBeats, isEmpty);
    });
  });
}
