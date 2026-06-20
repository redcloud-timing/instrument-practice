/// 栏目模型
///
/// 表示一个自定义栏目，用于对乐谱进行分类。
class LibraryCategory {
  const LibraryCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAtIso,
  });

  final int id;
  final String name;
  final int sortOrder;
  final String createdAtIso;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'created_at': createdAtIso,
    };
  }

  factory LibraryCategory.fromMap(Map<String, dynamic> map) {
    return LibraryCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAtIso: map['created_at'] as String,
    );
  }

  LibraryCategory copyWith({
    int? id,
    String? name,
    int? sortOrder,
    String? createdAtIso,
  }) {
    return LibraryCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAtIso: createdAtIso ?? this.createdAtIso,
    );
  }
}
