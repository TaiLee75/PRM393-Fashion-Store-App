import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý toàn bộ vòng đời đơn hàng chuẩn Enterprise (MVVM):
/// - Quản lý 6 trạng thái vận hành: Pending -> Confirmed/Delivering -> Delivered -> Cancelled / ReturnRequested / Returned.
/// - Đồng bộ quy trình đối soát thanh toán VietQR Napas247 & Tiền mặt COD (Khóa Bẫy 20).
/// - Hủy đơn & Đổi trả hoàn tiền chuẩn ACID với tự động hoàn kho SKU (Khóa Bẫy 5, 20, 21).
/// - Quản lý phiên đăng nhập an toàn, dọn sạch dữ liệu RAM khi đăng xuất (Khóa Bẫy 13).
/// - Cập nhật trạng thái cục bộ tức thì (Optimistic UI) cho trải nghiệm mượt mà không độ trễ.
class OrderProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<OrderModel> _userOrders = [];
  List<OrderModel> _allOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _activeUserId;

  StreamSubscription<List<OrderModel>>? _userOrdersSub;
  StreamSubscription<List<OrderModel>>? _allOrdersSub;

  OrderProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  // Getters cơ bản
  List<OrderModel> get userOrders => List.unmodifiable(_userOrders);
  List<OrderModel> get allOrders => List.unmodifiable(_allOrders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get activeUserId => _activeUserId;

  // ==========================================
  // 1. TRA CỨU & BỘ LỌC ĐƠN HÀNG (GETTERS & HELPERS)
  // ==========================================

  /// Tìm đơn hàng theo mã orderId (không ném ngoại lệ khi không tìm thấy)
  OrderModel? findById(String orderId) {
    for (final o in _userOrders) {
      if (o.orderId == orderId) return o;
    }
    for (final o in _allOrders) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  /// Lọc danh sách đơn hàng của khách hiện tại theo trạng thái
  List<OrderModel> userOrdersByStatus(String status) {
    if (status.isEmpty || status.toUpperCase() == 'ALL') {
      return userOrders;
    }
    return _userOrders.where((o) => o.status == status).toList();
  }

  /// Đếm số đơn của khách theo trạng thái (Phục vụ hiển thị Badge số lượng)
  int countUserOrdersByStatus(String status) {
    if (status.isEmpty || status.toUpperCase() == 'ALL') {
      return _userOrders.length;
    }
    return _userOrders.where((o) => o.status == status).length;
  }

  /// Lọc toàn bộ đơn hàng (Admin) theo trạng thái
  List<OrderModel> allOrdersByStatus(String status) {
    if (status.isEmpty || status.toUpperCase() == 'ALL') {
      return allOrders;
    }
    return _allOrders.where((o) => o.status == status).toList();
  }

  /// Đếm toàn bộ đơn hàng (Admin) theo trạng thái
  int countAllOrdersByStatus(String status) {
    if (status.isEmpty || status.toUpperCase() == 'ALL') {
      return _allOrders.length;
    }
    return _allOrders.where((o) => o.status == status).length;
  }

  /// Đơn hàng đang chờ Admin duyệt thanh toán VietQR
  List<OrderModel> get pendingPaymentOrders =>
      _allOrders.where((o) => o.isPaymentSubmitted).toList();

  /// Đơn hàng đang chờ Admin xử lý yêu cầu Đổi/Trả hàng
  List<OrderModel> get returnRequestedOrders =>
      _allOrders.where((o) => o.isReturnRequested).toList();

  // ==========================================
  // 2. MOCK DỮ LIỆU PHỤC VỤ KIỂM THỬ (TEST COMPATIBILITY)
  // ==========================================

  void setMockUserOrders(List<OrderModel> orders) {
    _userOrders = List.from(orders);
    notifyListeners();
  }

  void setMockAllOrders(List<OrderModel> orders) {
    _allOrders = List.from(orders);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==========================================
  // 3. QUẢN LÝ STREAM & PHIÊN ĐĂNG NHẬP (STREAMS & SESSION RESET)
  // ==========================================

  /// Lắng nghe đơn hàng của khách hàng thời gian thực
  void listenUserOrders(String userId) {
    if (userId.trim().isEmpty) {
      resetSession();
      return;
    }

    if (_activeUserId == userId && _userOrdersSub != null) {
      return;
    }

    _userOrdersSub?.cancel();
    _activeUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _userOrdersSub =
          _firestoreService.streamUserOrders(userId).listen((orders) {
        _userOrders = orders;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      }, onError: (err) {
        _errorMessage = err.toString();
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lắng nghe toàn bộ đơn hàng thời gian thực (Dành cho Admin)
  void listenAllOrders() {
    _allOrdersSub?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allOrdersSub = _firestoreService.streamAllOrders().listen((orders) {
        _allOrders = orders;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      }, onError: (err) {
        _errorMessage = err.toString();
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lắng nghe thay đổi của 1 đơn hàng duy nhất (Phục vụ auto-dismiss popup VietQR)
  Stream<OrderModel?> streamSingleOrder(String orderId) {
    return _firestoreService.streamOrder(orderId);
  }

  /// Tra cứu đơn hàng trực tiếp bằng ID và đồng bộ vào bộ nhớ
  Future<OrderModel?> fetchOrderById(String orderId) async {
    try {
      final order = await _firestoreService.getOrderById(orderId);
      if (order != null) {
        _updateLocalOrder(orderId, (_) => order);
      }
      return order;
    } catch (e) {
      _errorMessage = 'Lỗi tra cứu đơn hàng: $e';
      notifyListeners();
      return null;
    }
  }

  /// Đăng xuất: Dọn sạch RAM và hủy toàn bộ subscription (Khóa Bẫy 13)
  void resetSession() {
    _userOrdersSub?.cancel();
    _userOrdersSub = null;
    _allOrdersSub?.cancel();
    _allOrdersSub = null;
    _activeUserId = null;
    _userOrders = [];
    _allOrders = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ==========================================
  // 4. TIẾN HÀNH ĐẶT HÀNG MỚI (CREATE ORDER)
  // ==========================================

  /// Tạo đơn hàng chuẩn ACID (Khóa Bẫy 6, 9, 21):
  /// Tự động trừ kho chi tiết từng SKU, ghi nhận tài chính và gửi thông báo.
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
    String deliveryMethod = OrderModel.deliveryMethodShipping,
    String pickupBranchName = '',
    String note = '',
    num shippingFee = 0,
    num productDiscount = 0,
    num shippingDiscount = 0,
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
        productDiscount: productDiscount > 0
            ? productDiscount
            : (voucherCode != 'FREESHIP' ? discountAmount : 0),
        shippingDiscount: shippingDiscount > 0
            ? shippingDiscount
            : (voucherCode == 'FREESHIP' ? discountAmount : 0),
        shippingFee: shippingFee,
        totalPrice: totalPrice,
        paymentMethod: paymentMethod,
        paymentStatus: OrderModel.paymentUnpaid,
        deliveryMethod: deliveryMethod,
        pickupBranchName: pickupBranchName,
        note: note,
        status: OrderModel.statusPending,
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

  // ==========================================
  // 5. QUẢN LÝ VÒNG ĐỜI & TRẠNG THÁI ĐƠN HÀNG (STATE MACHINE)
  // ==========================================

  /// Cập nhật trạng thái đơn hàng (Khóa Bẫy 20: Tự động Paid khi giao thành công Delivered)
  Future<bool> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? userId,
  }) async {
    try {
      await _firestoreService.updateOrderStatus(
        orderId: orderId,
        status: newStatus,
        userId: userId,
      );

      _updateLocalOrder(orderId, (o) => o.copyWith(
        status: newStatus,
        paymentStatus: newStatus == OrderModel.statusDelivered
            ? OrderModel.paymentPaid
            : o.paymentStatus,
        deliveringAt: newStatus == OrderModel.statusDelivering
            ? DateTime.now()
            : o.deliveringAt,
        deliveredAt: newStatus == OrderModel.statusDelivered
            ? DateTime.now()
            : o.deliveredAt,
      ));

      return true;
    } catch (e) {
      _errorMessage = 'Cập nhật trạng thái đơn hàng thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hủy đơn hàng trong Transaction ACID (Khóa Bẫy 5, 20, 21):
  /// Hoàn lại tồn kho SKU, trừ soldCount, và tự động đổi paymentStatus sang Refunded nếu đã thanh toán.
  Future<bool> cancelOrder(
    String orderId, {
    String? cancelReason,
    String cancelledBy = 'customer',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.cancelOrder(
        orderId,
        cancelReason: cancelReason,
        cancelledBy: cancelledBy,
      );

      _updateLocalOrder(orderId, (o) {
        final newPayment = (o.paymentStatus == OrderModel.paymentPaid ||
                o.paymentStatus == OrderModel.paymentSubmitted)
            ? OrderModel.paymentRefunded
            : OrderModel.paymentUnpaid;

        return o.copyWith(
          status: OrderModel.statusCancelled,
          paymentStatus: newPayment,
          cancelReason: cancelReason ?? 'Khách hàng yêu cầu hủy đơn',
          cancelledBy: cancelledBy,
          cancelledAt: DateTime.now(),
        );
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Hủy đơn hàng thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Chỉnh sửa thông tin giao hàng khi đơn còn ở trạng thái Pending
  Future<bool> updateShippingInfo({
    required String orderId,
    required String newAddress,
    required String phone,
    required String recipientName,
  }) async {
    try {
      await _firestoreService.updateOrderShippingAddress(
        orderId: orderId,
        newAddress: newAddress,
        phone: phone,
        recipientName: recipientName,
      );

      _updateLocalOrder(orderId, (o) => o.copyWith(
        shippingAddress: newAddress,
        phone: phone,
        userName: recipientName,
      ));

      return true;
    } catch (e) {
      _errorMessage = 'Cập nhật địa chỉ nhận hàng thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // 6. QUY TRÌNH ĐỔI / TRẢ HÀNG & HOÀN TIỀN (RETURN & REFUND)
  // ==========================================

  /// Khách hàng gửi yêu cầu Đổi/Trả hàng (Chỉ khi đơn đã Delivered)
  Future<bool> requestReturn(String orderId, {required String reason}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.requestReturnOrder(
        orderId,
        returnReason: reason,
      );

      _updateLocalOrder(orderId, (o) => o.copyWith(
        status: OrderModel.statusReturnRequested,
        returnReason: reason,
      ));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gửi yêu cầu đổi trả thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin duyệt chấp thuận Đổi/Trả hàng: Hoàn kho SKU và hoàn tiền Refunded
  Future<bool> approveReturn(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.approveReturnOrder(orderId);

      _updateLocalOrder(orderId, (o) => o.copyWith(
        status: OrderModel.statusReturned,
        paymentStatus: OrderModel.paymentRefunded,
        returnedAt: DateTime.now(),
      ));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Duyệt đổi trả đơn hàng thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin từ chối yêu cầu Đổi/Trả hàng: Khôi phục trạng thái Delivered
  Future<bool> rejectReturn(String orderId, {String? reason}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.rejectReturnOrder(orderId, reason: reason);

      _updateLocalOrder(orderId, (o) => o.copyWith(
        status: OrderModel.statusDelivered,
      ));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Từ chối yêu cầu đổi trả thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // 7. ĐỐI SOÁT THANH TOÁN VIETQR NAPAS247
  // ==========================================

  /// Khách hàng xác nhận "Tôi đã chuyển khoản"
  Future<bool> confirmPaymentSubmitted(
    String orderId, {
    String? transactionRef,
  }) async {
    try {
      await _firestoreService.confirmPaymentSubmitted(
        orderId,
        transactionRef: transactionRef,
      );

      _updateLocalOrder(orderId, (o) => o.copyWith(
        paymentStatus: OrderModel.paymentSubmitted,
        transactionRef: transactionRef ?? o.transactionRef,
      ));

      return true;
    } catch (e) {
      _errorMessage = 'Xác nhận chuyển khoản thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  /// Admin đối soát tài khoản và xác nhận thanh toán thành công (Paid)
  Future<bool> confirmPaymentPaid(String orderId) async {
    try {
      await _firestoreService.confirmPaymentPaid(orderId);

      _updateLocalOrder(orderId, (o) => o.copyWith(
        paymentStatus: OrderModel.paymentPaid,
      ));

      return true;
    } catch (e) {
      _errorMessage = 'Xác nhận thanh toán thành công thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  /// Admin từ chối giao dịch chuyển khoản do sai cú pháp hoặc chưa nhận được tiền
  Future<bool> rejectPaymentSubmitted(String orderId, {String? reason}) async {
    try {
      await _firestoreService.rejectPaymentSubmitted(orderId, reason: reason);

      _updateLocalOrder(orderId, (o) => o.copyWith(
        paymentStatus: OrderModel.paymentUnpaid,
      ));

      return true;
    } catch (e) {
      _errorMessage = 'Từ chối giao dịch chuyển khoản thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // 8. TIỆN ÍCH NỘI BỘ: CẬP NHẬT TRẠNG THÁI CỤC BỘ (OPTIMISTIC UI)
  // ==========================================

  void _updateLocalOrder(String orderId, OrderModel Function(OrderModel) updateFn) {
    bool changed = false;

    final uIndex = _userOrders.indexWhere((o) => o.orderId == orderId);
    if (uIndex >= 0) {
      _userOrders[uIndex] = updateFn(_userOrders[uIndex]);
      changed = true;
    }

    final aIndex = _allOrders.indexWhere((o) => o.orderId == orderId);
    if (aIndex >= 0) {
      _allOrders[aIndex] = updateFn(_allOrders[aIndex]);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userOrdersSub?.cancel();
    _allOrdersSub?.cancel();
    super.dispose();
  }
}
