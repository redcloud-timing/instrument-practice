import 'dart:math' as math;

const noteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

const defaultReferenceA4Hz = 440.0;

/// 音高读数
///
/// 表示单次音高检测结果，包含频率、振幅和清晰度。
/// 提供 MIDI 音符换算、音名查询和音分偏差计算。
class PitchReading {
  const PitchReading({
    required this.frequency,
    required this.amplitude,
    required this.clarity,
    required this.timestampMillis,
  });

  final double frequency;
  final double amplitude;
  final double clarity;
  final int timestampMillis;

  bool get hasPitch => frequency > 0;

  int midiNumberFor(double referenceA4Hz) {
    if (!hasPitch) return 0;
    final cleanReference = referenceA4Hz > 0
        ? referenceA4Hz
        : defaultReferenceA4Hz;
    return (69 + 12 * math.log(frequency / cleanReference) / math.ln2).round();
  }

  double targetFrequencyFor(double referenceA4Hz) {
    if (!hasPitch) return 0;
    final cleanReference = referenceA4Hz > 0
        ? referenceA4Hz
        : defaultReferenceA4Hz;
    return (cleanReference *
            math.pow(2, (midiNumberFor(cleanReference) - 69) / 12))
        .toDouble();
  }

  int centsFor(double referenceA4Hz) {
    final target = targetFrequencyFor(referenceA4Hz);
    if (!hasPitch || target <= 0) return 0;
    return (1200 * math.log(frequency / target) / math.ln2).round();
  }

  String noteNameFor(double referenceA4Hz) {
    if (!hasPitch) return '--';
    return noteNames[midiNumberFor(referenceA4Hz) % 12];
  }

  int octaveFor(double referenceA4Hz) {
    if (!hasPitch) return 0;
    return (midiNumberFor(referenceA4Hz) ~/ 12) - 1;
  }

  String noteLabelFor(double referenceA4Hz) {
    if (!hasPitch) return '--';
    return '${noteNameFor(referenceA4Hz)}${octaveFor(referenceA4Hz)}';
  }

  bool isInTuneFor(double referenceA4Hz) {
    return hasPitch && centsFor(referenceA4Hz).abs() <= 5;
  }

  int get midiNumber => midiNumberFor(defaultReferenceA4Hz);

  double get targetFrequency => targetFrequencyFor(defaultReferenceA4Hz);

  int get cents => centsFor(defaultReferenceA4Hz);

  String get noteName => noteNameFor(defaultReferenceA4Hz);

  int get octave => octaveFor(defaultReferenceA4Hz);

  String get noteLabel => noteLabelFor(defaultReferenceA4Hz);

  bool get isInTune => isInTuneFor(defaultReferenceA4Hz);

  String get directionLabel {
    if (!hasPitch) return '没有音高数据';
    if (isInTune) return '音高接近参考线';
    return cents < 0 ? '低于参考线' : '高于参考线';
  }

  factory PitchReading.fromMap(Map<Object?, Object?> map) {
    return PitchReading(
      frequency: _readDouble(map['frequency']),
      amplitude: _readDouble(map['amplitude']),
      clarity: _readDouble(map['clarity']),
      timestampMillis: _readInt(map['timestampMillis']),
    );
  }

  static double _readDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0;
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
