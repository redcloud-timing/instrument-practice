/// 听音录音记录
///
/// 表示一次已完成的听音录音，包含文件路径、时长和用户标注。
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
