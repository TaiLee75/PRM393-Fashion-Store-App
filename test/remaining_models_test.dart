import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/models/notification_model.dart';
import 'package:fashion_store_app/models/message_model.dart';

void main() {
  group('Remaining Models Enterprise Unit Tests:', () {
    test('1. CartItemModel: isSelected flag, quantity guard, variant helpers, and serialization', () {
      final oldCartMap = {
        'cartItemId': 'prod_01_M_Đen',
        'productId': 'prod_01',
        'productName': 'Áo Polo',
        'imageUrl': 'https://example.com/polo.jpg',
        'price': 220000,
        'size': 'M',
        'color': 'Đen',
        'quantity': 0, // Dữ liệu lỗi quantity <= 0
      };

      // Tương thích ngược: mặc định isSelected = true, quantity bảo vệ tối thiểu là 1
      final itemDefault = CartItemModel.fromMap(oldCartMap);
      expect(itemDefault.isSelected, isTrue);
      expect(itemDefault.quantity, 1);
      expect(itemDefault.itemTotal, 220000);
      expect(itemDefault.variantSku, 'M_Đen');
      expect(itemDefault.isSameVariant('M', 'Đen'), isTrue);
      expect(itemDefault.isSameVariant('L', 'Đen'), isFalse);

      // Trường hợp phụ kiện không có màu (FreeSize)
      const noColorItem = CartItemModel(
        cartItemId: 'prod_hat_FreeSize',
        productId: 'prod_hat',
        productName: 'Mũ Lưỡi Trai',
        imageUrl: 'https://example.com/hat.jpg',
        price: 150000,
        size: 'FreeSize',
        color: '',
        quantity: 1,
      );
      expect(noColorItem.variantSku, 'FreeSize');

      // Khi bỏ tick chọn
      final unselectedItem = itemDefault.copyWith(isSelected: false);
      expect(unselectedItem.isSelected, isFalse);
      expect(unselectedItem.toMap()['isSelected'], isFalse);
      expect(unselectedItem, equals(itemDefault)); // Cùng cartItemId
    });

    test('2. UserModel: savedAddresses, effectiveDefaultAddress, role normalization, and measurements', () {
      final oldUserMap = {
        'uid': 'usr_old_01',
        'email': 'old@example.com',
        'fullName': 'Nguyễn Văn Cũ',
        'phone': '0901234567',
        'avatarUrl': '',
        'defaultAddress': '123 Đường Cũ, Q1',
        'role': 'CUSTOMER', // Chữ hoa
        'createdAt': '2026-10-20T10:00:00Z',
      };

      // Tương thích ngược
      final userOld = UserModel.fromMap(oldUserMap);
      expect(userOld.savedAddresses.isEmpty, isTrue);
      expect(userOld.wishlistProductIds.isEmpty, isTrue);
      expect(userOld.bodyMeasurements, isNull);
      expect(userOld.savedHeight, isNull);
      expect(userOld.savedWeight, isNull);
      expect(userOld.isAdmin, isFalse);
      expect(userOld.effectiveDefaultAddress, '123 Đường Cũ, Q1');

      // Doanh nghiệp hoàn chỉnh với Map dynamic lồng nhau từ Firestore
      final Map<dynamic, dynamic> dynamicUserMap = {
        'uid': 'usr_vip_02',
        'email': 'vip@example.com',
        'fullName': 'Trần Thị VIP',
        'role': 'ADMIN', // Test chuẩn hóa case-insensitive
        'defaultAddress': 'Địa chỉ cũ',
        'createdAt': '2026-10-25T08:00:00Z',
        'savedAddresses': <dynamic>[
          <dynamic, dynamic>{
            'id': 'addr_1',
            'label': 'Văn phòng',
            'address': 'Toà Keangnam, Hà Nội',
            'isDefault': false,
          },
          <dynamic, dynamic>{
            'id': 'addr_2',
            'label': 'Nhà riêng',
            'recipientName': 'Trần Thị VIP',
            'phone': '0988889999',
            'address': 'Toà Landmark 81, Bình Thạnh',
            'isDefault': true,
          }
        ],
        'wishlistProductIds': <dynamic>['prod_polo_01', 'prod_jean_02'],
        'bodyMeasurements': <dynamic, dynamic>{
          'height': 168,
          'weight': 52.5,
        },
      };

      final safeMap = Map<String, dynamic>.from(dynamicUserMap);
      final userVip = UserModel.fromMap(safeMap);

      expect(userVip.isAdmin, isTrue);
      expect(userVip.savedAddresses.length, 2);
      expect(userVip.effectiveDefaultAddress, 'Toà Landmark 81, Bình Thạnh'); // Ưu tiên địa chỉ mặc định
      expect(userVip.wishlistProductIds.length, 2);
      expect(userVip.isFavorite('prod_polo_01'), isTrue);
      expect(userVip.isFavorite('prod_other_99'), isFalse);
      expect(userVip.savedHeight, 168.0);
      expect(userVip.savedWeight, 52.5);

      final mapOutput = userVip.toMap();
      expect(mapOutput['savedAddresses'].length, 2);
      expect(mapOutput['wishlistProductIds'], contains('prod_jean_02'));
    });

    test('3. NotificationModel: orderId, type, and order notification check', () {
      final oldNotifMap = {
        'id': 'notif_001',
        'userId': 'usr_01',
        'title': 'Khuyến mãi hè',
        'body': 'Giảm giá lên đến 50%',
        'isRead': false,
        'createdAt': '2026-10-25T09:00:00Z',
      };

      final notifOld = NotificationModel.fromMap(oldNotifMap);
      expect(notifOld.orderId, isNull);
      expect(notifOld.type, NotificationModel.typeSystem);
      expect(notifOld.isOrderNotification, isFalse);

      final orderNotifMap = {
        'id': 'notif_002',
        'userId': 'usr_01',
        'title': 'Đơn hàng đang giao',
        'body': 'Đơn #ord_999 đang trên đường tới bạn',
        'isRead': false,
        'createdAt': '2026-10-25T11:00:00Z',
        'orderId': 'ord_999',
        'type': NotificationModel.typeOrderUpdate,
      };

      final notifOrder = NotificationModel.fromMap(orderNotifMap);
      expect(notifOrder.orderId, 'ord_999');
      expect(notifOrder.type, NotificationModel.typeOrderUpdate);
      expect(notifOrder.isOrderNotification, isTrue);
    });

    test('4. MessageModel: sender helper, order and product attachment contextual cards', () {
      final textOnlyMap = {
        'id': 'msg_01',
        'senderId': 'usr_01',
        'text': 'Chào shop, tư vấn giúp em',
        'createdAt': '2026-10-25T12:00:00Z',
      };

      final msgText = MessageModel.fromMap(textOnlyMap);
      expect(msgText.isSentBy('usr_01'), isTrue);
      expect(msgText.isSentBy('admin_01'), isFalse);
      expect(msgText.hasOrderAttachment, isFalse);
      expect(msgText.hasProductAttachment, isFalse);

      final attachmentMap = {
        'id': 'msg_02',
        'senderId': 'usr_01',
        'text': 'Shop ơi size L này 75kg mặc vừa không?',
        'createdAt': '2026-10-25T12:05:00Z',
        'orderId': 'ord_777',
        'productId': 'prod_polo_01',
        'productName': 'Áo Polo Thể Thao',
        'productImageUrl': 'https://example.com/polo.jpg',
      };

      final msgAttach = MessageModel.fromMap(attachmentMap);
      expect(msgAttach.hasOrderAttachment, isTrue);
      expect(msgAttach.hasProductAttachment, isTrue);
      expect(msgAttach.orderId, 'ord_777');
      expect(msgAttach.productName, 'Áo Polo Thể Thao');
      expect(msgAttach.productImageUrl, 'https://example.com/polo.jpg');

      final mapOutput = msgAttach.toMap();
      expect(mapOutput['orderId'], 'ord_777');
      expect(mapOutput['productName'], 'Áo Polo Thể Thao');
    });
  });
}
