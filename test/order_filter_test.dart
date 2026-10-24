import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/orders/order_history_screen.dart';

void main() {
  group('Kiểm thử Logic & Giao diện Bộ lọc Đơn hàng (Order Filter Feature)', () {
    final sampleOrders = [
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
        status: 'Pending',
        createdAt: DateTime.now(),
      ),
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
        status: 'Delivering',
        createdAt: DateTime.now(),
      ),
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
        status: 'Delivered',
        createdAt: DateTime.now(),
      ),
    ];

    test('Logic lọc đơn hàng theo trạng thái (Pending, Delivering, Delivered)', () {
      final pendingList = sampleOrders.where((o) => o.status == 'Pending').toList();
      final deliveringList = sampleOrders.where((o) => o.status == 'Delivering').toList();
      final deliveredList = sampleOrders.where((o) => o.status == 'Delivered').toList();

      expect(pendingList.length, 1);
      expect(pendingList.first.orderId, 'ORD_PENDING_01');

      expect(deliveringList.length, 1);
      expect(deliveringList.first.orderId, 'ORD_DELIVERING_02');

      expect(deliveredList.length, 1);
      expect(deliveredList.first.orderId, 'ORD_DELIVERED_03');
    });

    test('Logic tìm kiếm đơn hàng theo mã đơn và tên sản phẩm', () {
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
    });

    testWidgets('OrderHistoryScreen hiển thị thanh tìm kiếm & các chip lọc với bộ đếm', (WidgetTester tester) async {
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
      expect(find.text('Chờ xác nhận'), findsNWidgets(2)); // 1 trong Chip lọc + 1 trong thẻ đơn hàng Pending
      expect(find.text('Đang giao'), findsOneWidget); // Chip "Đang giao" (thẻ đơn hàng ghi "Đang giao hàng")
      expect(find.text('Đã giao'), findsOneWidget); // Chip "Đã giao" (thẻ đơn hàng ghi "Đã giao thành công")

      // Ban đầu "Tất cả" có 3 đơn hàng
      expect(find.text('Mã đơn: #ORD_PEND'), findsOneWidget);
      expect(find.text('Mã đơn: #ORD_DELI'), findsNWidgets(2));

      // Bấm vào chip "Chờ xác nhận"
      await tester.tap(find.text('Chờ xác nhận').first);
      await tester.pumpAndSettle();

      // Chỉ hiển thị 1 đơn Pending
      expect(find.text('Mã đơn: #ORD_PEND'), findsOneWidget);
      expect(find.text('Mã đơn: #ORD_DELI'), findsNothing);

      // Bấm vào chip "Đã giao"
      await tester.tap(find.text('Đã giao'));
      await tester.pumpAndSettle();

      // Chỉ hiển thị 1 đơn Delivered
      expect(find.text('Mã đơn: #ORD_DELI'), findsOneWidget);
      expect(find.text('Áo Khoác Gió Chống Nước (XL, Rêu) x1'), findsOneWidget);
    });
  });
}
