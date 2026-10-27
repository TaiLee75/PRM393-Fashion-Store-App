import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/orders/order_detail_screen.dart';

void main() {
  group('Kiểm thử Giao diện (Widget Test) OrderDetailScreen - Task 3.5', () {
    final mockOrder = OrderModel(
      orderId: 'ORDER_TEST_123456',
      userId: 'user_001',
      userName: 'Nguyễn Văn Test',
      phone: '0901234567',
      shippingAddress: '123 Đường Fashion, Quận 1, TP.HCM',
      items: const [
        CartItemModel(
          cartItemId: 'prod_1_M_Trang',
          productId: 'prod_1',
          productName: 'Áo Thun Basic Lifewear',
          imageUrl: 'https://example.com/aothun.jpg',
          price: 299000,
          size: 'M',
          color: 'Trắng',
          quantity: 2,
        ),
      ],
      subtotal: 598000,
      voucherCode: 'SALE10',
      discountAmount: 59800,
      totalPrice: 538200,
      paymentMethod: 'VIETQR',
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    testWidgets('1. OrderDetailScreen hiển thị đúng thông tin đơn hàng và Stepper trạng thái Pending',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: mockOrder),
          ),
        ),
      );

      // Kiểm tra tiêu đề AppBar có mã đơn viết hoa
      expect(find.text('ĐƠN HÀNG #ORDER_TE'), findsOneWidget);

      // Kiểm tra Stepper trạng thái Pending
      expect(find.text('Đang chờ shop xác nhận'), findsOneWidget);
      expect(find.text('Đặt hàng'), findsOneWidget);
      expect(find.text('Đang giao'), findsOneWidget);
      expect(find.text('Đã nhận'), findsOneWidget);

      // Kiểm tra thông tin người nhận & địa chỉ
      expect(find.text('THÔNG TIN GIAO HÀNG'), findsOneWidget);
      expect(find.text('Nguyễn Văn Test'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);
      expect(find.text('123 Đường Fashion, Quận 1, TP.HCM'), findsOneWidget);

      // Kiểm tra món hàng
      expect(find.text('Áo Thun Basic Lifewear'), findsOneWidget);
      expect(find.text('Size: M  |  Màu: Trắng'), findsOneWidget);

      // Kiểm tra phương thức thanh toán VietQR và nút mở mã QR
      expect(find.text('MỞ MÃ QR THANH TOÁN (NAPAS 24/7)'), findsOneWidget);

      // Kiểm tra nút liên hệ shop
      expect(find.text('LIÊN HỆ SHOP VỀ ĐƠN HÀNG NÀY'), findsOneWidget);

      // Kiểm tra các nút hành động của trạng thái Pending (Khóa Bẫy 20)
      expect(find.text('Sửa địa chỉ'), findsOneWidget);
      expect(find.text('Hủy đơn hàng'), findsOneWidget);
    });

    testWidgets('2. OrderDetailScreen chuyển tiêu đề khi trạng thái là Delivering',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deliveringOrder = mockOrder.copyWith(status: 'Delivering');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: deliveringOrder),
          ),
        ),
      );

      expect(find.text('Đơn hàng đang trên đường giao'), findsOneWidget);
      expect(find.text('TÔI ĐÃ NHẬN ĐƯỢC HÀNG'), findsOneWidget);
    });

    testWidgets('3. Khóa Bẫy 8 & 16: Đơn đã giao & thanh toán khóa nút QR và hiển thị các hành động Delivered',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final paidDeliveredOrder = mockOrder.copyWith(
        status: OrderModel.statusDelivered,
        paymentStatus: OrderModel.paymentPaid,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: paidDeliveredOrder),
          ),
        ),
      );

      // Khóa Bẫy 8: Nút mở QR phải biến mất
      expect(find.text('MỞ MÃ QR THANH TOÁN (NAPAS 24/7)'), findsNothing);

      // Khóa Bẫy 16: Hiển thị badge đã thanh toán
      expect(find.text('✅ Đã thanh toán'), findsOneWidget);

      // Các nút hành động của đơn Delivered
      expect(find.text('Đánh giá sản phẩm'), findsOneWidget);
      expect(find.text('Yêu cầu Đổi/Trả'), findsOneWidget);
      expect(find.text('Mua lại đơn này'), findsOneWidget);
    });

    testWidgets('4. Khóa Bẫy 8: Đơn đã hủy hiển thị Banner lý do hủy và khóa nút VietQR',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cancelledOrder = mockOrder.copyWith(
        status: OrderModel.statusCancelled,
        cancelReason: 'Tôi muốn đổi màu áo khác',
        paymentStatus: OrderModel.paymentRefunded,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: cancelledOrder),
          ),
        ),
      );

      // Khóa Bẫy 8: Nút mở mã QR phải biến mất
      expect(find.text('MỞ MÃ QR THANH TOÁN (NAPAS 24/7)'), findsNothing);

      // Hiển thị Banner hủy
      expect(find.text('ĐƠN HÀNG ĐÃ HỦY'), findsOneWidget);
      expect(find.text('Lý do: Tôi muốn đổi màu áo khác'), findsOneWidget);
      expect(find.text('💸 Tiền đã được xử lý hoàn trả cho bạn.'), findsOneWidget);
      expect(find.text('Mua lại các sản phẩm này'), findsOneWidget);
    });

    testWidgets('5. Khóa Bẫy 18: Admin xem đơn của khách hàng khác hiển thị nút Chat với khách hàng này',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminAuth = AuthProvider();
      adminAuth.setMockUser(UserModel(
        uid: 'admin_uid_999',
        email: 'admin@lifewear.com',
        fullName: 'Quản trị viên',
        role: 'admin',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: adminAuth),
            ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
          ],
          child: MaterialApp(
            home: OrderDetailScreen(initialOrder: mockOrder),
          ),
        ),
      );

      // Khóa Bẫy 18: Nút liên hệ chuyển thành "CHAT VỚI KHÁCH HÀNG NÀY"
      expect(find.text('CHAT VỚI KHÁCH HÀNG NÀY'), findsOneWidget);
      expect(find.text('LIÊN HỆ SHOP VỀ ĐƠN HÀNG NÀY'), findsNothing);
    });
  });
}
