import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';

/// Model đơn đặt hàng (Collection `orders`) chuẩn Enterprise
class OrderModel {
  // Constants trạng thái vận hành
  static const String statusPending = 'Pending';
  static const String statusDelivering = 'Delivering';
  static const String statusDelivered = 'Delivered';
  static const String statusCancelled = 'Cancelled';
  static const String statusReturnRequested = 'ReturnRequested';
  static const String statusReturned = 'Returned';

  // Constants trạng thái thanh toán
  static const String paymentUnpaid = 'Unpaid';
  static const String paymentSubmitted = 'PaymentSubmitted';
  static const String paymentPaid = 'Paid';
  static const String paymentRefunded = 'Refunded';

  // Constants hình thức nhận hàng
  static const String deliveryMethodShipping = 'DELIVERY';
  static const String deliveryMethodPickup = 'PICKUP';

  final String orderId;
  final String userId;
  final String userName;
  final String phone;
  final String shippingAddress;
  final List<CartItemModel> items;

  // Bóc tách tài chính
  final num subtotal; // Tiền hàng ban đầu
  final String voucherCode;
  final num discountAmount; // Tổng tiền giảm = productDiscount + shippingDiscount
  final num productDiscount; // Giảm giá sản phẩm (SALE10, UNIQLO50K,...)
  final num shippingDiscount; // Giảm phí vận chuyển (FREESHIP)
  final num shippingFee; // Phí giao hàng gốc
  final num totalPrice; // Tiền khách thanh toán: subtotal - productDiscount + (shippingFee - shippingDiscount)

  // Phương thức & Trạng thái thanh toán
  final String paymentMethod; // "COD" hoặc "VIETQR"
  final String paymentStatus; // "Unpaid", "PaymentSubmitted", "Paid", "Refunded"
  final String transactionRef; // Mã giao dịch chuyển khoản VietQR (nếu có)

  // Hình thức nhận hàng
  final String deliveryMethod; // "DELIVERY" (giao hàng) hoặc "PICKUP" (nhận tại quầy)
  final String pickupBranchName; // Tên chi nhánh nhận hàng khi chọn PICKUP
  final String note; // Ghi chú đơn hàng của khách

  // Trạng thái vận hành & Lý do
  final String status; // "Pending", "Delivering", "Delivered", "Cancelled", "ReturnRequested", "Returned"
  final String cancelReason; // Lý do khách hoặc admin hủy đơn
  final String returnReason; // Lý do khách yêu cầu đổi/trả hàng

  // Mốc thời gian kiểm toán (Audit Timestamps)
  final DateTime createdAt;
  final DateTime? deliveringAt; // Thời điểm bắt đầu giao
  final DateTime? deliveredAt; // Thời điểm giao thành công
  final DateTime? cancelledAt; // Thời điểm hủy đơn
  final DateTime? returnedAt; // Thời điểm duyệt trả hàng / hoàn tiền

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
    this.productDiscount = 0,
    this.shippingDiscount = 0,
    this.shippingFee = 0,
    required this.totalPrice,
    this.paymentMethod = 'COD',
    this.paymentStatus = paymentUnpaid,
    this.transactionRef = '',
    this.deliveryMethod = deliveryMethodShipping,
    this.pickupBranchName = '',
    this.note = '',
    this.cancelReason = '',
    this.returnReason = '',
    this.status = statusPending,
    required this.createdAt,
    this.deliveringAt,
    this.deliveredAt,
    this.cancelledAt,
    this.returnedAt,
  });

  // =================== HELPER GETTERS ===================

  /// Đơn hàng đã được thanh toán thành công
  bool get isPaid => paymentStatus == paymentPaid;

  /// Đơn hàng đã được hoàn tiền
  bool get isRefunded => paymentStatus == paymentRefunded;

  /// Khách hàng đã gửi chuyển khoản VietQR và đang chờ Admin đối soát
  bool get isPaymentSubmitted => paymentStatus == paymentSubmitted;

  /// Phương thức thanh toán là VietQR
  bool get isVietQr => paymentMethod == 'VIETQR';

  /// Phương thức thanh toán là COD (tiền mặt khi nhận hàng)
  bool get isCod => paymentMethod == 'COD';

  /// Hình thức nhận tại cửa hàng
  bool get isPickup => deliveryMethod == deliveryMethodPickup;

  /// Hình thức giao hàng tận nơi
  bool get isDelivery => deliveryMethod == deliveryMethodShipping;

  /// Đang ở trạng thái Chờ xử lý
  bool get isPending => status == statusPending;

  /// Đang được giao hàng
  bool get isDelivering => status == statusDelivering;

  /// Đã giao hàng thành công
  bool get isDelivered => status == statusDelivered;

  /// Đã hủy đơn
  bool get isCancelled => status == statusCancelled;

  /// Đang yêu cầu đổi/trả hàng
  bool get isReturnRequested => status == statusReturnRequested;

  /// Đã hoàn trả hàng
  bool get isReturned => status == statusReturned;

  /// Cho phép hủy đơn (Chỉ được hủy khi còn ở trạng thái Pending)
  bool get canCancel => status == statusPending;

  /// Cho phép chỉnh sửa địa chỉ nhận hàng (Chỉ khi Pending và chọn DELIVERY)
  bool get canEditAddress =>
      status == statusPending && deliveryMethod == deliveryMethodShipping;

  /// Cho phép gửi yêu cầu đổi/trả hàng (Khi đã nhận hàng thành công)
  bool get canRequestReturn => status == statusDelivered;

  /// Đơn VietQR chưa thanh toán (cần hiển thị nút thanh toán/mở mã QR)
  bool get isVietQrPendingPayment =>
      isVietQr && status == statusPending && paymentStatus == paymentUnpaid;

  /// Hiển thị tên trạng thái vận hành tiếng Việt chuẩn UX
  String get statusText {
    switch (status) {
      case statusPending:
        return 'Chờ xác nhận';
      case statusDelivering:
        return 'Đang giao hàng';
      case statusDelivered:
        return 'Đã giao thành công';
      case statusCancelled:
        return 'Đã hủy đơn';
      case statusReturnRequested:
        return 'Yêu cầu đổi/trả';
      case statusReturned:
        return 'Đã hoàn trả';
      default:
        return status;
    }
  }

  /// Hiển thị tên trạng thái thanh toán tiếng Việt chuẩn UX
  String get paymentStatusText {
    switch (paymentStatus) {
      case paymentUnpaid:
        return 'Chưa thanh toán';
      case paymentSubmitted:
        return 'Đã chuyển khoản (Chờ duyệt)';
      case paymentPaid:
        return 'Đã thanh toán';
      case paymentRefunded:
        return 'Đã hoàn tiền';
      default:
        return paymentStatus;
    }
  }

  /// Hiển thị tên hình thức giao hàng tiếng Việt
  String get deliveryMethodText =>
      isPickup ? 'Nhận tại cửa hàng' : 'Giao tận nơi';

  /// Tổng số lượng món hàng trong đơn
  int get totalQuantity =>
      items.fold<int>(0, (total, item) => total + item.quantity);

  // =================== SERIALIZATION ===================

  factory OrderModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime? parseNullableDate(dynamic date) {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date);
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return null;
    }

    DateTime parseDate(dynamic date) {
      return parseNullableDate(date) ?? DateTime.now();
    }

    // Parse items an toàn tuyệt đối chống lỗi cast _Map<dynamic, dynamic>
    final List<CartItemModel> parsedItems = [];
    if (map['items'] is List) {
      for (final item in map['items'] as List) {
        if (item is Map) {
          parsedItems.add(CartItemModel.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final currentStatus = map['status'] as String? ?? statusPending;

    // Tương thích ngược paymentStatus nếu bản ghi Firestore cũ chưa có trường này
    String parsedPaymentStatus = map['paymentStatus'] as String? ?? '';
    if (parsedPaymentStatus.isEmpty) {
      if (currentStatus == statusDelivered) {
        parsedPaymentStatus = paymentPaid;
      } else if (currentStatus == statusReturned) {
        parsedPaymentStatus = paymentRefunded;
      } else {
        parsedPaymentStatus = paymentUnpaid;
      }
    }

    final parsedSubtotal = (map['subtotal'] as num?) ?? 0;
    final parsedTotalPrice = (map['totalPrice'] as num?) ?? 0;

    // Tương thích ngược bóc tách chiết khấu
    final rawDiscount = (map['discountAmount'] as num?) ?? 0;
    final rawProdDiscount = (map['productDiscount'] as num?) ?? 0;
    final rawShipDiscount = (map['shippingDiscount'] as num?) ?? 0;
    final effProdDiscount = rawProdDiscount > 0
        ? rawProdDiscount
        : (rawShipDiscount > 0 ? 0 : rawDiscount);
    final effDiscountAmount =
        rawDiscount > 0 ? rawDiscount : (effProdDiscount + rawShipDiscount);

    // Tương thích ngược phí giao hàng: nếu đơn cũ không lưu shippingFee, suy luận từ chênh lệch tài chính
    num parsedShippingFee = (map['shippingFee'] as num?) ?? 0;
    if (map['shippingFee'] == null && parsedTotalPrice > 0 && parsedSubtotal > 0) {
      final implied = parsedTotalPrice + effDiscountAmount - parsedSubtotal;
      if (implied > 0) {
        parsedShippingFee = implied;
      }
    }

    return OrderModel(
      orderId: id ?? map['orderId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      shippingAddress: map['shippingAddress'] as String? ?? '',
      items: parsedItems,
      subtotal: parsedSubtotal,
      voucherCode: map['voucherCode'] as String? ?? '',
      discountAmount: effDiscountAmount,
      productDiscount: effProdDiscount,
      shippingDiscount: rawShipDiscount,
      shippingFee: parsedShippingFee,
      totalPrice: parsedTotalPrice,
      paymentMethod: map['paymentMethod'] as String? ?? 'COD',
      paymentStatus: parsedPaymentStatus,
      transactionRef: map['transactionRef'] as String? ?? '',
      deliveryMethod: map['deliveryMethod'] as String? ?? deliveryMethodShipping,
      pickupBranchName: map['pickupBranchName'] as String? ?? '',
      note: map['note'] as String? ?? '',
      cancelReason: map['cancelReason'] as String? ?? '',
      returnReason: map['returnReason'] as String? ?? '',
      status: currentStatus,
      createdAt: parseDate(map['createdAt']),
      deliveringAt: parseNullableDate(map['deliveringAt']),
      deliveredAt: parseNullableDate(map['deliveredAt']),
      cancelledAt: parseNullableDate(map['cancelledAt']),
      returnedAt: parseNullableDate(map['returnedAt']),
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
      'productDiscount': productDiscount,
      'shippingDiscount': shippingDiscount,
      'shippingFee': shippingFee,
      'totalPrice': totalPrice,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'transactionRef': transactionRef,
      'deliveryMethod': deliveryMethod,
      'pickupBranchName': pickupBranchName,
      'note': note,
      'status': status,
      'cancelReason': cancelReason,
      'returnReason': returnReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveringAt':
          deliveringAt != null ? Timestamp.fromDate(deliveringAt!) : null,
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'cancelledAt':
          cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'returnedAt': returnedAt != null ? Timestamp.fromDate(returnedAt!) : null,
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
    num? productDiscount,
    num? shippingDiscount,
    num? shippingFee,
    num? totalPrice,
    String? paymentMethod,
    String? paymentStatus,
    String? transactionRef,
    String? deliveryMethod,
    String? pickupBranchName,
    String? note,
    String? cancelReason,
    String? returnReason,
    String? status,
    DateTime? createdAt,
    DateTime? deliveringAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    DateTime? returnedAt,
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
      productDiscount: productDiscount ?? this.productDiscount,
      shippingDiscount: shippingDiscount ?? this.shippingDiscount,
      shippingFee: shippingFee ?? this.shippingFee,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionRef: transactionRef ?? this.transactionRef,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      pickupBranchName: pickupBranchName ?? this.pickupBranchName,
      note: note ?? this.note,
      cancelReason: cancelReason ?? this.cancelReason,
      returnReason: returnReason ?? this.returnReason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      deliveringAt: deliveringAt ?? this.deliveringAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderModel &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId);

  @override
  int get hashCode => orderId.hashCode;
}
