import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/screens/main_nav_screen.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/providers/notification_provider.dart';
import 'package:fashion_store_app/providers/chat_provider.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/models/notification_model.dart';

void main() {
  group('Kiểm thử Giao diện & Điều hướng Cốt lõi (Task 3.1 - MainNavScreen Test)', () {
    late AuthProvider authProvider;
    late CartProvider cartProvider;
    late OrderProvider orderProvider;
    late NotificationProvider notiProvider;
    late ChatProvider chatProvider;
    late ProductProvider productProvider;

    setUp(() {
      authProvider = AuthProvider();
      cartProvider = CartProvider();
      orderProvider = OrderProvider();
      notiProvider = NotificationProvider();
      chatProvider = ChatProvider();
      productProvider = ProductProvider();

      // Mock user login
      authProvider.setMockUser(
        UserModel(
          uid: 'test_user_31',
          email: 'test31@example.com',
          fullName: 'Test User 3.1',
          role: 'customer',
          createdAt: DateTime.now(),
        ),
      );

      // Seed a mock product
      productProvider.setMockProducts([
        const ProductModel(
          id: 'prod_1',
          name: 'Áo thun Uniqlo Test',
          categoryId: 'cat_aothun',
          price: 299000,
          description: 'Mô tả test',
          imageUrls: ['https://example.com/a.jpg'],
          sizes: ['M', 'L'],
          colors: ['Trắng'],
          stock: 50,
          isActive: true,
        ),
      ]);
    });

    Widget buildTestableWidget({int initialIndex = 0}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
          ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ChangeNotifierProvider<NotificationProvider>.value(value: notiProvider),
          ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
        ],
        child: MaterialApp(
          home: MainNavScreen(
            key: ValueKey(authProvider.userId),
            initialIndex: initialIndex,
          ),
        ),
      );
    }

    testWidgets('1. MainNavScreen khởi tạo thành công 5 tab Uniqlo và Brand Header',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kiểm tra Header Brand UNI-PRM FASHION STORE
      expect(find.text('UNI-PRM'), findsOneWidget);
      expect(find.text('FASHION STORE'), findsOneWidget);

      // Kiểm tra 5 tab trong BottomNavigationBar
      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Giỏ hàng'), findsOneWidget);
      expect(find.text('Đơn hàng'), findsOneWidget);
      expect(find.text('Tư vấn'), findsOneWidget);
      expect(find.text('Tài khoản'), findsOneWidget);
    });

    testWidgets('2. Badge hiển thị số lượng tin nhắn chưa đọc trên Tab Tư vấn và biến mất khi mở Tab',
        (WidgetTester tester) async {
      // Mock có 3 tin nhắn chưa đọc từ Admin
      chatProvider.setMockUnreadCustomerCount(3);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tìm Badge số 3 trên tab Tư vấn
      expect(find.text('3'), findsOneWidget);

      // Chạm vào tab Tư vấn (Tab index 3)
      await tester.tap(find.text('Tư vấn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sau khi chạm vào tab Tư vấn, chatProvider.unreadCustomerCount được reset về 0 (badge biến mất)
      expect(chatProvider.unreadCustomerCount, 0);
    });

    testWidgets('3. Badge thông báo chưa đọc hiển thị trên AppBar icon chuông',
        (WidgetTester tester) async {
      // Mock có 2 thông báo chưa đọc
      notiProvider.setMockNotifications([
        NotificationModel(
          id: 'n1',
          userId: 'test_user_31',
          title: 'Đơn hàng mới',
          body: 'Đơn #123 đang giao',
          createdAt: DateTime.now(),
          isRead: false,
        ),
        NotificationModel(
          id: 'n2',
          userId: 'test_user_31',
          title: 'Khuyến mãi hot',
          body: 'Voucher SALE10',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ]);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tìm Badge số 2 trên AppBar
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('4. switchToTab chuyển tab mượt mà và pop màn hình con đã push về root',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Đẩy 1 màn hình con lên Navigator stack
      bool wasPressed = false;
      final navContext = tester.element(find.byType(MainNavScreen));
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Sub Screen Pushed')),
            body: Builder(
              builder: (subCtx) => ElevatedButton(
                onPressed: () {
                  wasPressed = true;
                  MainNavScreen.switchToTab(subCtx, 2);
                },
                child: const Text('Click Switch To Orders'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Kiểm tra đang ở màn hình con
      expect(find.text('Sub Screen Pushed'), findsOneWidget);

      // Bấm nút chuyển tab từ màn hình con
      await tester.tap(find.text('Click Switch To Orders'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(wasPressed, isTrue);
      expect(find.text('Sub Screen Pushed'), findsNothing);
      expect(find.byType(MainNavScreen), findsOneWidget);

      // BottomNavigationBar đang ở tab Đơn hàng (index 2)
      final bottomNav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(bottomNav.currentIndex, 2);
    });
  });
}
