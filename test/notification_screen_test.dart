import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/notification_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/notification_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/notifications/notification_screen.dart';
import 'package:fashion_store_app/screens/orders/order_detail_screen.dart';

void main() {
  group('Kiểm thử Giao diện NotificationScreen (Task 3.6)', () {
    testWidgets('Hiển thị bộ lọc và nút Đọc tất cả khi có thông báo chưa đọc',
        (WidgetTester tester) async {
      final notiProvider = NotificationProvider();
      final orderProvider = OrderProvider();
      final authProvider = AuthProvider();

      final testNotis = [
        NotificationModel(
          id: 'noti_1',
          userId: 'user_1',
          title: 'Đơn hàng #ORD12345 đã được tiếp nhận',
          body: 'Shop đang chuẩn bị hàng cho bạn',
          isRead: false,
          createdAt: DateTime.now(),
          orderId: 'ORD12345',
          type: NotificationModel.typeOrderUpdate,
        ),
        NotificationModel(
          id: 'noti_2',
          userId: 'user_1',
          title: 'Khuyến mãi Lifewear Mùa Hè',
          body: 'Giảm 20% cho áo thun trơn',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          type: NotificationModel.typePromotion,
        ),
      ];
      notiProvider.setMockNotifications(testNotis);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notiProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: const MaterialApp(
            home: NotificationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề AppBar
      expect(find.text('THÔNG BÁO'), findsOneWidget);

      // Kiểm tra có nút Đọc tất cả do còn 1 thông báo chưa đọc
      expect(find.text('Đọc tất cả'), findsOneWidget);

      // Kiểm tra Filter Chips
      expect(find.text('Tất cả (2)'), findsOneWidget);
      expect(find.text('Đơn hàng (1)'), findsOneWidget);
      expect(find.text('Khuyến mãi (1)'), findsOneWidget);

      // Bấm nút Đọc tất cả
      await tester.tap(find.text('Đọc tất cả'));
      await tester.pumpAndSettle();

      // Sau khi đọc tất cả, unreadCount = 0 nên nút Đọc tất cả biến mất
      expect(notiProvider.unreadCount, 0);
      expect(find.text('Đọc tất cả'), findsNothing);
    });

    testWidgets('Bấm vào thông báo đơn hàng điều hướng tới OrderDetailScreen',
        (WidgetTester tester) async {
      final notiProvider = NotificationProvider();
      final orderProvider = OrderProvider();
      final authProvider = AuthProvider();

      const testOrderId = 'ORD_99999';
      final testOrder = OrderModel(
        orderId: testOrderId,
        userId: 'user_1',
        userName: 'Nguyễn Văn A',
        phone: '0901234567',
        shippingAddress: '123 Nguyễn Tri Phương, Q10, TP.HCM',
        items: const [],
        totalPrice: 450000,
        subtotal: 420000,
        shippingFee: 30000,
        discountAmount: 0,
        paymentMethod: 'COD',
        paymentStatus: 'Unpaid',
        status: OrderModel.statusPending,
        createdAt: DateTime.now(),
      );

      orderProvider.setMockUserOrders([testOrder]);

      final testNotis = [
        NotificationModel(
          id: 'noti_order',
          userId: 'user_1',
          title: 'Đơn hàng #$testOrderId đang được giao',
          body: 'Tài xế đang trên đường giao hàng đến bạn',
          isRead: false,
          createdAt: DateTime.now(),
          orderId: testOrderId,
          type: NotificationModel.typeOrderUpdate,
        ),
      ];
      notiProvider.setMockNotifications(testNotis);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notiProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: const MaterialApp(
            home: NotificationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bấm vào thông báo
      await tester.tap(find.text('Đơn hàng #$testOrderId đang được giao'));
      await tester.pumpAndSettle();

      // Đã mở OrderDetailScreen
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.textContaining('ĐƠN HÀNG #'), findsOneWidget);
    });
  });
}
