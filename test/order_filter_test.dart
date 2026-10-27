import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/orders/order_history_screen.dart';

void main() {
  group('Kiểm thử Logic & Giao diện Bộ lọc Đơn hàng Toàn diện (Task 4.4):', () {
    final sampleOrders = [
      // 1. Chờ xác nhận - VietQR Unpaid
      OrderModel(
        orderId: 'ORD_PENDING_01',
        userId: 'user_test',
        userName: 'Nguyễn Văn A',
        phone: '0901111111',
        shippingAddress: 'Hà Nội',
        items: const [
          CartItemModel(
            cartItemId: 'item_1',
            productId: 'prod_1',
            productName: 'Áo Polo Nam Classic',
            imageUrl: 'https://example.com/polo.jpg',
            price: 350000,
            size: 'L',
            color: 'Đen',
            quantity: 1,
          ),
        ],
        subtotal: 350000,
        totalPrice: 350000,
        status: OrderModel.statusPending,
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentUnpaid,
        createdAt: DateTime(2026, 10, 25, 10, 0),
      ),
      // 2. Đang giao - VietQR PaymentSubmitted
      OrderModel(
        orderId: 'ORD_DELIVERING_02',
        userId: 'user_test',
        userName: 'Trần Thị B',
        phone: '0902222222',
        shippingAddress: 'TP.HCM',
        items: const [
          CartItemModel(
            cartItemId: 'item_2',
            productId: 'prod_2',
            productName: 'Quần Jean Slimfit',
            imageUrl: 'https://example.com/jean.jpg',
            price: 499000,
            size: '32',
            color: 'Xanh Đậm',
            quantity: 1,
          ),
        ],
        subtotal: 499000,
        totalPrice: 499000,
        status: OrderModel.statusDelivering,
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentSubmitted,
        transactionRef: 'FT260999888',
        createdAt: DateTime(2026, 10, 25, 11, 0),
      ),
      // 3. Đã giao - COD Paid
      OrderModel(
        orderId: 'ORD_DELIVERED_03',
        userId: 'user_test',
        userName: 'Lê Văn C',
        phone: '0903333333',
        shippingAddress: 'Đà Nẵng',
        items: const [
          CartItemModel(
            cartItemId: 'item_3',
            productId: 'prod_3',
            productName: 'Áo Khoác Gió Chống Nước',
            imageUrl: 'https://example.com/jacket.jpg',
            price: 650000,
            size: 'XL',
            color: 'Rêu',
            quantity: 1,
          ),
        ],
        subtotal: 650000,
        totalPrice: 650000,
        status: OrderModel.statusDelivered,
        paymentMethod: 'COD',
        paymentStatus: OrderModel.paymentPaid,
        createdAt: DateTime(2026, 10, 25, 12, 0),
      ),
      // 4. Yêu cầu đổi/trả - VietQR Paid
      OrderModel(
        orderId: 'ORD_RETURN_REQ_04',
        userId: 'user_test',
        userName: 'Phạm Văn D',
        phone: '0904444444',
        shippingAddress: 'Cần Thơ',
        items: const [
          CartItemModel(
            cartItemId: 'item_4',
            productId: 'prod_4',
            productName: 'Áo Sơ Mi Oxford Dài Tay',
            imageUrl: 'https://example.com/shirt.jpg',
            price: 420000,
            size: 'M',
            color: 'Trắng',
            quantity: 1,
          ),
        ],
        subtotal: 420000,
        totalPrice: 420000,
        status: OrderModel.statusReturnRequested,
        returnReason: 'Rộng vai muốn đổi size S',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentPaid,
        createdAt: DateTime(2026, 10, 25, 13, 0),
      ),
      // 5. Đã hoàn trả - VietQR Refunded
      OrderModel(
        orderId: 'ORD_RETURNED_05',
        userId: 'user_test',
        userName: 'Hoàng Thị E',
        phone: '0905555555',
        shippingAddress: 'Hải Phòng',
        items: const [
          CartItemModel(
            cartItemId: 'item_5',
            productId: 'prod_5',
            productName: 'Quần Khaki Chino Co Giãn',
            imageUrl: 'https://example.com/chino.jpg',
            price: 550000,
            size: '31',
            color: 'Be',
            quantity: 1,
          ),
        ],
        subtotal: 550000,
        totalPrice: 550000,
        status: OrderModel.statusReturned,
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefunded,
        createdAt: DateTime(2026, 10, 25, 14, 0),
      ),
      // 6. Đã hủy - COD Unpaid
      OrderModel(
        orderId: 'ORD_CANCELLED_06',
        userId: 'user_test',
        userName: 'Đỗ Văn F',
        phone: '0906666666',
        shippingAddress: 'Nha Trang',
        items: const [
          CartItemModel(
            cartItemId: 'item_6',
            productId: 'prod_6',
            productName: 'Tất Khử Mùi Cổ Ngắn',
            imageUrl: 'https://example.com/socks.jpg',
            price: 89000,
            size: 'FreeSize',
            color: 'Xám',
            quantity: 2,
          ),
        ],
        subtotal: 178000,
        totalPrice: 178000,
        status: OrderModel.statusCancelled,
        cancelReason: 'Đổi ý không mua nữa',
        cancelledBy: 'customer',
        paymentMethod: 'COD',
        paymentStatus: OrderModel.paymentUnpaid,
        createdAt: DateTime(2026, 10, 25, 15, 0),
      ),
    ];

    test('1. Logic lọc đơn hàng chuẩn xác theo toàn bộ 6 trạng thái nghiệp vụ', () {
      final pendingList = sampleOrders.where((o) => o.status == OrderModel.statusPending).toList();
      final deliveringList = sampleOrders.where((o) => o.status == OrderModel.statusDelivering).toList();
      final deliveredList = sampleOrders.where((o) => o.status == OrderModel.statusDelivered).toList();
      final returnReqList = sampleOrders.where((o) => o.status == OrderModel.statusReturnRequested).toList();
      final returnedList = sampleOrders.where((o) => o.status == OrderModel.statusReturned).toList();
      final cancelledList = sampleOrders.where((o) => o.status == OrderModel.statusCancelled).toList();

      expect(pendingList.length, 1);
      expect(pendingList.first.orderId, 'ORD_PENDING_01');

      expect(deliveringList.length, 1);
      expect(deliveringList.first.orderId, 'ORD_DELIVERING_02');

      expect(deliveredList.length, 1);
      expect(deliveredList.first.orderId, 'ORD_DELIVERED_03');

      expect(returnReqList.length, 1);
      expect(returnReqList.first.orderId, 'ORD_RETURN_REQ_04');

      expect(returnedList.length, 1);
      expect(returnedList.first.orderId, 'ORD_RETURNED_05');

      expect(cancelledList.length, 1);
      expect(cancelledList.first.orderId, 'ORD_CANCELLED_06');
    });

    test('2. Logic phân loại trạng thái dòng tiền minh bạch (PaymentStatus)', () {
      final unpaidOrders = sampleOrders.where((o) => o.paymentStatus == OrderModel.paymentUnpaid).toList();
      final submittedOrders = sampleOrders.where((o) => o.isPaymentSubmitted).toList();
      final paidOrders = sampleOrders.where((o) => o.isPaid).toList();
      final refundedOrders = sampleOrders.where((o) => o.isRefunded).toList();

      expect(unpaidOrders.length, 2); // ORD_PENDING_01, ORD_CANCELLED_06
      expect(submittedOrders.length, 1); // ORD_DELIVERING_02
      expect(submittedOrders.first.transactionRef, 'FT260999888');

      expect(paidOrders.length, 2); // ORD_DELIVERED_03, ORD_RETURN_REQ_04
      expect(refundedOrders.length, 1); // ORD_RETURNED_05
    });

    test('3. Logic tìm kiếm đơn hàng theo mã đơn và tên sản phẩm', () {
      // Tìm theo mã đơn
      const queryId = 'ORD_DELIVERING';
      final matchById = sampleOrders.where((o) => o.orderId.toLowerCase().contains(queryId.toLowerCase())).toList();
      expect(matchById.length, 1);
      expect(matchById.first.orderId, 'ORD_DELIVERING_02');

      // Tìm theo tên sản phẩm
      const queryItem = 'Áo Khoác';
      final matchByItem = sampleOrders.where((o) =>
          o.items.any((it) => it.productName.toLowerCase().contains(queryItem.toLowerCase()))
      ).toList();
      expect(matchByItem.length, 1);
      expect(matchByItem.first.orderId, 'ORD_DELIVERED_03');

      // Tìm sản phẩm tất
      const querySocks = 'Tất';
      final matchSocks = sampleOrders.where((o) =>
          o.items.any((it) => it.productName.toLowerCase().contains(querySocks.toLowerCase()))
      ).toList();
      expect(matchSocks.length, 1);
      expect(matchSocks.first.orderId, 'ORD_CANCELLED_06');
    });

    testWidgets('4. OrderHistoryScreen hiển thị đầy đủ 6 chip lọc, bộ đếm & thẻ đơn hàng chuẩn',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final orderProvider = OrderProvider();
      orderProvider.setMockUserOrders(sampleOrders);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrderHistoryScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra thanh tìm kiếm
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tìm theo mã đơn hoặc tên sản phẩm...'), findsOneWidget);

      // Kiểm tra các chip lọc trạng thái
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Chờ xác nhận'), findsNWidgets(2)); // 1 chip + 1 thẻ đơn Pending
      expect(find.text('Đang giao'), findsOneWidget);
      expect(find.text('Đã giao'), findsOneWidget);
      expect(find.text('Yêu cầu đổi/trả'), findsNWidgets(2)); // 1 chip + 1 thẻ đơn
      expect(find.text('Đã hoàn trả'), findsNWidgets(2)); // 1 chip + 1 thẻ đơn
      expect(find.text('Đã hủy'), findsOneWidget);

      // Kiểm tra Badge thanh toán minh bạch
      expect(find.text('Chưa thanh toán'), findsOneWidget); // Đơn VietQR Unpaid
      expect(find.text('Chờ duyệt CK'), findsOneWidget); // Đơn VietQR PaymentSubmitted
      expect(find.text('Đã thanh toán'), findsNWidgets(2)); // Đơn Paid
      expect(find.text('Đã hoàn tiền'), findsOneWidget); // Đơn Refunded

      // Bấm chip "Chờ xác nhận"
      final pendingChip = find.text('Chờ xác nhận').first;
      await tester.ensureVisible(pendingChip);
      await tester.tap(pendingChip);
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: #ORD_PEND'), findsOneWidget);
      expect(find.text('Xem mã QR thanh toán (Napas247)'), findsOneWidget);

      // Bấm chip "Yêu cầu đổi/trả"
      final returnChip = find.text('Yêu cầu đổi/trả').first;
      await tester.ensureVisible(returnChip);
      await tester.tap(returnChip);
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: #ORD_RETU'), findsOneWidget);
      expect(find.textContaining('Áo Sơ Mi Oxford Dài Tay'), findsOneWidget);

      // Bấm chip "Đã hủy"
      final cancelChip = find.text('Đã hủy').first;
      await tester.ensureVisible(cancelChip);
      await tester.tap(cancelChip);
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: #ORD_CANC'), findsOneWidget);
      expect(find.text('Mua lại đơn này'), findsOneWidget);
    });
  });
}
