import 'package:cloud_firestore/cloud_firestore.dart';

/// Model thông báo người dùng (Collection `notifications`)
class NotificationModel {
  static const String typeOrderUpdate = 'ORDER_UPDATE';
  static const String typePromotion = 'PROMOTION';
  static const String typeSystem = 'SYSTEM';
  static const String typeOrder = 'order';
  static const String typePayment = 'payment';
  static const String typeChat = 'chat';

  final String id;
  final String userId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? orderId; // Mã đơn hàng liên quan (để điều hướng khi bấm vào)
  final String type; // Loại thông báo: ORDER_UPDATE, PROMOTION, SYSTEM, order, payment, chat

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
    this.orderId,
    this.type = typeSystem,
  });

  /// Kiểm tra có phải thông báo liên quan đến đơn hàng hay không
  bool get isOrderNotification =>
      (orderId != null && orderId!.isNotEmpty) ||
      type == typeOrder ||
      type == typeOrderUpdate;

  /// Kiểm tra có phải thông báo thanh toán hay không
  bool get isPaymentNotification => type.toLowerCase() == typePayment;

  /// Kiểm tra có phải thông báo tin nhắn chat hay không
  bool get isChatNotification => type.toLowerCase() == typeChat;

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    return NotificationModel(
      id: id ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      createdAt: parseDate(map['createdAt']),
      orderId: map['orderId'] as String?,
      type: map['type'] as String? ?? typeSystem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'orderId': orderId,
      'type': type,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    String? orderId,
    String? type,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
