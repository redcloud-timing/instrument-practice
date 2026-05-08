class PitchTraceRecording {
  const PitchTraceRecording({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    required this.durationSeconds,
    this.title = '',
    this.note = '',
  });

  final String path;
  final String name;
  final int sizeBytes;
  final int lastModified;
  final int durationSeconds;
  final String title;
  final String note;

  PitchTraceRecording copyWith({String? title, String? note}) {
    return PitchTraceRecording(
      path: path,
      name: name,
      sizeBytes: sizeBytes,
      lastModified: lastModified,
      durationSeconds: durationSeconds,
      title: title ?? this.title,
      note: note ?? this.note,
    );
  }
}
