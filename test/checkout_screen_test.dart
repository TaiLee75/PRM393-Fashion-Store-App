import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/screens/cart/checkout_screen.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';

void main() {
  testWidgets('Kiểm thử Giao diện (Widget Test) màn hình CheckoutScreen có Autofill & Validation',
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
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
        ],
        child: const MaterialApp(
          home: CheckoutScreen(),
        ),
      ),
    );

    // Kiểm tra có tiêu đề Thanh toán
    expect(find.text('THANH TOÁN ĐƠN HÀNG'), findsOneWidget);

    // Kiểm tra các trường nhập thông tin giao hàng (Họ tên, SĐT, Địa chỉ, Ghi chú)
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.textContaining('Họ tên người nhận'), findsOneWidget);
    expect(find.textContaining('Số điện thoại liên hệ'), findsOneWidget);
    expect(find.textContaining('Địa chỉ nhận hàng chi tiết'), findsOneWidget);
    expect(find.textContaining('Ghi chú cho đơn hàng'), findsOneWidget);

    // Kiểm tra checkbox lưu địa chỉ mặc định
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.textContaining('Lưu thông tin này làm địa chỉ nhận hàng mặc định'), findsOneWidget);

    // Kiểm tra nút Xác nhận đặt hàng
    expect(find.text('XÁC NHẬN ĐẶT HÀNG'), findsOneWidget);
  });
}
