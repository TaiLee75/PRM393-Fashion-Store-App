import 'package:cloud_firestore/cloud_firestore.dart';

/// Model tin nhắn hỗ trợ tư vấn trực tuyến (Sub-collection `messages` trong `chats`)
class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  // Đính kèm ngữ cảnh tư vấn (Order / Product Cards)
  final String? orderId; // Đính kèm đơn hàng khách đang hỏi
  final num? orderTotalPrice; // Tổng tiền đơn hàng đính kèm
  final String? productId; // Đính kèm mã sản phẩm khách đang xem
  final String? productName; // Tên sản phẩm đính kèm
  final String? productImageUrl; // Ảnh sản phẩm đính kèm

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.orderId,
    this.orderTotalPrice,
    this.productId,
    this.productName,
    this.productImageUrl,
  });

  /// Kiểm tra tin nhắn có phải do người dùng hiện tại gửi hay không
  bool isSentBy(String currentUserId) => senderId == currentUserId;

  /// Kiểm tra tin nhắn có đính kèm thẻ đơn hàng hay không
  bool get hasOrderAttachment => orderId != null && orderId!.isNotEmpty;

  /// Kiểm tra tin nhắn có đính kèm thẻ sản phẩm hay không
  bool get hasProductAttachment =>
      (productName != null && productName!.isNotEmpty) ||
      (productId != null && productId!.isNotEmpty);

  factory MessageModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    return MessageModel(
      id: id ?? map['id'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      orderId: map['orderId'] as String?,
      orderTotalPrice: map['orderTotalPrice'] as num?,
      productId: map['productId'] as String?,
      productName: map['productName'] as String?,
      productImageUrl: map['productImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'orderId': orderId,
      'orderTotalPrice': orderTotalPrice,
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    DateTime? createdAt,
    String? orderId,
    num? orderTotalPrice,
    String? productId,
    String? productName,
    String? productImageUrl,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      orderTotalPrice: orderTotalPrice ?? this.orderTotalPrice,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageModel &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
