import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đánh giá sản phẩm từ người mua
class ReviewModel {
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    return ReviewModel(
      userName: map['userName'] as String? ?? 'Khách hàng',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Model sản phẩm quần áo thời trang (Collection `products`)
class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final num price;
  final String description;
  final List<String> imageUrls;
  final List<String> sizes;
  final List<String> colors;
  final double rating;
  final List<ReviewModel> reviews;

  const ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.description,
    required this.imageUrls,
    required this.sizes,
    required this.colors,
    this.rating = 5.0,
    this.reviews = const [],
  });

  String get mainImage => imageUrls.isNotEmpty ? imageUrls.first : '';

  factory ProductModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final List<dynamic>? rawReviews = map['reviews'] as List<dynamic>?;
    final List<ReviewModel> parsedReviews = rawReviews != null
        ? rawReviews
            .whereType<Map<String, dynamic>>()
            .map((r) => ReviewModel.fromMap(r))
            .toList()
        : [];

    return ProductModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      price: (map['price'] as num?) ?? 0,
      description: map['description'] as String? ?? '',
      imageUrls: (map['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      sizes: (map['sizes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      colors: (map['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviews: parsedReviews,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'price': price,
      'description': description,
      'imageUrls': imageUrls,
      'sizes': sizes,
      'colors': colors,
      'rating': rating,
      'reviews': reviews.map((r) => r.toMap()).toList(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    num? price,
    String? description,
    List<String>? imageUrls,
    List<String>? sizes,
    List<String>? colors,
    double? rating,
    List<ReviewModel>? reviews,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      sizes: sizes ?? this.sizes,
      colors: colors ?? this.colors,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
    );
  }
}
