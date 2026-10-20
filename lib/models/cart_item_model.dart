/// Model sản phẩm trong giỏ hàng (Collection `carts`)
/// Khóa `cartItemId` phân biệt theo quy tắc: `${productId}_${size}_${color}`
class CartItemModel {
  final String cartItemId;
  final String productId;
  final String productName;
  final String imageUrl;
  final num price;
  final String size;
  final String color;
  final int quantity;

  const CartItemModel({
    required this.cartItemId,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.price,
    required this.size,
    required this.color,
    required this.quantity,
  });

  /// Tổng tiền của dòng sản phẩm này
  num get itemTotal => price * quantity;

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      cartItemId: map['cartItemId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      price: (map['price'] as num?) ?? 0,
      size: map['size'] as String? ?? '',
      color: map['color'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cartItemId': cartItemId,
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'price': price,
      'size': size,
      'color': color,
      'quantity': quantity,
    };
  }

  CartItemModel copyWith({
    String? cartItemId,
    String? productId,
    String? productName,
    String? imageUrl,
    num? price,
    String? size,
    String? color,
    int? quantity,
  }) {
    return CartItemModel(
      cartItemId: cartItemId ?? this.cartItemId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      size: size ?? this.size,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemModel &&
          runtimeType == other.runtimeType &&
          cartItemId == other.cartItemId;

  @override
  int get hashCode => cartItemId.hashCode;
}
