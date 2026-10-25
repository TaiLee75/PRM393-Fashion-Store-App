import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/order_model.dart';

void main() {
  group('OrderModel Enterprise Serialization & Logic Tests:', () {
    test('1. Tương thích ngược: Parse bản ghi đơn hàng cũ không có trường mới & tính implied shippingFee', () {
      final oldOrderMap = {
        'orderId': 'ord_old_001',
        'userId': 'usr_001',
        'userName': 'Nguyễn Văn Cũ',
        'phone': '0901234567',
        'shippingAddress': '123 Đường Cũ, Quận 1',
        'subtotal': 400000,
        'voucherCode': 'SALE10',
        'discountAmount': 40000,
        'totalPrice': 390000, // 400k - 40k + 30k ship = 390k
        'paymentMethod': 'COD',
        'status': 'Pending',
        'createdAt': '2026-10-20T10:00:00Z',
        'items': [
          {
            'cartItemId': 'prod_01_M_Đen',
            'productId': 'prod_01',
            'productName': 'Áo Thun',
            'imageUrl': 'https://example.com/a.jpg',
            'price': 200000,
            'size': 'M',
            'color': 'Đen',
            'quantity': 2,
          }
        ],
      };

      final order = OrderModel.fromMap(oldOrderMap);

      expect(order.orderId, 'ord_old_001');
      expect(order.status, OrderModel.statusPending);
      expect(order.statusText, 'Chờ xác nhận');
      expect(order.paymentStatus, OrderModel.paymentUnpaid); // Tự động suy luận từ Pending
      expect(order.paymentStatusText, 'Chưa thanh toán');
      expect(order.deliveryMethod, OrderModel.deliveryMethodShipping);
      expect(order.deliveryMethodText, 'Giao tận nơi');
      expect(order.isDelivery, isTrue);
      expect(order.isPickup, isFalse);
      expect(order.isCod, isTrue);
      expect(order.isVietQr, isFalse);
      expect(order.pickupBranchName, '');
      expect(order.productDiscount, 40000); // Tự suy luận từ discountAmount
      expect(order.shippingDiscount, 0);
      expect(order.shippingFee, 30000); // Tự suy luận chính xác từ 390k + 40k - 400k = 30k
      expect(order.canCancel, isTrue);
      expect(order.canEditAddress, isTrue);
      expect(order.canRequestReturn, isFalse);
      expect(order.deliveringAt, isNull);
      expect(order.deliveredAt, isNull);
      expect(order.items.length, 1);
      expect(order.totalQuantity, 2);
    });

    test('2. Tương thích ngược: Đơn cũ có status Delivered tự suy luận paymentStatus = Paid', () {
      final oldDeliveredMap = {
        'orderId': 'ord_old_002',
        'userId': 'usr_002',
        'userName': 'Trần Thị Cũ',
        'phone': '0912345678',
        'shippingAddress': '456 Đường Cũ, Quận 3',
        'subtotal': 250000,
        'totalPrice': 250000,
        'paymentMethod': 'COD',
        'status': 'Delivered',
        'createdAt': '2026-10-15T09:00:00Z',
        'items': [],
      };

      final order = OrderModel.fromMap(oldDeliveredMap);
      expect(order.status, OrderModel.statusDelivered);
      expect(order.statusText, 'Đã giao thành công');
      expect(order.paymentStatus, OrderModel.paymentPaid); // COD giao xong coi như đã thanh toán
      expect(order.paymentStatusText, 'Đã thanh toán');
      expect(order.isPaid, isTrue);
      expect(order.canCancel, isFalse);
      expect(order.canRequestReturn, isTrue);
    });

    test('3. Parse đơn hàng mới chuẩn Enterprise: VietQR, Audit Timestamps, Bóc tách phí', () {
      final newOrderMap = {
        'orderId': 'ord_new_888',
        'userId': 'usr_enterprise',
        'userName': 'Lê Hoàng Nam',
        'phone': '0988889999',
        'shippingAddress': 'Chi nhánh Takashimaya Q1',
        'subtotal': 500000,
        'voucherCode': 'FREESHIP',
        'discountAmount': 30000,
        'productDiscount': 0,
        'shippingDiscount': 30000,
        'shippingFee': 30000,
        'totalPrice': 500000,
        'paymentMethod': 'VIETQR',
        'paymentStatus': OrderModel.paymentSubmitted,
        'transactionRef': 'VQR_998877_TXN',
        'deliveryMethod': OrderModel.deliveryMethodPickup,
        'pickupBranchName': 'Fashion Store Takashimaya',
        'note': 'Lấy hàng lúc 17h',
        'status': OrderModel.statusPending,
        'createdAt': '2026-10-25T08:00:00Z',
        'items': [
          {
            'cartItemId': 'prod_02_L_Trắng',
            'productId': 'prod_02',
            'productName': 'Áo Sơ Mi',
            'imageUrl': 'https://example.com/somi.jpg',
            'price': 250000,
            'size': 'L',
            'color': 'Trắng',
            'quantity': 2,
          }
        ],
      };

      final order = OrderModel.fromMap(newOrderMap);

      expect(order.orderId, 'ord_new_888');
      expect(order.isVietQr, isTrue);
      expect(order.isPaymentSubmitted, isTrue);
      expect(order.isPaid, isFalse);
      expect(order.paymentStatusText, 'Đã chuyển khoản (Chờ duyệt)');
      expect(order.transactionRef, 'VQR_998877_TXN');
      expect(order.isPickup, isTrue);
      expect(order.deliveryMethodText, 'Nhận tại cửa hàng');
      expect(order.pickupBranchName, 'Fashion Store Takashimaya');
      expect(order.note, 'Lấy hàng lúc 17h');
      expect(order.productDiscount, 0);
      expect(order.shippingDiscount, 30000);
      expect(order.shippingFee, 30000);
      expect(order.canEditAddress, isFalse); // Đơn PICKUP không cho sửa địa chỉ giao
      expect(order.canCancel, isTrue);

      // Test toMap & copyWith
      final mapOutput = order.toMap();
      expect(mapOutput['deliveryMethod'], OrderModel.deliveryMethodPickup);
      expect(mapOutput['transactionRef'], 'VQR_998877_TXN');
      expect(mapOutput['paymentStatus'], OrderModel.paymentSubmitted);

      final updatedOrder = order.copyWith(status: OrderModel.statusCancelled, cancelReason: 'Đổi ý');
      expect(updatedOrder.isCancelled, isTrue);
      expect(updatedOrder.statusText, 'Đã hủy đơn');
      expect(updatedOrder.cancelReason, 'Đổi ý');
      expect(updatedOrder, equals(order)); // Cùng orderId
    });

    test('4. Xử lý an toàn khi Firestore trả về Map dynamic lồng nhau', () {
      final dynamicMap = <dynamic, dynamic>{
        'orderId': 'ord_dyn_999',
        'userId': 'usr_dyn',
        'userName': 'Khách Dynamic',
        'phone': '0933333333',
        'shippingAddress': 'Hà Nội',
        'subtotal': 300000,
        'totalPrice': 300000,
        'createdAt': '2026-10-25T10:00:00Z',
        'items': <dynamic>[
          <dynamic, dynamic>{
            'cartItemId': 'prod_03_XL_Xanh',
            'productId': 'prod_03',
            'productName': 'Quần Jean',
            'imageUrl': 'https://example.com/jean.jpg',
            'price': 300000,
            'size': 'XL',
            'color': 'Xanh',
            'quantity': 1,
          }
        ],
      };

      final order = OrderModel.fromMap(Map<String, dynamic>.from(dynamicMap));
      expect(order.orderId, 'ord_dyn_999');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'Quần Jean');
    });
  });
}
