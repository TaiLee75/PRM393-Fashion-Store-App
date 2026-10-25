import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đánh giá sản phẩm từ người mua (Review)
class ReviewModel {
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String orderId;
  final String variantInfo; // Ví dụ: "Phân loại: Size L, Màu Đen"
  final bool isVerifiedPurchase;

  const ReviewModel({
    this.userId = '',
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.orderId = '',
    this.variantInfo = '',
    this.isVerifiedPurchase = false,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    return ReviewModel(
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Khách hàng',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      orderId: map['orderId'] as String? ?? '',
      variantInfo: map['variantInfo'] as String? ?? '',
      isVerifiedPurchase: map['isVerifiedPurchase'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'orderId': orderId,
      'variantInfo': variantInfo,
      'isVerifiedPurchase': isVerifiedPurchase,
    };
  }

  ReviewModel copyWith({
    String? userId,
    String? userName,
    double? rating,
    String? comment,
    DateTime? createdAt,
    String? orderId,
    String? variantInfo,
    bool? isVerifiedPurchase,
  }) {
    return ReviewModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      variantInfo: variantInfo ?? this.variantInfo,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          orderId == other.orderId &&
          comment == other.comment &&
          createdAt == other.createdAt);

  @override
  int get hashCode => Object.hash(userId, orderId, comment, createdAt);
}

/// Model sản phẩm quần áo thời trang (Collection `products`)
class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final num price;
  final num? originalPrice; // Giá niêm yết trước khuyến mãi (nếu có)
  final String description;
  final List<String> imageUrls;
  final List<String> sizes;
  final List<String> colors;
  final int stock; // Tổng tồn kho
  final Map<String, int> variantStock; // Tồn kho theo từng SKU: {"S_Trắng": 10, "M_Đen": 15}
  final int soldCount; // Số lượng đã bán thực tế
  final bool isActive; // Trạng thái đang kinh doanh (true) hay ngừng bán (false)
  final double rating;
  final List<ReviewModel> reviews;

  const ProductModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    this.originalPrice,
    required this.description,
    required this.imageUrls,
    required this.sizes,
    required this.colors,
    this.stock = 99,
    this.variantStock = const {},
    this.soldCount = 0,
    this.isActive = true,
    this.rating = 5.0,
    this.reviews = const [],
  });

  /// Ảnh chính đại diện của sản phẩm
  String get mainImage => imageUrls.isNotEmpty ? imageUrls.first : '';

  /// Kiểm tra sản phẩm có đang được giảm giá hay không
  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  /// Phần trăm giảm giá (nếu có giá gốc)
  int get discountPercent => hasDiscount
      ? (((originalPrice! - price) / originalPrice!) * 100).round()
      : 0;

  /// Tổng tồn kho thực tế (ưu tiên cộng từ các biến thể nếu có)
  int get effectiveStock {
    if (variantStock.isNotEmpty) {
      return variantStock.values.fold<int>(0, (total, qty) => total + qty);
    }
    return stock;
  }

  /// Lấy tồn kho của một biến thể cụ thể (Size + Màu tùy chọn).
  /// - Nếu sản phẩm có `variantStock`:
  ///   + Truyền cả `size` và `color`: trả về số lượng chính xác của SKU đó (hoặc 0 nếu SKU không tồn tại).
  ///   + Chỉ truyền `size`: trả về tổng tồn kho của toàn bộ các màu thuộc size đó.
  /// - Nếu sản phẩm không có `variantStock` (dữ liệu cũ): trả về `stock` chung.
  int getStockForVariant(String size, [String? color]) {
    if (variantStock.isEmpty) return stock;

    if (color != null && color.isNotEmpty) {
      final key = '${size}_$color';
      if (variantStock.containsKey(key)) {
        return variantStock[key] ?? 0;
      }
      if (variantStock.containsKey(size)) {
        return variantStock[size] ?? 0;
      }
      return 0; // Đã quản lý theo biến thể nhưng không tồn tại SKU này
    }

    if (variantStock.containsKey(size)) {
      return variantStock[size] ?? 0;
    }

    // Tính tổng tồn kho của tất cả màu thuộc size này
    final matchingStock = variantStock.entries
        .where((e) => e.key.startsWith('${size}_'))
        .fold<int>(0, (total, e) => total + e.value);

    return matchingStock;
  }

  /// Kiểm tra hết hàng:
  /// - `isOutOfStock()`: Kiểm tra toàn bộ sản phẩm đã hết hàng chưa.
  /// - `isOutOfStock('M')`: Kiểm tra size M đã hết sạch hàng ở tất cả các màu chưa.
  /// - `isOutOfStock('M', 'Đen')`: Kiểm tra riêng biến thể Size M - Màu Đen.
  bool isOutOfStock([String? size, String? color]) {
    if (size != null) {
      return getStockForVariant(size, color) <= 0;
    }
    return effectiveStock <= 0;
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, [String? id]) {
    // Parse danh sách đánh giá an toàn kể cả khi Firestore trả về Map<dynamic, dynamic>
    final List<ReviewModel> parsedReviews = [];
    if (map['reviews'] is List) {
      for (final item in map['reviews'] as List) {
        if (item is Map) {
          parsedReviews.add(ReviewModel.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Parse variantStock an toàn chống lỗi ép kiểu _Map<dynamic, dynamic>
    final Map<String, int> parsedVariantStock = {};
    if (map['variantStock'] is Map) {
      (map['variantStock'] as Map).forEach((key, value) {
        if (value is num) {
          parsedVariantStock[key.toString()] = value.toInt();
        }
      });
    }

    int parsedStock = (map['stock'] as num?)?.toInt() ?? 99;
    if (map['stock'] == null && parsedVariantStock.isNotEmpty) {
      parsedStock =
          parsedVariantStock.values.fold<int>(0, (total, qty) => total + qty);
    }

    return ProductModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      price: (map['price'] as num?) ?? 0,
      originalPrice: map['originalPrice'] as num?,
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
      stock: parsedStock,
      variantStock: parsedVariantStock,
      soldCount: (map['soldCount'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
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
      'originalPrice': originalPrice,
      'description': description,
      'imageUrls': imageUrls,
      'sizes': sizes,
      'colors': colors,
      'stock': effectiveStock,
      'variantStock': variantStock,
      'soldCount': soldCount,
      'isActive': isActive,
      'rating': rating,
      'reviews': reviews.map((r) => r.toMap()).toList(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    num? price,
    num? originalPrice,
    String? description,
    List<String>? imageUrls,
    List<String>? sizes,
    List<String>? colors,
    int? stock,
    Map<String, int>? variantStock,
    int? soldCount,
    bool? isActive,
    double? rating,
    List<ReviewModel>? reviews,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      sizes: sizes ?? this.sizes,
      colors: colors ?? this.colors,
      stock: stock ?? this.stock,
      variantStock: variantStock ?? this.variantStock,
      soldCount: soldCount ?? this.soldCount,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
