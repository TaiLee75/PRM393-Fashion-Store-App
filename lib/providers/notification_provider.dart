import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý danh sách thông báo và số lượng chưa đọc
class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  StreamSubscription<List<NotificationModel>>? _sub;

  NotificationProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  /// Đếm số thông báo chưa đọc để hiển thị Badge đỏ
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Lắng nghe thông báo thời gian thực của người dùng
  void listenNotifications(String userId) {
    _sub?.cancel();
    _isLoading = true;
    notifyListeners();

    _sub = _firestoreService.streamUserNotifications(userId).listen((list) {
      _notifications = list;
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestoreService.markNotificationAsRead(notificationId);
      final index =
          _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
