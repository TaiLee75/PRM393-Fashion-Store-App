import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý đặt hàng, danh sách đơn hàng và trạng thái duyệt đơn
class OrderProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<OrderModel> _userOrders = [];
  List<OrderModel> _allOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<OrderModel>>? _userOrdersSub;
  StreamSubscription<List<OrderModel>>? _allOrdersSub;

  OrderProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<OrderModel> get userOrders => List.unmodifiable(_userOrders);
  List<OrderModel> get allOrders => List.unmodifiable(_allOrders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Lắng nghe đơn hàng của khách hàng hiện tại
  void listenUserOrders(String userId) {
    _userOrdersSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _userOrdersSub = _firestoreService.streamUserOrders(userId).listen((orders) {
      _userOrders = orders;
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Lắng nghe toàn bộ đơn hàng (Dành cho Admin/Shop quản lý)
  void listenAllOrders() {
    _allOrdersSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _allOrdersSub = _firestoreService.streamAllOrders().listen((orders) {
      _allOrders = orders;
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Tiến hành đặt hàng mới
  Future<String?> createOrder({
    required String userId,
    required String userName,
    required String phone,
    required String shippingAddress,
    required List<CartItemModel> items,
    required num subtotal,
    required String voucherCode,
    required num discountAmount,
    required num totalPrice,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = OrderModel(
        orderId: '',
        userId: userId,
        userName: userName,
        phone: phone,
        shippingAddress: shippingAddress,
        items: items,
        subtotal: subtotal,
        voucherCode: voucherCode,
        discountAmount: discountAmount,
        totalPrice: totalPrice,
        paymentMethod: paymentMethod,
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      final orderId = await _firestoreService.createOrder(order);
      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      _errorMessage = 'Đặt hàng thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Đổi trạng thái đơn hàng (Dành cho Admin duyệt đơn khi demo)
  Future<bool> updateOrderStatus({
    required String orderId,
    required String newStatus,
    required String userId,
  }) async {
    try {
      await _firestoreService.updateOrderStatus(
        orderId: orderId,
        status: newStatus,
        userId: userId,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Cập nhật trạng thái đơn hàng thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _userOrdersSub?.cancel();
    _allOrdersSub?.cancel();
    super.dispose();
  }
}
