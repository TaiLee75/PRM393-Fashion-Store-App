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
  });
}
