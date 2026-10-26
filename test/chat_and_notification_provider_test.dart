import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/message_model.dart';
import 'package:fashion_store_app/models/notification_model.dart';
import 'package:fashion_store_app/providers/chat_provider.dart';
import 'package:fashion_store_app/providers/notification_provider.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

/// Fake FirestoreService phục vụ kiểm thử cho ChatProvider & NotificationProvider (Task 2.5)
class FakeFirestoreServiceForChatAndNotif extends FirestoreService {
  final Map<String, List<MessageModel>> messagesDb = {};
  final List<Map<String, dynamic>> chatRoomsDb = [];
  final Map<String, List<NotificationModel>> notificationsDb = {};

  final Map<String, StreamController<List<MessageModel>>> _msgControllers = {};
  final StreamController<List<Map<String, dynamic>>> _roomsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final Map<String, StreamController<List<NotificationModel>>> _notifControllers = {};

  StreamController<List<MessageModel>> _getOrCreateMsgController(String customerId) {
    return _msgControllers.putIfAbsent(
      customerId,
      () => StreamController<List<MessageModel>>.broadcast(),
    );
  }

  StreamController<List<NotificationModel>> _getOrCreateNotifController(String userId) {
    return _notifControllers.putIfAbsent(
      userId,
      () => StreamController<List<NotificationModel>>.broadcast(),
    );
  }

  @override
  Stream<List<MessageModel>> streamMessages(String customerId) {
    return _getOrCreateMsgController(customerId).stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> streamAllChats() {
    return _roomsController.stream;
  }

  @override
  Future<void> sendMessage({
    required String customerId,
    required MessageModel message,
    String? customerName,
    bool isFromAdmin = false,
  }) async {
    final list = messagesDb.putIfAbsent(customerId, () => []);
    final savedMsg = message.copyWith(id: 'msg_${DateTime.now().millisecondsSinceEpoch}');
    list.add(savedMsg);
    _getOrCreateMsgController(customerId).add(List.from(list));

    // Cập nhật room
    final roomIndex = chatRoomsDb.indexWhere((r) => r['customerId'] == customerId);
    if (roomIndex >= 0) {
      chatRoomsDb[roomIndex]['lastMessage'] = message.text;
      if (isFromAdmin) {
        chatRoomsDb[roomIndex]['unreadByCustomer'] =
            ((chatRoomsDb[roomIndex]['unreadByCustomer'] as int? ?? 0) + 1);
      } else {
        chatRoomsDb[roomIndex]['unreadByAdmin'] =
            ((chatRoomsDb[roomIndex]['unreadByAdmin'] as int? ?? 0) + 1);
      }
    } else {
      chatRoomsDb.add({
        'customerId': customerId,
        'userName': customerName ?? 'Khách',
        'lastMessage': message.text,
        'unreadByAdmin': isFromAdmin ? 0 : 1,
        'unreadByCustomer': isFromAdmin ? 1 : 0,
      });
    }
    _roomsController.add(List.from(chatRoomsDb));
  }

  @override
  Future<void> markChatAsReadByAdmin(String customerId) async {
    final roomIndex = chatRoomsDb.indexWhere((r) => r['customerId'] == customerId);
    if (roomIndex >= 0) {
      chatRoomsDb[roomIndex]['unreadByAdmin'] = 0;
      _roomsController.add(List.from(chatRoomsDb));
    }
  }

  @override
  Future<void> markChatAsReadByCustomer(String customerId) async {
    final roomIndex = chatRoomsDb.indexWhere((r) => r['customerId'] == customerId);
    if (roomIndex >= 0) {
      chatRoomsDb[roomIndex]['unreadByCustomer'] = 0;
      _roomsController.add(List.from(chatRoomsDb));
    }
  }

  @override
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _getOrCreateNotifController(userId).stream;
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    for (final list in notificationsDb.values) {
      final index = list.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        list[index] = list[index].copyWith(isRead: true);
      }
    }
  }

  void dispose() {
    for (final c in _msgControllers.values) {
      c.close();
    }
    _roomsController.close();
    for (final c in _notifControllers.values) {
      c.close();
    }
  }
}

void main() {
  group('Kiểm thử Đơn vị Toàn diện (Unit Test) cho ChatProvider (Task 2.5):', () {
    late FakeFirestoreServiceForChatAndNotif fakeService;
    late ChatProvider chatProvider;

    setUp(() {
      fakeService = FakeFirestoreServiceForChatAndNotif();
      chatProvider = ChatProvider(firestoreService: fakeService);
    });

    tearDown(() {
      fakeService.dispose();
      chatProvider.dispose();
    });

    test('1. Khởi tạo ban đầu: Danh sách tin nhắn rỗng và bộ đếm bằng 0', () {
      expect(chatProvider.messages, isEmpty);
      expect(chatProvider.customerMessages, isEmpty);
      expect(chatProvider.adminMessages, isEmpty);
      expect(chatProvider.adminChatRooms, isEmpty);
      expect(chatProvider.unreadAdminTotal, 0);
      expect(chatProvider.isLoading, isFalse);
      expect(chatProvider.isAdminLoading, isFalse);
    });

    test('2. Mock dữ liệu và tính tổng tin nhắn chưa đọc của Admin (unreadAdminTotal)', () {
      final mockRooms = [
        {
          'customerId': 'cust_01',
          'userName': 'Khách A',
          'lastMessage': 'Alo shop',
          'unreadByAdmin': 3,
        },
        {
          'customerId': 'cust_02',
          'userName': 'Khách B',
          'lastMessage': 'Size L còn không?',
          'unreadByAdmin': 2,
        },
      ];

      chatProvider.setMockAdminChatRooms(mockRooms);
      expect(chatProvider.adminChatRooms.length, 2);
      expect(chatProvider.unreadAdminTotal, 5); // 3 + 2 = 5
    });

    test('3. Gửi tin nhắn văn bản thông thường thành công', () async {
      final ok = await chatProvider.sendMessage(
        customerId: 'customer_123',
        text: 'Shop tư vấn giúp mình mẫu áo polo với!',
        senderId: 'customer_123',
        customerName: 'Hoàng Nam',
      );

      expect(ok, isTrue);
      expect(fakeService.messagesDb['customer_123']!.length, 1);
      final msg = fakeService.messagesDb['customer_123']!.first;
      expect(msg.text, 'Shop tư vấn giúp mình mẫu áo polo với!');
      expect(msg.hasOrderAttachment, isFalse);
      expect(msg.hasProductAttachment, isFalse);
    });

    test('4. Đính kèm thẻ ngữ cảnh đơn hàng (Contextual Order Card)', () async {
      final ok = await chatProvider.sendMessage(
        customerId: 'customer_123',
        text: 'Đơn này của mình khi nào giao vậy shop?',
        senderId: 'customer_123',
        orderId: 'ORD_20261026_001',
        orderTotalPrice: 550000,
      );

      expect(ok, isTrue);
      final msg = fakeService.messagesDb['customer_123']!.first;
      expect(msg.hasOrderAttachment, isTrue);
      expect(msg.orderId, 'ORD_20261026_001');
      expect(msg.orderTotalPrice, 550000);
    });

    test('5. Đính kèm thẻ ngữ cảnh sản phẩm (Contextual Product Card)', () async {
      final ok = await chatProvider.sendMessage(
        customerId: 'customer_123',
        text: 'Mẫu áo này còn màu Trắng size L không ạ?',
        senderId: 'customer_123',
        productId: 'prod_polo_01',
        productName: 'Áo Polo Lifewear Classic',
        productImageUrl: 'https://example.com/polo.jpg',
      );

      expect(ok, isTrue);
      final msg = fakeService.messagesDb['customer_123']!.first;
      expect(msg.hasProductAttachment, isTrue);
      expect(msg.productId, 'prod_polo_01');
      expect(msg.productName, 'Áo Polo Lifewear Classic');
    });

    test('6. Chặn gửi tin nhắn rỗng không có đính kèm', () async {
      final ok = await chatProvider.sendMessage(
        customerId: 'customer_123',
        text: '   ',
        senderId: 'customer_123',
      );
      expect(ok, isFalse);
    });

    test('7. Khóa Bẫy 7 (IndexedStack Freeze Prevention): Tách biệt luồng Customer và Admin', () {
      // Khách hàng đang ở Tab 3 lắng nghe tin nhắn của chính mình
      chatProvider.setMockMessages([
        MessageModel(
          id: 'cust_msg_01',
          senderId: 'customer_A',
          text: 'Tin nhắn riêng của khách A',
          createdAt: DateTime.now(),
        ),
      ]);

      // Admin mở chi tiết phòng chat của khách B
      chatProvider.setMockAdminMessages([
        MessageModel(
          id: 'admin_view_msg_01',
          senderId: 'customer_B',
          text: 'Tin nhắn của khách B gửi shop',
          createdAt: DateTime.now(),
        ),
      ]);

      // Kiểm tra: 2 luồng hoàn toàn độc lập, không bị ghi đè lẫn nhau!
      expect(chatProvider.messages.length, 1);
      expect(chatProvider.messages.first.text, 'Tin nhắn riêng của khách A');
      expect(chatProvider.adminMessages.length, 1);
      expect(chatProvider.adminMessages.first.text, 'Tin nhắn của khách B gửi shop');

      // Admin đóng phòng chat
      chatProvider.closeAdminActiveChat();
      expect(chatProvider.adminMessages, isEmpty);
      // Tin nhắn của khách vẫn nguyên vẹn
      expect(chatProvider.messages.length, 1);
    });

    test('8. Đánh dấu đã đọc phòng chat (markChatAsReadByAdmin & ByCustomer) kèm Optimistic UI', () async {
      final room = {
        'customerId': 'customer_test',
        'userName': 'Khách Test',
        'lastMessage': 'Xin chào',
        'unreadByAdmin': 4,
        'unreadByCustomer': 2,
      };
      fakeService.chatRoomsDb.add(room);
      chatProvider.setMockAdminChatRooms([room]);
      expect(chatProvider.unreadAdminTotal, 4);

      // Đánh dấu Admin đã đọc -> Optimistic UI lập tức đưa unreadByAdmin về 0
      await chatProvider.markChatAsReadByAdmin('customer_test');
      expect(fakeService.chatRoomsDb.first['unreadByAdmin'], 0);
      expect(chatProvider.adminChatRooms.first['unreadByAdmin'], 0);
      expect(chatProvider.unreadAdminTotal, 0);

      await chatProvider.markChatAsReadByCustomer('customer_test');
      expect(fakeService.chatRoomsDb.first['unreadByCustomer'], 0);
    });

    test('9. Khóa Bẫy 13: resetSession của ChatProvider dọn sạch 100% RAM khi đăng xuất', () {
      chatProvider.setMockMessages([
        MessageModel(
          id: 'm1',
          senderId: 'user',
          text: 'test',
          createdAt: DateTime.now(),
        ),
      ]);
      chatProvider.setMockAdminChatRooms([
        {'customerId': 'c1', 'unreadByAdmin': 2},
      ]);

      expect(chatProvider.messages, isNotEmpty);
      expect(chatProvider.adminChatRooms, isNotEmpty);

      // Đăng xuất
      chatProvider.resetSession();

      expect(chatProvider.messages, isEmpty);
      expect(chatProvider.customerMessages, isEmpty);
      expect(chatProvider.adminMessages, isEmpty);
      expect(chatProvider.adminChatRooms, isEmpty);
      expect(chatProvider.currentCustomerId, isNull);
      expect(chatProvider.adminActiveCustomerId, isNull);
      expect(chatProvider.unreadAdminTotal, 0);
    });
  });

  group('Kiểm thử Đơn vị Toàn diện (Unit Test) cho NotificationProvider (Task 2.5):', () {
    late FakeFirestoreServiceForChatAndNotif fakeService;
    late NotificationProvider notifProvider;

    final sampleNotifications = [
      NotificationModel(
        id: 'notif_001',
        userId: 'user_01',
        title: 'Đơn hàng đã được xác nhận',
        body: 'Đơn #ORD_001 đang chuẩn bị hàng',
        orderId: 'ORD_001',
        type: NotificationModel.typeOrderUpdate,
        isRead: false,
        createdAt: DateTime.now(),
      ),
      NotificationModel(
        id: 'notif_002',
        userId: 'user_01',
        title: 'Mã giảm giá mới: SALE10',
        body: 'Giảm 10% tối đa 50k cho đơn hàng từ 200k',
        type: NotificationModel.typePromotion,
        isRead: false,
        createdAt: DateTime.now(),
      ),
      NotificationModel(
        id: 'notif_003',
        userId: 'user_01',
        title: 'Đơn hàng cũ đã giao',
        body: 'Đơn #ORD_000 đã giao thành công',
        orderId: 'ORD_000',
        type: NotificationModel.typeOrderUpdate,
        isRead: true, // Đã đọc
        createdAt: DateTime.now(),
      ),
    ];

    setUp(() {
      fakeService = FakeFirestoreServiceForChatAndNotif();
      fakeService.notificationsDb['user_01'] = List.from(sampleNotifications);
      notifProvider = NotificationProvider(firestoreService: fakeService);
    });

    tearDown(() {
      fakeService.dispose();
      notifProvider.dispose();
    });

    test('10. Khởi tạo và mock thông báo: Đếm unreadCount chính xác', () {
      notifProvider.setMockNotifications(sampleNotifications);
      expect(notifProvider.notifications.length, 3);
      expect(notifProvider.unreadCount, 2); // 2 chưa đọc (notif_001, notif_002)
    });

    test('11. Bộ lọc thông báo (orderNotifications & promoNotifications)', () {
      notifProvider.setMockNotifications(sampleNotifications);
      expect(notifProvider.orderNotifications.length, 2);
      expect(notifProvider.promoNotifications.length, 1);
      expect(notifProvider.promoNotifications.first.id, 'notif_002');
    });

    test('12. Đánh dấu 1 thông báo đã đọc (markAsRead) với Optimistic UI', () async {
      notifProvider.setMockNotifications(sampleNotifications);
      expect(notifProvider.unreadCount, 2);

      await notifProvider.markAsRead('notif_001');

      // Optimistic: Ngay lập tức giảm unreadCount còn 1
      expect(notifProvider.unreadCount, 1);
      final readNotif = notifProvider.notifications.firstWhere((n) => n.id == 'notif_001');
      expect(readNotif.isRead, isTrue);
    });

    test('13. Đánh dấu tất cả thông báo đã đọc (markAllAsRead)', () async {
      notifProvider.setMockNotifications(sampleNotifications);
      expect(notifProvider.unreadCount, 2);

      await notifProvider.markAllAsRead();

      // Toàn bộ thông báo chuyển sang đã đọc và unreadCount = 0
      expect(notifProvider.unreadCount, 0);
      expect(notifProvider.notifications.every((n) => n.isRead), isTrue);
    });

    test('14. Khóa Bẫy 13: resetSession của NotificationProvider dọn sạch RAM khi đăng xuất', () {
      notifProvider.setMockNotifications(sampleNotifications);
      expect(notifProvider.notifications, isNotEmpty);

      // Đăng xuất
      notifProvider.resetSession();

      expect(notifProvider.notifications, isEmpty);
      expect(notifProvider.unreadCount, 0);
      expect(notifProvider.activeUserId, isNull);
      expect(notifProvider.isLoading, isFalse);
    });

    test('15. Tra cứu thông báo theo ID (findById)', () {
      notifProvider.setMockNotifications(sampleNotifications);
      expect(notifProvider.findById('notif_001'), isNotNull);
      expect(notifProvider.findById('notif_001')!.orderId, 'ORD_001');
      expect(notifProvider.findById('not_found'), isNull);
    });
  });
}
