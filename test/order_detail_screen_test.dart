import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/orders/order_detail_screen.dart';

void main() {
  group('Kiểm thử Giao diện (Widget Test) OrderDetailScreen - Member 5', () {
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

    testWidgets('OrderDetailScreen hiển thị đúng thông tin đơn hàng và Stepper trạng thái Pending',
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
    });

    testWidgets('OrderDetailScreen chuyển tiêu đề khi trạng thái là Delivering',
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
    });
  });
}
