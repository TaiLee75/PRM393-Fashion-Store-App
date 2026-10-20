import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/cart_item_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý giỏ hàng, áp mã giảm giá và tính toán đơn giá (MVVM)
class CartProvider extends ChangeNotifier {
  final FirestoreService? firestoreService;
  final String? userId;

  List<CartItemModel> _items = [];
  String _voucherCode = '';
  num _discountAmount = 0;
  bool _isLoading = false;

  CartProvider({this.firestoreService, this.userId});

  // Getters
  List<CartItemModel> get items => List.unmodifiable(_items);
  String get voucherCode => _voucherCode;
  num get discountAmount => _discountAmount;
  bool get isLoading => _isLoading;

  /// Tổng số lượng mặt hàng trong giỏ
  int get totalQuantity =>
      _items.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Tổng tiền hàng tạm tính trước chiết khấu
  num get subtotal =>
      _items.fold<num>(0, (sum, item) => sum + item.itemTotal);

  /// Tổng tiền thanh toán cuối cùng sau khi trừ Voucher
  num get totalPrice {
    final finalPrice = subtotal - _discountAmount;
    return finalPrice > 0 ? finalPrice : 0;
  }

  /// Khởi tạo và nạp giỏ hàng từ Firestore (nếu có userId)
  void loadUserCart(String userId) {
    if (firestoreService == null) return;
    _isLoading = true;
    notifyListeners();

    firestoreService!.streamCart(userId).listen((cartItems) {
      _items = cartItems;
      _recalculateVoucher();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Thêm món vào giỏ hàng
  void addItem(CartItemModel newItem) {
    final existingIndex =
        _items.indexWhere((item) => item.cartItemId == newItem.cartItemId);

    if (existingIndex >= 0) {
      // Đã có item cùng productId, size, color -> tăng số lượng
      final current = _items[existingIndex];
      _items[existingIndex] = current.copyWith(
        quantity: current.quantity + newItem.quantity,
      );
    } else {
      _items.add(newItem);
    }

    _recalculateVoucher();
    _syncWithFirestore();
    notifyListeners();
  }

  /// Cập nhật số lượng của một món trong giỏ
  void updateQuantity(String cartItemId, int quantity) {
    final index = _items.indexWhere((item) => item.cartItemId == cartItemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
      _recalculateVoucher();
      _syncWithFirestore();
      notifyListeners();
    }
  }

  /// Xóa một món ra khỏi giỏ
  void removeItem(String cartItemId) {
    _items.removeWhere((item) => item.cartItemId == cartItemId);
    _recalculateVoucher();
    _syncWithFirestore();
    notifyListeners();
  }

  /// Áp dụng mã giảm giá Voucher (VD: "SALE10", "FREESHIP")
  bool applyVoucher(String code) {
    final cleanCode = code.trim().toUpperCase();
    final voucherData = AppConstants.vouchers[cleanCode];

    if (voucherData != null) {
      _voucherCode = cleanCode;
      final type = voucherData['type'];
      final value = voucherData['value'];

      if (type == 'percent') {
        _discountAmount = (subtotal * (value as num)).round();
      } else if (type == 'fixed') {
        _discountAmount = value as num;
      }
      notifyListeners();
      return true;
    } else {
      _voucherCode = '';
      _discountAmount = 0;
      notifyListeners();
      return false;
    }
  }

  /// Hủy áp dụng mã giảm giá
  void removeVoucher() {
    _voucherCode = '';
    _discountAmount = 0;
    notifyListeners();
  }

  /// Xóa sạch giỏ hàng (sau khi đặt hàng thành công hoặc đăng xuất)
  void clearCart() {
    _items.clear();
    _voucherCode = '';
    _discountAmount = 0;
    _syncWithFirestore();
    notifyListeners();
  }

  /// Tính lại số tiền giảm khi số lượng hoặc danh sách món thay đổi
  void _recalculateVoucher() {
    if (_voucherCode.isNotEmpty) {
      final voucherData = AppConstants.vouchers[_voucherCode];
      if (voucherData != null) {
        final type = voucherData['type'];
        final value = voucherData['value'];
        if (type == 'percent') {
          _discountAmount = (subtotal * (value as num)).round();
        } else if (type == 'fixed') {
          _discountAmount = value as num;
        }
      } else {
        _discountAmount = 0;
      }
    } else {
      _discountAmount = 0;
    }
  }

  /// Đồng bộ với Firestore nếu có userId và firestoreService
  Future<void> _syncWithFirestore() async {
    final service = firestoreService;
    final uid = userId;
    if (service != null && uid != null && uid.isNotEmpty) {
      try {
        await service.saveCart(uid, _items);
      } catch (_) {
        // Tránh gián đoạn giao diện khi offline
      }
    }
  }
}
