import 'tuner_reading.dart';

enum ScaleType { major, minor }

class MusicalScale {
  const MusicalScale({required this.root, required this.type});

  final String root;
  final ScaleType type;

  static const _majorIntervals = [0, 2, 4, 5, 7, 9, 11];
  static const _minorIntervals = [0, 2, 3, 5, 7, 8, 10];

  String get label => '$root ${type == ScaleType.major ? 'Major' : 'Minor'}';

  Set<int> noteIndices() {
    final rootIdx = noteNames.indexOf(root);
    if (rootIdx < 0) return {0, 2, 4, 5, 7, 9, 11};
    final intervals = type == ScaleType.major
        ? _majorIntervals
        : _minorIntervals;
    return intervals.map((i) => (rootIdx + i) % 12).toSet();
  }

  Map<String, dynamic> toJson() => {'root': root, 'type': type.name};

  factory MusicalScale.fromJson(Map<String, dynamic> json) {
    return MusicalScale(
      root: json['root'] as String? ?? 'C',
      type: ScaleType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ScaleType.major,
      ),
    );
  }

  static List<MusicalScale> allScales() {
    final list = <MusicalScale>[];
    for (final root in noteNames) {
      list.add(MusicalScale(root: root, type: ScaleType.major));
      list.add(MusicalScale(root: root, type: ScaleType.minor));
    }
    return list;
  }
}
