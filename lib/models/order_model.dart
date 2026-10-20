import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';

/// Model đơn đặt hàng (Collection `orders`)
class OrderModel {
  final String orderId;
  final String userId;
  final String userName;
  final String phone;
  final String shippingAddress;
  final List<CartItemModel> items;
  final num subtotal;
  final String voucherCode;
  final num discountAmount;
  final num totalPrice;
  final String paymentMethod; // "COD" hoặc "VIETQR"
  final String status; // "Pending" -> "Delivering" -> "Delivered"
  final DateTime createdAt;

  const OrderModel({
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.shippingAddress,
    required this.items,
    required this.subtotal,
    this.voucherCode = '',
    this.discountAmount = 0,
    required this.totalPrice,
    this.paymentMethod = 'COD',
    this.status = 'Pending',
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    final List<dynamic>? rawItems = map['items'] as List<dynamic>?;
    final List<CartItemModel> parsedItems = rawItems != null
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map((item) => CartItemModel.fromMap(item))
            .toList()
        : [];

    return OrderModel(
      orderId: id ?? map['orderId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      shippingAddress: map['shippingAddress'] as String? ?? '',
      items: parsedItems,
      subtotal: (map['subtotal'] as num?) ?? 0,
      voucherCode: map['voucherCode'] as String? ?? '',
      discountAmount: (map['discountAmount'] as num?) ?? 0,
      totalPrice: (map['totalPrice'] as num?) ?? 0,
      paymentMethod: map['paymentMethod'] as String? ?? 'COD',
      status: map['status'] as String? ?? 'Pending',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'phone': phone,
      'shippingAddress': shippingAddress,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'voucherCode': voucherCode,
      'discountAmount': discountAmount,
      'totalPrice': totalPrice,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  OrderModel copyWith({
    String? orderId,
    String? userId,
    String? userName,
    String? phone,
    String? shippingAddress,
    List<CartItemModel>? items,
    num? subtotal,
    String? voucherCode,
    num? discountAmount,
    num? totalPrice,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      phone: phone ?? this.phone,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      voucherCode: voucherCode ?? this.voucherCode,
      discountAmount: discountAmount ?? this.discountAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
