/// 栏目-乐谱关联模型
///
/// 表示一个栏目和一个乐谱的关联关系。
class CategoryItem {
  const CategoryItem({required this.categoryId, required this.itemUri});

  final int categoryId;
  final String itemUri;

  Map<String, dynamic> toMap() {
    return {'category_id': categoryId, 'item_uri': itemUri};
  }

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    return CategoryItem(
      categoryId: map['category_id'] as int,
      itemUri: map['item_uri'] as String,
    );
  }
}
