enum BeatType {
  accent,
  subaccent,
  normal,
  rest;

  String get label {
    switch (this) {
      case BeatType.accent:
        return '强';
      case BeatType.subaccent:
        return '次强';
      case BeatType.normal:
        return '弱';
      case BeatType.rest:
        return '空';
    }
  }

  int get value {
    switch (this) {
      case BeatType.accent:
        return 2;
      case BeatType.subaccent:
        return 3;
      case BeatType.normal:
        return 1;
      case BeatType.rest:
        return 0;
    }
  }

  static BeatType fromValue(int value) {
    switch (value) {
      case 2:
        return BeatType.accent;
      case 3:
        return BeatType.subaccent;
      case 0:
        return BeatType.rest;
      case 1:
      default:
        return BeatType.normal;
    }
  }

  BeatType get next {
    switch (this) {
      case BeatType.accent:
        return BeatType.subaccent;
      case BeatType.subaccent:
        return BeatType.normal;
      case BeatType.normal:
        return BeatType.rest;
      case BeatType.rest:
        return BeatType.accent;
    }
  }
}

enum MetronomeSoundStyle {
  classic,
  wood,
  electronic,
  soft,
  digital,
  warm,
  bright,
  deep,
  silent;

  String get label {
    switch (this) {
      case MetronomeSoundStyle.classic:
        return '经典';
      case MetronomeSoundStyle.wood:
        return '木质';
      case MetronomeSoundStyle.electronic:
        return '电子';
      case MetronomeSoundStyle.soft:
        return '柔和';
      case MetronomeSoundStyle.digital:
        return '数码';
      case MetronomeSoundStyle.warm:
        return '温暖';
      case MetronomeSoundStyle.bright:
        return '明亮';
      case MetronomeSoundStyle.deep:
        return '深沉';
      case MetronomeSoundStyle.silent:
        return '静音';
    }
  }

  static MetronomeSoundStyle fromName(String? name) {
    return MetronomeSoundStyle.values.firstWhere(
      (style) => style.name == name,
      orElse: () => MetronomeSoundStyle.classic,
    );
  }
}

class MetronomePreset {
  const MetronomePreset({
    required this.name,
    required this.bpm,
    required this.beats,
    required this.subdivisionBeats,
  });

  final String name;
  final int bpm;
  final List<BeatType> beats;
  final List<List<BeatType>> subdivisionBeats;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'bpm': bpm,
      'beats': beats.map((beat) => beat.value).toList(),
      'subdivisionBeats': [
        for (final dots in subdivisionBeats)
          dots.map((beat) => beat.value).toList(),
      ],
    };
  }

  factory MetronomePreset.fromMap(Map<String, dynamic> map) {
    final rawBeats = map['beats'];
    final rawSubdivisionBeats = map['subdivisionBeats'];

    return MetronomePreset(
      name: (map['name'] as String? ?? '').trim(),
      bpm: (map['bpm'] as int? ?? 80),
      beats: rawBeats is List
          ? rawBeats
                .map((value) => BeatType.fromValue(value is int ? value : 1))
                .toList()
          : const [
              BeatType.accent,
              BeatType.normal,
              BeatType.normal,
              BeatType.normal,
            ],
      subdivisionBeats: rawSubdivisionBeats is List
          ? [
              for (final row in rawSubdivisionBeats)
                if (row is List)
                  row
                      .map(
                        (value) => BeatType.fromValue(value is int ? value : 1),
                      )
                      .toList()
                else
                  <BeatType>[],
            ]
          : const <List<BeatType>>[
              <BeatType>[],
              <BeatType>[],
              <BeatType>[],
              <BeatType>[],
            ],
    );
  }
}
