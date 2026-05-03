class PracticeLog {
  const PracticeLog({
    this.id,
    required this.practiceDate,
    required this.durationSeconds,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String practiceDate;
  final int durationSeconds;
  final String note;
  final String createdAt;
  final String updatedAt;

  bool get hasPractice => durationSeconds > 0;

  factory PracticeLog.fromMap(Map<String, Object?> map) {
    return PracticeLog(
      id: map['id'] as int?,
      practiceDate: map['practice_date'] as String,
      durationSeconds: (map['duration_seconds'] as int?) ?? 0,
      note: (map['note'] as String?) ?? '',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'practice_date': practiceDate,
      'duration_seconds': durationSeconds,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
