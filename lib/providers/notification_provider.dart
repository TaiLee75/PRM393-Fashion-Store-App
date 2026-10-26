import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý danh sách thông báo, phân loại và đếm số lượng chưa đọc (MVVM):
/// - Quản lý thông báo thời gian thực theo userId.
/// - Đánh dấu đã đọc từng thông báo hoặc tất cả (markAllAsRead) với Optimistic UI.
/// - Phân loại thông báo: Đơn hàng (orderNotifications) & Ưu đãi khuyến mãi (promoNotifications).
/// - Quản lý phiên đăng xuất an toàn (Khóa Bẫy 13).
class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _activeUserId;
  StreamSubscription<List<NotificationModel>>? _sub;

  NotificationProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  // Getters cơ bản
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get activeUserId => _activeUserId;

  /// Đếm số thông báo chưa đọc để hiển thị Badge đỏ
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Lọc các thông báo biến động đơn hàng
  List<NotificationModel> get orderNotifications => _notifications
      .where((n) => n.type == NotificationModel.typeOrderUpdate)
      .toList();

  /// Lọc các thông báo khuyến mãi, voucher
  List<NotificationModel> get promoNotifications => _notifications
      .where((n) => n.type == NotificationModel.typePromotion)
      .toList();

  /// Tra cứu thông báo theo mã ID
  NotificationModel? findById(String id) {
    for (final n in _notifications) {
      if (n.id == id) return n;
    }
    return null;
  }

  // ==========================================
  // 1. MOCK DỮ LIỆU PHỤC VỤ TEST (TEST COMPATIBILITY)
  // ==========================================

  void setMockNotifications(List<NotificationModel> list) {
    _notifications = List.from(list);
    notifyListeners();
  }

  // ==========================================
  // 2. LẮNG NGHE THÔNG BÁO THỜI GIAN THỰC (STREAMS)
  // ==========================================

  /// Lắng nghe thông báo thời gian thực của người dùng
  void listenNotifications(String userId) {
    if (userId.trim().isEmpty) {
      resetSession();
      return;
    }

    if (_activeUserId == userId && _sub != null) {
      return;
    }

    _sub?.cancel();
    _activeUserId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      _sub = _firestoreService.streamUserNotifications(userId).listen((list) {
        _notifications = list;
        _isLoading = false;
        notifyListeners();
      }, onError: (_) {
        _isLoading = false;
        notifyListeners();
      });
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // 3. ĐÁNH DẤU ĐÃ ĐỌC (OPTIMISTIC READ ACTIONS)
  // ==========================================

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }

    try {
      await _firestoreService.markNotificationAsRead(notificationId);
    } catch (_) {}
  }

  /// Đánh dấu toàn bộ thông báo của người dùng là đã đọc
  Future<void> markAllAsRead() async {
    final unreadList = _notifications.where((n) => !n.isRead).toList();
    if (unreadList.isEmpty) return;

    // Cập nhật Optimistic trên RAM tức thì
    _notifications = _notifications
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
    notifyListeners();

    // Đồng bộ Firestore
    for (final item in unreadList) {
      try {
        await _firestoreService.markNotificationAsRead(item.id);
      } catch (_) {}
    }
  }

  // ==========================================
  // 4. QUẢN TRỊ PHIÊN ĐĂNG XUẤT (RESET SESSION - KHÓA BẪY 13)
  // ==========================================

  /// Đăng xuất: Hủy stream và dọn sạch RAM
  void resetSession() {
    _sub?.cancel();
    _sub = null;
    _activeUserId = null;
    _notifications = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
