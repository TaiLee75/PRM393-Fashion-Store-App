import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý tin nhắn tư vấn trực tuyến thời gian thực (MVVM):
/// - Tách biệt 2 Stream độc lập cho Khách hàng (Tab 3) và Admin (Khóa Bẫy 7 - Chống đơ IndexedStack).
/// - Hỗ trợ đính kèm thẻ ngữ cảnh tư vấn: Thẻ đơn hàng (orderId, orderTotalPrice) & Thẻ sản phẩm (productId, productName, productImageUrl).
/// - Quản lý số lượng tin nhắn chưa đọc (Unread Badges) cho cả khách hàng và Admin.
/// - Quản trị phiên đăng xuất an toàn (Khóa Bẫy 13).
class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<MessageModel> _customerMessages = [];
  List<MessageModel> _adminMessages = [];
  List<Map<String, dynamic>> _adminChatRooms = [];

  String? _currentCustomerId;
  String? _adminActiveCustomerId;
  bool _isLoading = false;
  bool _isAdminLoading = false;

  StreamSubscription<List<MessageModel>>? _customerMessagesSub;
  StreamSubscription<Map<String, dynamic>?>? _customerRoomSub;
  StreamSubscription<List<MessageModel>>? _adminMessagesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _adminChatsSub;

  int _unreadCustomerCount = 0;

  ChatProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  // Getters tương thích ngược và phân tách luồng
  /// Danh sách tin nhắn của khách hàng (Tab 3) - Phục vụ tương thích ngược với ChatScreen
  List<MessageModel> get messages => List.unmodifiable(_customerMessages);

  /// Danh sách tin nhắn của khách hàng hiện tại
  List<MessageModel> get customerMessages => List.unmodifiable(_customerMessages);

  /// Danh sách tin nhắn phòng chat đang mở của Admin
  List<MessageModel> get adminMessages => List.unmodifiable(_adminMessages);

  /// Danh sách tất cả phòng chat (dành cho Admin)
  List<Map<String, dynamic>> get adminChatRooms =>
      List.unmodifiable(_adminChatRooms);

  bool get isLoading => _isLoading;
  bool get isAdminLoading => _isAdminLoading;
  String? get currentCustomerId => _currentCustomerId;
  String? get adminActiveCustomerId => _adminActiveCustomerId;

  /// Tổng số tin nhắn chưa đọc của khách hàng hiện tại (hiển thị Badge đỏ trên Tab 3)
  int get unreadCustomerCount => _unreadCustomerCount;

  /// Tương thích ngược: unreadCount trả về số tin chưa đọc của khách
  int get unreadCount => _unreadCustomerCount;

  /// Tổng số tin nhắn chưa đọc của tất cả các phòng chat (hiển thị Badge đỏ trên Tab Admin)
  int get unreadAdminTotal {
    return _adminChatRooms.fold<int>(0, (sum, room) {
      final unread = (room['unreadByAdmin'] as num?)?.toInt() ?? 0;
      return sum + unread;
    });
  }

  // ==========================================
  // 1. MOCK DỮ LIỆU PHỤC VỤ TEST (TEST COMPATIBILITY)
  // ==========================================

  void setMockMessages(List<MessageModel> list) {
    _customerMessages = List.from(list);
    notifyListeners();
  }

  void setMockAdminMessages(List<MessageModel> list) {
    _adminMessages = List.from(list);
    notifyListeners();
  }

  void setMockAdminChatRooms(List<Map<String, dynamic>> rooms) {
    _adminChatRooms = List.from(rooms);
    notifyListeners();
  }

  void setMockUnreadCustomerCount(int count) {
    _unreadCustomerCount = count;
    notifyListeners();
  }

  // ==========================================
  // 2. LẮNG NGHE TIN NHẮN KHÁCH HÀNG (CUSTOMER STREAM - TAB 3)
  // ==========================================

  /// Lắng nghe tin nhắn trong phòng chat của khách hàng hiện tại (Tab 3)
  void listenMessages(String customerId) {
    if (customerId.trim().isEmpty) return;

    if (_currentCustomerId == customerId && _customerMessagesSub != null) {
      return;
    }

    _customerMessagesSub?.cancel();
    _customerRoomSub?.cancel();
    _currentCustomerId = customerId;
    _isLoading = true;
    notifyListeners();

    try {
      _customerMessagesSub =
          _firestoreService.streamMessages(customerId).listen((msgs) {
        _customerMessages = msgs;
        _isLoading = false;
        notifyListeners();
      }, onError: (_) {
        _isLoading = false;
        notifyListeners();
      });

      _customerRoomSub =
          _firestoreService.streamChatRoom(customerId).listen((roomData) {
        if (roomData != null) {
          _unreadCustomerCount =
              (roomData['unreadByCustomer'] as num?)?.toInt() ?? 0;
          notifyListeners();
        }
      }, onError: (_) {});
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // 3. LẮNG NGHE TIN NHẮN PHÒNG CHAT ADMIN (ADMIN STREAM - KHÓA BẪY 7)
  // ==========================================

  /// Lắng nghe tin nhắn trong 1 phòng chat cụ thể khi Admin click vào xem
  /// (Tách biệt hoàn toàn khỏi _customerMessages để không gây xung đột trên device demo)
  void listenAdminActiveChat(String customerId) {
    if (customerId.trim().isEmpty) return;

    if (_adminActiveCustomerId == customerId && _adminMessagesSub != null) {
      return;
    }

    _adminMessagesSub?.cancel();
    _adminActiveCustomerId = customerId;
    _isAdminLoading = true;
    notifyListeners();

    try {
      _adminMessagesSub =
          _firestoreService.streamMessages(customerId).listen((msgs) {
        _adminMessages = msgs;
        _isAdminLoading = false;
        notifyListeners();
      }, onError: (_) {
        _isAdminLoading = false;
        notifyListeners();
      });
    } catch (_) {
      _isAdminLoading = false;
      notifyListeners();
    }
  }

  /// Đóng phòng chat Admin đang xem để giải phóng bộ nhớ
  void closeAdminActiveChat() {
    _adminMessagesSub?.cancel();
    _adminMessagesSub = null;
    _adminActiveCustomerId = null;
    _adminMessages = [];
    _isAdminLoading = false;
    notifyListeners();
  }

  /// Lắng nghe danh sách tất cả các phòng chat của khách (Cho màn hình tổng quan Admin)
  void listenAdminChatRooms() {
    _adminChatsSub?.cancel();
    try {
      _adminChatsSub = _firestoreService.streamAllChats().listen((rooms) {
        _adminChatRooms = rooms;
        notifyListeners();
      }, onError: (_) {});
    } catch (_) {}
  }

  // ==========================================
  // 4. GỬI TIN NHẮN & ĐÍNH KÈM NGỮ CẢNH (CONTEXTUAL ATTACHMENTS)
  // ==========================================

  /// Gửi tin nhắn mới (hỗ trợ đính kèm thẻ đơn hàng & thẻ sản phẩm)
  Future<bool> sendMessage({
    required String customerId,
    required String text,
    required String senderId,
    String? customerName,
    bool isFromAdmin = false,
    String? orderId,
    num? orderTotalPrice,
    String? productId,
    String? productName,
    String? productImageUrl,
  }) async {
    final cleanText = text.trim();
    final hasAttachment = (orderId != null && orderId.isNotEmpty) ||
        (productName != null && productName.isNotEmpty) ||
        (productId != null && productId.isNotEmpty);

    if (cleanText.isEmpty && !hasAttachment) return false;

    final message = MessageModel(
      id: '',
      senderId: senderId,
      text: cleanText,
      createdAt: DateTime.now(),
      orderId: orderId,
      orderTotalPrice: orderTotalPrice,
      productId: productId,
      productName: productName,
      productImageUrl: productImageUrl,
    );

    try {
      await _firestoreService.sendMessage(
        customerId: customerId,
        message: message,
        customerName: customerName,
        isFromAdmin: isFromAdmin,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // 5. ĐÁNH DẤU ĐÃ ĐỌC (READ STATUS)
  // ==========================================

  /// Đánh dấu Admin đã đọc tin nhắn của phòng chat (kèm Optimistic UI)
  Future<void> markChatAsReadByAdmin(String customerId) async {
    final roomIndex =
        _adminChatRooms.indexWhere((r) => r['customerId'] == customerId);
    if (roomIndex >= 0) {
      final updatedRoom = Map<String, dynamic>.from(_adminChatRooms[roomIndex]);
      updatedRoom['unreadByAdmin'] = 0;
      _adminChatRooms[roomIndex] = updatedRoom;
      notifyListeners();
    }

    try {
      await _firestoreService.markChatAsReadByAdmin(customerId);
    } catch (_) {}
  }

  /// Đánh dấu Khách hàng đã đọc tin nhắn của Admin (kèm Optimistic UI)
  Future<void> markChatAsReadByCustomer(String customerId) async {
    _unreadCustomerCount = 0;
    notifyListeners();
    try {
      await _firestoreService.markChatAsReadByCustomer(customerId);
    } catch (_) {}
  }

  // ==========================================
  // 6. QUẢN TRỊ PHIÊN ĐĂNG XUẤT (RESET SESSION - KHÓA BẪY 13)
  // ==========================================

  /// Đăng xuất: Hủy toàn bộ StreamSubscription và dọn sạch RAM
  void resetSession() {
    _customerMessagesSub?.cancel();
    _customerMessagesSub = null;
    _customerRoomSub?.cancel();
    _customerRoomSub = null;
    _adminMessagesSub?.cancel();
    _adminMessagesSub = null;
    _adminChatsSub?.cancel();
    _adminChatsSub = null;

    _customerMessages = [];
    _adminMessages = [];
    _adminChatRooms = [];
    _unreadCustomerCount = 0;
    _currentCustomerId = null;
    _adminActiveCustomerId = null;
    _isLoading = false;
    _isAdminLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _customerMessagesSub?.cancel();
    _customerRoomSub?.cancel();
    _adminMessagesSub?.cancel();
    _adminChatsSub?.cancel();
    super.dispose();
  }
}
