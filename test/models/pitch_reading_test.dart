import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/models/pitch_reading.dart';

void main() {
  group('PitchReading', () {
    test('hasPitch 为 false 当频率为 0', () {
      const reading = PitchReading(
        frequency: 0,
        amplitude: 0,
        clarity: 0,
        timestampMillis: 0,
      );
      expect(reading.hasPitch, isFalse);
      expect(reading.midiNumberFor(440), equals(0));
    });

    test('A4 音高计算正确（440 Hz = MIDI 69）', () {
      const reading = PitchReading(
        frequency: 440,
        amplitude: 1,
        clarity: 1,
        timestampMillis: 0,
      );
      expect(reading.midiNumberFor(440), equals(69));
      expect(reading.noteNameFor(440), equals('A'));
      expect(reading.centsFor(440), equals(0));
    });

    test('C4 音高计算正确（261.63 Hz = MIDI 60）', () {
      const reading = PitchReading(
        frequency: 261.63,
        amplitude: 1,
        clarity: 1,
        timestampMillis: 0,
      );
      expect(reading.midiNumberFor(440), equals(60));
      expect(reading.noteNameFor(440), equals('C'));
    });

    test('微分音偏差计算', () {
      // A4 + 10 cents ≈ 442.54 Hz
      const reading = PitchReading(
        frequency: 442.54,
        amplitude: 1,
        clarity: 1,
        timestampMillis: 0,
      );
      expect(reading.centsFor(440), closeTo(10, 1));
    });

    test('isInTuneFor 在 ±5 cents 内返回 true', () {
      const reading = PitchReading(
        frequency: 440.5,
        amplitude: 1,
        clarity: 1,
        timestampMillis: 0,
      );
      expect(reading.isInTuneFor(440), isTrue);
    });

    test('isInTuneFor 超出 ±5 cents 返回 false', () {
      const reading = PitchReading(
        frequency: 445,
        amplitude: 1,
        clarity: 1,
        timestampMillis: 0,
      );
      expect(reading.isInTuneFor(440), isFalse);
    });

    test('fromMap 正常解析', () {
      final reading = PitchReading.fromMap({
        'frequency': 440.0,
        'amplitude': 0.8,
        'clarity': 0.95,
        'timestampMillis': 1000,
      });
      expect(reading.frequency, equals(440.0));
      expect(reading.amplitude, equals(0.8));
      expect(reading.clarity, equals(0.95));
      expect(reading.timestampMillis, equals(1000));
    });

    test('fromMap 整数类型兼容', () {
      final reading = PitchReading.fromMap({
        'frequency': 440, // int 而非 double
        'amplitude': 1,
        'clarity': 1,
        'timestampMillis': 1000,
      });
      expect(reading.frequency, equals(440.0));
    });

    test('noteLabel 显示音名+八度', () {
      const reading = PitchReading(
        frequency: 440,
        amplitude: 1,
        clarity: 1,
        timestampMillis: 0,
      );
      expect(reading.noteLabel, equals('A4'));
    });

    test('directionLabel 无音高时返回提示', () {
      const reading = PitchReading(
        frequency: 0,
        amplitude: 0,
        clarity: 0,
        timestampMillis: 0,
      );
      expect(reading.directionLabel, equals('没有音高数据'));
    });
  });
}
