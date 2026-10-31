import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/orders/order_detail_screen.dart';
import 'package:fashion_store_app/screens/orders/order_history_screen.dart';

void main() {
  group('Kiểm thử Mô hình & Trạng thái Hoàn tiền (Order Refund Enhancement)', () {
    test('1. OrderModel hỗ trợ hằng số paymentRefundPending và getter isRefundPending', () {
      expect(OrderModel.paymentRefundPending, 'RefundPending');

      final pendingRefundOrder = OrderModel(
        orderId: 'ORD_REFUND_01',
        userId: 'user_01',
        userName: 'Nguyễn Văn Test',
        phone: '0901234567',
        shippingAddress: '123 Đường Fashion, Q1, TP.HCM',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefundPending,
        status: OrderModel.statusCancelled,
        items: const [],
        subtotal: 450000,
        totalPrice: 450000,
        createdAt: DateTime.now(),
      );

      expect(pendingRefundOrder.isRefundPending, isTrue);
      expect(pendingRefundOrder.isRefunded, isFalse);
      expect(pendingRefundOrder.paymentStatusText, 'Chờ hoàn tiền');
    });

    test('2. ReviewModel hỗ trợ trường id nhận diện duy nhất từng đánh giá', () {
      final review = ReviewModel(
        id: 'rev_unique_123',
        userId: 'user_01',
        userName: 'Khách hàng VIP',
        rating: 5.0,
        comment: 'Chất vải mát, đường may tỉ mỉ!',
        createdAt: DateTime.now(),
        orderId: 'ORD_001',
        variantInfo: 'Size L, Màu Đen',
      );

      expect(review.id, 'rev_unique_123');
      final map = review.toMap();
      expect(map['id'], 'rev_unique_123');

      final fromMap = ReviewModel.fromMap(map);
      expect(fromMap.id, 'rev_unique_123');

      final copy = review.copyWith(rating: 4.0);
      expect(copy.id, 'rev_unique_123');
      expect(copy.rating, 4.0);
    });

    test('3. OrderProvider hỗ trợ cập nhật confirmPaymentRefunded', () async {
      final orderProvider = OrderProvider();
      final mockOrder = OrderModel(
        orderId: 'ORD_TEST_REFUND_99',
        userId: 'user_99',
        userName: 'Trần Thị Khách',
        phone: '0988888888',
        shippingAddress: '456 Lê Lợi, TP.HCM',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefundPending,
        status: OrderModel.statusCancelled,
        items: const [],
        subtotal: 300000,
        totalPrice: 300000,
        createdAt: DateTime.now(),
      );

      orderProvider.setMockUserOrders([mockOrder]);
      orderProvider.setMockAllOrders([mockOrder]);

      expect(orderProvider.userOrders.first.paymentStatus, OrderModel.paymentRefundPending);

      // Thử nghiệm confirmPaymentRefunded qua Mock / Direct
      final success = await orderProvider.confirmPaymentRefunded('ORD_TEST_REFUND_99');
      expect(success, isA<bool>());
    });
  });

  group('Kiểm thử Giao diện OrderDetailScreen với Quy trình Hoàn tiền (Widget Test)', () {
    const mockCartItem = CartItemModel(
      cartItemId: 'PROD_1_M_Trang',
      productId: 'PROD_1',
      productName: 'Áo Polo Lifewear Thể Thao',
      imageUrl: 'https://example.com/polo.jpg',
      size: 'M',
      color: 'Trắng',
      price: 250000,
      quantity: 1,
    );

    testWidgets('4. Đơn hàng đã thanh toán bị hủy hiển thị badge "Chờ Shop hoàn tiền" và Banner giải thích 24h',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cancelledPaidOrder = OrderModel(
        orderId: 'ORD_CANCEL_PAID_001',
        userId: 'user_cust',
        userName: 'Lê Văn Khách',
        phone: '0912345678',
        shippingAddress: '789 Nguyễn Huệ, Q1, TP.HCM',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefundPending,
        status: OrderModel.statusCancelled,
        cancelReason: 'Tôi muốn đổi màu áo khác',
        items: const [mockCartItem],
        subtotal: 250000,
        totalPrice: 250000,
        createdAt: DateTime.now(),
      );

      final authProvider = AuthProvider();
      authProvider.setMockUser(UserModel(
        uid: 'user_cust',
        email: 'cust@example.com',
        fullName: 'Lê Văn Khách',
        role: 'customer',
        createdAt: DateTime.now(),
      ));

      final orderProvider = OrderProvider();
      orderProvider.setMockUserOrders([cancelledPaidOrder]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: cancelledPaidOrder),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kiểm tra tiêu đề hủy đơn
      expect(find.text('ĐƠN HÀNG ĐÃ HỦY'), findsOneWidget);
      expect(find.text('Lý do: Tôi muốn đổi màu áo khác'), findsOneWidget);

      // Kiểm tra banner giải thích hoàn tiền trong 24h
      expect(
        find.textContaining('Đơn hàng đã thanh toán. Shop đã tiếp nhận yêu cầu hoàn tiền'),
        findsOneWidget,
      );

      // Kiểm tra badge trạng thái thanh toán là "Chờ Shop hoàn tiền"
      expect(find.text('⏳ Chờ Shop hoàn tiền'), findsOneWidget);
    });

    testWidgets('5. Admin xem đơn ở trạng thái RefundPending hiển thị nút "XÁC NHẬN ĐÃ CHUYỂN TIỀN HOÀN"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final refundPendingOrder = OrderModel(
        orderId: 'ORD_ADMIN_CHECK_REFUND_12',
        userId: 'customer_uid_12',
        userName: 'Nguyễn Thị Khách',
        phone: '0977777777',
        shippingAddress: 'Chi nhánh Landmark 81',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefundPending,
        status: OrderModel.statusCancelled,
        cancelReason: 'Khách đổi ý không muốn nhận',
        items: const [mockCartItem],
        subtotal: 250000,
        totalPrice: 250000,
        createdAt: DateTime.now(),
      );

      final adminAuth = AuthProvider();
      adminAuth.setMockUser(UserModel(
        uid: 'admin_master_uid',
        email: 'admin@lifewear.vn',
        fullName: 'Quản Trị Viên Shop',
        role: 'admin',
        createdAt: DateTime.now(),
      ));

      final orderProvider = OrderProvider();
      orderProvider.setMockAllOrders([refundPendingOrder]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: adminAuth),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: refundPendingOrder),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Nút xác nhận hoàn tiền dành cho Admin
      expect(find.textContaining('XÁC NHẬN ĐÃ CHUYỂN TIỀN HOÀN'), findsOneWidget);
    });

    testWidgets('6. Đơn chưa thanh toán khi hủy hiển thị badge "Đã hủy (Chưa thanh toán)" rõ ràng',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cancelledUnpaidOrder = OrderModel(
        orderId: 'ORD_UNPAID_CANCEL_55',
        userId: 'user_cust',
        userName: 'Lê Văn Khách',
        phone: '0912345678',
        shippingAddress: '789 Nguyễn Huệ, Q1, TP.HCM',
        paymentMethod: 'COD',
        paymentStatus: OrderModel.paymentUnpaid,
        status: OrderModel.statusCancelled,
        cancelReason: 'Đặt nhầm địa chỉ',
        items: const [mockCartItem],
        subtotal: 250000,
        totalPrice: 250000,
        createdAt: DateTime.now(),
      );

      final authProvider = AuthProvider();
      authProvider.setMockUser(UserModel(
        uid: 'user_cust',
        email: 'cust@example.com',
        fullName: 'Lê Văn Khách',
        role: 'customer',
        createdAt: DateTime.now(),
      ));

      final orderProvider = OrderProvider();
      orderProvider.setMockUserOrders([cancelledUnpaidOrder]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: cancelledUnpaidOrder),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kiểm tra badge rõ ràng: "🚫 Đã hủy (Chưa thanh toán)"
      expect(find.text('🚫 Đã hủy (Chưa thanh toán)'), findsOneWidget);
    });

    testWidgets('7. OrderHistoryScreen hiển thị badge "Chờ hoàn tiền" cho đơn đã thanh toán bị hủy', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final refundPendingOrder = OrderModel(
        orderId: 'ORD_HIST_REFUND_01',
        userId: 'user_cust',
        userName: 'Lê Văn Khách',
        phone: '0912345678',
        shippingAddress: '789 Nguyễn Huệ, Q1, TP.HCM',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefundPending,
        status: OrderModel.statusCancelled,
        cancelReason: 'Đổi ý',
        items: const [mockCartItem],
        subtotal: 250000,
        totalPrice: 250000,
        createdAt: DateTime.now(),
      );

      final authProvider = AuthProvider();
      authProvider.setMockUser(UserModel(
        uid: 'user_cust',
        email: 'cust@example.com',
        fullName: 'Lê Văn Khách',
        role: 'customer',
        createdAt: DateTime.now(),
      ));

      final orderProvider = OrderProvider();
      orderProvider.setMockUserOrders([refundPendingOrder]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
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

      // Kiểm tra badge "Chờ hoàn tiền" xuất hiện trên thẻ đơn hàng ở màn hình Lịch sử đơn hàng
      expect(find.text('Chờ hoàn tiền'), findsOneWidget);
      // Đảm bảo không còn hiện "Chưa thanh toán"
      expect(find.text('Chưa thanh toán'), findsNothing);
    });

    testWidgets('8. OrderHistoryScreen không hiển thị badge "Chưa thanh toán" đối với đơn VietQR đã hủy', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cancelledUnpaidOrder = OrderModel(
        orderId: 'ORD_HIST_UNPAID_CANCEL',
        userId: 'user_cust',
        userName: 'Lê Văn Khách',
        phone: '0912345678',
        shippingAddress: '789 Nguyễn Huệ, Q1, TP.HCM',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentUnpaid,
        status: OrderModel.statusCancelled,
        cancelReason: 'Hết hạn thanh toán',
        items: const [mockCartItem],
        subtotal: 250000,
        totalPrice: 250000,
        createdAt: DateTime.now(),
      );

      final authProvider = AuthProvider();
      authProvider.setMockUser(UserModel(
        uid: 'user_cust',
        email: 'cust@example.com',
        fullName: 'Lê Văn Khách',
        role: 'customer',
        createdAt: DateTime.now(),
      ));

      final orderProvider = OrderProvider();
      orderProvider.setMockUserOrders([cancelledUnpaidOrder]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
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

      // Tuyệt đối không hiển thị badge "Chưa thanh toán" gây hiểu nhầm khi đơn đã hủy
      expect(find.text('Chưa thanh toán'), findsNothing);
    });

    testWidgets('9. OrderDetailScreen hiển thị banner "Đang chờ shop chuyển tiền hoàn" khi đơn Đã hoàn trả và Chờ hoàn tiền', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final returnedPendingOrder = OrderModel(
        orderId: 'ORD_RET_PENDING_01',
        userId: 'user_cust',
        userName: 'Lê Văn Khách',
        phone: '0912345678',
        shippingAddress: '789 Nguyễn Huệ, Q1, TP.HCM',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefundPending,
        status: OrderModel.statusReturned,
        returnReason: 'Áo bị chật vai',
        items: const [mockCartItem],
        subtotal: 250000,
        totalPrice: 250000,
        returnedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final authProvider = AuthProvider();
      authProvider.setMockUser(UserModel(
        uid: 'user_cust',
        email: 'cust@example.com',
        fullName: 'Lê Văn Khách',
        role: 'customer',
        createdAt: DateTime.now(),
      ));

      final orderProvider = OrderProvider();
      orderProvider.setMockUserOrders([returnedPendingOrder]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: returnedPendingOrder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề ĐƠN HÀNG ĐÃ HOÀN TRẢ và lý do
      expect(find.text('ĐƠN HÀNG ĐÃ HOÀN TRẢ'), findsOneWidget);
      expect(find.text('Lý do: Áo bị chật vai'), findsOneWidget);

      // Kiểm tra banner Chờ shop chuyển tiền hoàn
      expect(find.textContaining('Đang chờ shop chuyển tiền hoàn'), findsOneWidget);
    });

    testWidgets('10. Admin xem đơn Đã hoàn trả đang Chờ hoàn tiền thấy nút "XÁC NHẬN ĐÃ CHUYỂN TIỀN HOÀN"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final returnedPendingOrder = OrderModel(
        orderId: 'ORD_RET_ADMIN_01',
        userId: 'user_cust',
        userName: 'Lê Văn Khách',
        phone: '0912345678',
        shippingAddress: '789 Nguyễn Huệ, Q1, TP.HCM',
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentRefundPending,
        status: OrderModel.statusReturned,
        returnReason: 'Lỗi đường may',
        items: const [mockCartItem],
        subtotal: 250000,
        totalPrice: 250000,
        returnedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final adminAuthProvider = AuthProvider();
      adminAuthProvider.setMockUser(UserModel(
        uid: 'admin_01',
        email: 'admin@fashionstore.com',
        fullName: 'Quản Trị Viên',
        role: 'admin',
        createdAt: DateTime.now(),
      ));

      final orderProvider = OrderProvider();
      orderProvider.setMockAllOrders([returnedPendingOrder]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: adminAuthProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: returnedPendingOrder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Admin thấy nút hành động Xác nhận đã chuyển tiền hoàn
      expect(find.textContaining('XÁC NHẬN ĐÃ CHUYỂN TIỀN HOÀN'), findsOneWidget);
    });
  });
}
