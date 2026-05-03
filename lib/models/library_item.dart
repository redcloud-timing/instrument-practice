class LibraryItem {
  const LibraryItem({
    required this.uri,
    required this.title,
    required this.mimeType,
    required this.addedAtIso,
    required this.openedAtIso,
    required this.isFavorite,
    required this.note,
    this.sizeBytes,
  });

  final String uri;
  final String title;
  final String mimeType;
  final String addedAtIso;
  final String openedAtIso;
  final bool isFavorite;
  final String note;
  final int? sizeBytes;

  bool get isPdf => mimeType == 'application/pdf';

  bool get isImage => mimeType.startsWith('image/');

  String get typeLabel {
    if (isPdf) return 'PDF';
    if (isImage) return '图片';
    return '文件';
  }

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return '';

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).ceil()} KB';
    }

    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get openedAtLabel {
    final value = DateTime.tryParse(openedAtIso)?.toLocal();
    if (value == null) return '未打开';

    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}月${value.day}日 ${value.hour}:$minute';
  }

  LibraryItem copyWith({
    String? uri,
    String? title,
    String? mimeType,
    String? addedAtIso,
    String? openedAtIso,
    bool? isFavorite,
    String? note,
    int? sizeBytes,
  }) {
    return LibraryItem(
      uri: uri ?? this.uri,
      title: title ?? this.title,
      mimeType: mimeType ?? this.mimeType,
      addedAtIso: addedAtIso ?? this.addedAtIso,
      openedAtIso: openedAtIso ?? this.openedAtIso,
      isFavorite: isFavorite ?? this.isFavorite,
      note: note ?? this.note,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'uri': uri,
      'title': title,
      'mimeType': mimeType,
      'addedAtIso': addedAtIso,
      'openedAtIso': openedAtIso,
      'isFavorite': isFavorite,
      'note': note,
      'sizeBytes': sizeBytes,
    };
  }

  factory LibraryItem.fromMap(Map<String, dynamic> map) {
    return LibraryItem(
      uri: (map['uri'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '未命名资料').trim(),
      mimeType: (map['mimeType'] as String? ?? 'application/pdf').trim(),
      addedAtIso: (map['addedAtIso'] as String? ?? '').trim(),
      openedAtIso: (map['openedAtIso'] as String? ?? '').trim(),
      isFavorite: map['isFavorite'] as bool? ?? false,
      note: (map['note'] as String? ?? '').trim(),
      sizeBytes: _readInt(map['sizeBytes']),
    );
  }

  factory LibraryItem.fromPickedMap(
    Map<Object?, Object?> map, {
    required String addedAtIso,
    required String openedAtIso,
  }) {
    return LibraryItem(
      uri: (map['uri'] as String? ?? '').trim(),
      title: (map['name'] as String? ?? '未命名资料').trim(),
      mimeType: (map['mimeType'] as String? ?? 'application/pdf').trim(),
      addedAtIso: addedAtIso,
      openedAtIso: openedAtIso,
      isFavorite: false,
      note: '',
      sizeBytes: _readInt(map['sizeBytes']),
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
