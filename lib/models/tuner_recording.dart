class TunerRecording {
  const TunerRecording({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    required this.durationSeconds,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final int lastModified;
  final int durationSeconds;
}
