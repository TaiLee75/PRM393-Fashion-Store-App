import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý tin nhắn tư vấn trực tuyến thời gian thực
class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<MessageModel> _messages = [];
  List<Map<String, dynamic>> _adminChatRooms = [];
  bool _isLoading = false;

  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _adminChatsSub;

  ChatProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<MessageModel> get messages => List.unmodifiable(_messages);
  List<Map<String, dynamic>> get adminChatRooms =>
      List.unmodifiable(_adminChatRooms);
  bool get isLoading => _isLoading;

  /// Lắng nghe tin nhắn trong phòng chat của khách hàng
  void listenMessages(String customerId) {
    _messagesSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _messagesSub = _firestoreService.streamMessages(customerId).listen((msgs) {
      _messages = msgs;
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Lắng nghe danh sách tất cả các phòng chat của khách (Cho Admin demo)
  void listenAdminChatRooms() {
    _adminChatsSub?.cancel();
    _adminChatsSub = _firestoreService.streamAllChats().listen((rooms) {
      _adminChatRooms = rooms;
      notifyListeners();
    });
  }

  /// Gửi tin nhắn mới
  Future<bool> sendMessage({
    required String customerId,
    required String text,
    required String senderId,
    String? customerName,
  }) async {
    if (text.trim().isEmpty) return false;

    final message = MessageModel(
      id: '',
      senderId: senderId,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _firestoreService.sendMessage(
        customerId: customerId,
        message: message,
        customerName: customerName,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _adminChatsSub?.cancel();
    super.dispose();
  }
}
