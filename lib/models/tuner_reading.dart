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

class TunerReading {
  const TunerReading({
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

  int get midiNumber {
    if (!hasPitch) return 0;
    return (69 + 12 * math.log(frequency / 440) / math.ln2).round();
  }

  double get targetFrequency {
    if (!hasPitch) return 0;
    return (440 * math.pow(2, (midiNumber - 69) / 12)).toDouble();
  }

  int get cents {
    if (!hasPitch || targetFrequency <= 0) return 0;
    return (1200 * math.log(frequency / targetFrequency) / math.ln2).round();
  }

  String get noteName {
    if (!hasPitch) return '--';
    return noteNames[midiNumber % 12];
  }

  int get octave {
    if (!hasPitch) return 0;
    return (midiNumber ~/ 12) - 1;
  }

  String get noteLabel {
    if (!hasPitch) return '--';
    return '$noteName$octave';
  }

  bool get isInTune => hasPitch && cents.abs() <= 5;

  String get directionLabel {
    if (!hasPitch) return '请吹奏一个稳定长音';
    if (isInTune) return '音准稳定';
    return cents < 0 ? '偏低' : '偏高';
  }

  factory TunerReading.fromMap(Map<Object?, Object?> map) {
    return TunerReading(
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
