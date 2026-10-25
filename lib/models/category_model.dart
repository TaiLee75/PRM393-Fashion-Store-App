/// Model danh mục sản phẩm thời trang (Collection `categories`)
class CategoryModel {
  final String id;
  final String name;
  final String iconUrl;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconUrl,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return CategoryModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      iconUrl: map['iconUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? iconUrl,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
