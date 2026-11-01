import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/message_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/chat_provider.dart';
import 'package:fashion_store_app/screens/chat/chat_screen.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

class FakeFirestoreServiceWithMsgs extends FirestoreService {
  final _msgController = StreamController<List<MessageModel>>.broadcast();

  @override
  Stream<List<MessageModel>> streamMessages(String customerId) {
    return _msgController.stream;
  }
}

void main() {
  group('Kiểm thử Giao diện ChatScreen (PRM393 - Member 5)', () {
    testWidgets('ChatScreen isStandalone: false hiển thị khung tư vấn và tin nhắn',
        (tester) async {
      final fakeService = FakeFirestoreServiceWithMsgs();
      final chatProvider = ChatProvider(firestoreService: fakeService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatScreen(isStandalone: false),
            ),
          ),
        ),
      );

      // Phát tin nhắn mô phỏng
      fakeService._msgController.add([
        MessageModel(
          id: '1',
          senderId: 'guest_customer',
          text: 'Mình cao 1m75 nặng 68kg mặc size gì?',
          createdAt: DateTime.now(),
        ),
        MessageModel(
          id: '2',
          senderId: 'shop_admin',
          text: 'Chào bạn, với chiều cao và cân nặng này bạn mặc size L là vừa đẹp nhé!',
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pump();
      expect(find.text('Mình cao 1m75 nặng 68kg mặc size gì?'), findsOneWidget);
      expect(
        find.text('Chào bạn, với chiều cao và cân nặng này bạn mặc size L là vừa đẹp nhé!'),
        findsOneWidget,
      );
      expect(find.text('BẠN'), findsOneWidget);
      expect(find.text('TƯ VẤN VIÊN (SHOP)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('ChatScreen isStandalone: true có AppBar "TƯ VẤN KHÁCH HÀNG"',
        (tester) async {
      final fakeService = FakeFirestoreServiceWithMsgs();
      final chatProvider = ChatProvider(firestoreService: fakeService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: ChatScreen(isStandalone: true),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('TƯ VẤN KHÁCH HÀNG'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('ChatScreen hiển thị thanh đính kèm sản phẩm đang chờ gửi và nút xóa',
        (tester) async {
      final fakeService = FakeFirestoreServiceWithMsgs();
      final chatProvider = ChatProvider(firestoreService: fakeService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: ChatScreen(
              isStandalone: true,
              initialProductId: 'prod_101',
              initialProductName: 'Áo Thun Basic Coolmate',
              initialProductImageUrl: 'https://example.com/aothun.png',
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Đính kèm sản phẩm: Áo Thun Basic Coolmate'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);

      // Nhấn nút xóa đính kèm
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('Đính kèm sản phẩm: Áo Thun Basic Coolmate'), findsNothing);
    });

    testWidgets('ChatScreen hiển thị thanh đính kèm đơn hàng đang chờ gửi',
        (tester) async {
      final fakeService = FakeFirestoreServiceWithMsgs();
      final chatProvider = ChatProvider(firestoreService: fakeService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: ChatScreen(
              isStandalone: true,
              initialOrderId: 'ORDER_999888',
              initialOrderTotalPrice: 350000,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.textContaining('Đính kèm đơn hàng #ORDER_99'), findsOneWidget);
    });

    testWidgets('ChatScreen và AdminChatDetailScreen render thẻ đính kèm Order & Product trong tin nhắn',
        (tester) async {
      final fakeService = FakeFirestoreServiceWithMsgs();
      final chatProvider = ChatProvider(firestoreService: fakeService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatScreen(isStandalone: false),
            ),
          ),
        ),
      );

      // Phát các tin nhắn có đính kèm đơn hàng và sản phẩm
      fakeService._msgController.add([
        MessageModel(
          id: 'msg_order_1',
          senderId: 'guest_customer',
          text: 'Xin hỗ trợ kiểm tra đơn hàng này',
          createdAt: DateTime.now(),
          orderId: 'ORDER_12345678',
          orderTotalPrice: 299000,
        ),
        MessageModel(
          id: 'msg_prod_1',
          senderId: 'guest_customer',
          text: 'Mẫu áo này còn màu trắng size L không ạ?',
          createdAt: DateTime.now(),
          productId: 'prod_99',
          productName: 'Áo Khoác Bomber Lifewear',
          productImageUrl: '',
        ),
      ]);

      await tester.pump();

      // Kiểm tra thẻ đơn hàng trong bubble
      expect(find.text('Đơn hàng #ORDER_12'), findsOneWidget);
      expect(find.text('Xin hỗ trợ kiểm tra đơn hàng này'), findsOneWidget);

      // Kiểm tra thẻ sản phẩm trong bubble
      expect(find.text('Áo Khoác Bomber Lifewear'), findsOneWidget);
      expect(find.text('Mẫu áo này còn màu trắng size L không ạ?'), findsOneWidget);
    });
  });
}
