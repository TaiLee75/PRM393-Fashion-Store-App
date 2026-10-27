import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/providers/chat_provider.dart';
import 'package:fashion_store_app/providers/notification_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/profile/profile_screen.dart';

void main() {
  group('Kiểm thử Giao diện ProfileScreen & Khóa Bẫy 4 (Task 3.6)', () {
    testWidgets('ProfileScreen hiển thị thông tin người dùng, thanh tóm tắt đơn hàng và role switcher',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      final cartProvider = CartProvider();
      final orderProvider = OrderProvider();
      final notiProvider = NotificationProvider();
      final chatProvider = ChatProvider();

      final user = UserModel(
        uid: 'user_profile_1',
        email: 'user.test@example.com',
        fullName: 'Trần Văn Nam',
        phone: '0987654321',
        defaultAddress: '456 Lê Duẩn, Quận 1, TP.HCM',
        bodyMeasurements: {'height': 175, 'weight': 68},
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);

      final testOrders = [
        OrderModel(
          orderId: 'ORD_P_1',
          userId: 'user_profile_1',
          userName: 'Trần Văn Nam',
          phone: '0987654321',
          shippingAddress: '456 Lê Duẩn, Quận 1, TP.HCM',
          items: const [],
          subtotal: 300000,
          totalPrice: 300000,
          status: OrderModel.statusPending,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          orderId: 'ORD_P_2',
          userId: 'user_profile_1',
          userName: 'Trần Văn Nam',
          phone: '0987654321',
          shippingAddress: '456 Lê Duẩn, Quận 1, TP.HCM',
          items: const [],
          subtotal: 500000,
          totalPrice: 500000,
          status: OrderModel.statusDelivered,
          createdAt: DateTime.now(),
        ),
      ];
      orderProvider.setMockUserOrders(testOrders);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notiProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Kiểm tra thông tin cá nhân
      expect(find.text('Trần Văn Nam'), findsOneWidget);
      expect(find.text('user.test@example.com'), findsOneWidget);
      expect(find.textContaining('0987654321'), findsOneWidget);
      expect(find.textContaining('456 Lê Duẩn'), findsOneWidget);

      // 2. Kiểm tra số đo cơ thể
      expect(find.textContaining('175cm - 68kg'), findsOneWidget);

      // 3. Kiểm tra Order Status Summary Bar
      expect(find.text('ĐƠN HÀNG CỦA TÔI'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.text('Đang giao'), findsOneWidget);
      expect(find.text('Đã giao'), findsOneWidget);
      expect(find.text('Đổi / Trả'), findsOneWidget);

      // 4. Kiểm tra Demo Role Switcher
      expect(find.textContaining('Demo Role Switcher'), findsOneWidget);
    });

    testWidgets('Bấm Đổi mật khẩu tài khoản mở Hộp thoại Re-authentication (Khóa Bẫy 4)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      final cartProvider = CartProvider();
      final orderProvider = OrderProvider();
      final notiProvider = NotificationProvider();
      final chatProvider = ChatProvider();

      final user = UserModel(
        uid: 'user_profile_2',
        email: 'pass.change@example.com',
        fullName: 'Lê Hoàng Yến',
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notiProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tìm và bấm vào mục Đổi mật khẩu tài khoản
      await tester.tap(find.text('Đổi mật khẩu tài khoản'));
      await tester.pumpAndSettle();

      // Kiểm tra Hộp thoại Đổi mật khẩu an toàn
      expect(find.text('ĐỔI MẬT KHẨU AN TOÀN'), findsOneWidget);
      expect(find.textContaining('Mật khẩu hiện tại'), findsOneWidget);
      expect(find.textContaining('Mật khẩu mới'), findsOneWidget);
      expect(find.textContaining('Xác nhận mật khẩu mới'), findsOneWidget);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);

      // Bấm nút Hủy để đóng dialog
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('ĐỔI MẬT KHẨU AN TOÀN'), findsNothing);
    });
  });
}
