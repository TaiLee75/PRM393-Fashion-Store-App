import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';

/// Kết quả tính toán tài chính đơn hàng chuẩn Enterprise (Bảng kê chi tiết)
class OrderPricingResult {
  final num subtotal; // Tiền hàng thực tế
  final num shippingFee; // Phí giao hàng ban đầu
  final num productDiscount; // Chiết khấu sản phẩm (từ voucher tiền hàng)
  final num shippingDiscount; // Giảm giá vận chuyển (từ voucher FREESHIP)
  final num finalTotalPrice; // Tổng thanh toán = (subtotal - productDiscount) + (shippingFee - shippingDiscount)
  final String effectiveVoucherCode; // Mã voucher áp dụng hợp lệ
  final String? message; // Cảnh báo hoặc giải thích voucher

  const OrderPricingResult({
    required this.subtotal,
    required this.shippingFee,
    required this.productDiscount,
    required this.shippingDiscount,
    required this.finalTotalPrice,
    this.effectiveVoucherCode = '',
    this.message,
  });

  /// Tổng số tiền được giảm giá
  num get totalDiscount => productDiscount + shippingDiscount;
}

/// ViewModel quản lý giỏ hàng, chọn lọc thanh toán, gộp phân loại và đối soát tài chính (MVVM)
class CartProvider extends ChangeNotifier {
  final FirestoreService? firestoreService;
  final String? userId; // Tương thích ngược constructor

  String? _activeUserId;
  List<CartItemModel> _items = [];
  String _voucherCode = '';
  num _discountAmount = 0;
  bool _isLoading = false;
  int _syncCount = 0;
  StreamSubscription<List<CartItemModel>>? _cartSub;

  CartProvider({this.firestoreService, this.userId}) {
    if (userId != null && userId!.isNotEmpty) {
      loadUserCart(userId!);
    }
  }

  // Getters cơ bản
  List<CartItemModel> get items => List.unmodifiable(_items);
  String get voucherCode => _voucherCode;
  num get discountAmount => _discountAmount;
  bool get isLoading => _isLoading;
  bool get isSyncing => _syncCount > 0;
  String? get activeUserId => _activeUserId ?? userId;

  /// Danh sách các món được người dùng tích chọn để mua (Khóa Bẫy 1)
  List<CartItemModel> get selectedItems =>
      _items.where((item) => item.isSelected).toList();

  /// Đếm số món đang được tích chọn
  int get selectedQuantity =>
      selectedItems.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Tổng số lượng tất cả các mặt hàng có trong giỏ
  int get totalQuantity =>
      _items.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Đã chọn tất cả món trong giỏ hay chưa
  bool get isAllSelected =>
      _items.isNotEmpty && _items.every((item) => item.isSelected);

  /// Tổng tiền hàng tạm tính trước chiết khấu (Chỉ tính trên các món được tích chọn - Khóa Bẫy 1)
  num get subtotal =>
      selectedItems.fold<num>(0, (sum, item) => sum + item.itemTotal);

  /// Tổng tiền thanh toán cuối cùng sau khi trừ Voucher (Phục vụ tương thích ngược)
  num get totalPrice {
    final finalPrice = subtotal - _discountAmount;
    return finalPrice > 0 ? finalPrice : 0;
  }

  /// Nạp giỏ hàng động theo userId của phiên đăng nhập hiện tại (Khóa Bẫy 13)
  void loadUserCart(String newUserId) {
    if (newUserId.trim().isEmpty) {
      unloadCartOnLogout();
      return;
    }

    if (_activeUserId == newUserId && _cartSub != null) {
      // Đang lắng nghe đúng user này rồi thì giữ nguyên stream
      return;
    }

    _cartSub?.cancel();
    _activeUserId = newUserId;
    _isLoading = true;
    notifyListeners();

    if (firestoreService != null) {
      _cartSub = firestoreService!.streamCart(newUserId).listen((cloudItems) {
        if (_syncCount == 0) {
          _items = cloudItems;
          _recalculateVoucher();
          _isLoading = false;
          notifyListeners();
        }
      }, onError: (_) {
        _isLoading = false;
        notifyListeners();
      });
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Thêm món vào giỏ hàng (kẹp trần theo tồn kho nếu có)
  void addItem(CartItemModel newItem, [int? maxStock]) {
    final existingIndex =
        _items.indexWhere((item) => item.cartItemId == newItem.cartItemId);

    if (existingIndex >= 0) {
      final current = _items[existingIndex];
      int combinedQty = current.quantity + newItem.quantity;
      if (maxStock != null && maxStock > 0 && combinedQty > maxStock) {
        combinedQty = maxStock;
      }
      _items[existingIndex] = current.copyWith(
        quantity: combinedQty,
        isSelected: newItem.isSelected,
      );
    } else {
      int finalQty = newItem.quantity;
      if (maxStock != null && maxStock > 0 && finalQty > maxStock) {
        finalQty = maxStock;
      }
      _items.add(newItem.copyWith(quantity: finalQty, isSelected: newItem.isSelected));
    }

    _recalculateVoucher();
    _syncWithFirestore();
    notifyListeners();
  }

  /// Bật/Tắt checkbox chọn mua một món trong giỏ
  void toggleItemSelection(String cartItemId) {
    final index = _items.indexWhere((item) => item.cartItemId == cartItemId);
    if (index >= 0) {
      final current = _items[index];
      _items[index] = current.copyWith(isSelected: !current.isSelected);
      _recalculateVoucher();
      notifyListeners();
      _syncWithFirestore();
    }
  }

  /// Chọn tất cả hoặc bỏ chọn tất cả các món trong giỏ (loại trừ các món hết hàng nếu có)
  void toggleSelectAll(bool isSelected, [Set<String>? excludedItemIds]) {
    _items = _items.map((item) {
      if (isSelected && excludedItemIds != null && excludedItemIds.contains(item.cartItemId)) {
        return item.copyWith(isSelected: false);
      }
      return item.copyWith(isSelected: isSelected);
    }).toList();
    _recalculateVoucher();
    notifyListeners();
    _syncWithFirestore();
  }

  /// Cập nhật số lượng của một món trong giỏ (kẹp theo tồn kho nếu có)
  void updateQuantity(String cartItemId, int quantity, [int? maxStock]) {
    final index = _items.indexWhere((item) => item.cartItemId == cartItemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        int finalQty = quantity;
        if (maxStock != null && maxStock > 0 && finalQty > maxStock) {
          finalQty = maxStock;
        }
        _items[index] = _items[index].copyWith(quantity: finalQty);
      }
      _recalculateVoucher();
      _syncWithFirestore();
      notifyListeners();
    }
  }

  /// Đổi phân loại Size/Màu ngay tại Giỏ hàng & Hợp nhất số lượng nếu trùng SKU (Khóa Bẫy 2)
  void updateItemVariant({
    required String oldCartItemId,
    required String newSize,
    required String newColor,
    int? maxVariantStock,
  }) {
    final oldIndex = _items.indexWhere((i) => i.cartItemId == oldCartItemId);
    if (oldIndex < 0) return;

    final oldItem = _items[oldIndex];
    final newCartItemId = CartItemModel.buildCartItemId(
      oldItem.productId,
      newSize,
      newColor,
    );

    // Nếu không thay đổi gì
    if (newCartItemId == oldCartItemId) return;

    final existingIndex =
        _items.indexWhere((i) => i.cartItemId == newCartItemId);

    if (existingIndex >= 0) {
      // Đã có dòng phân loại này trong giỏ -> Cộng dồn số lượng và xóa dòng cũ (Khóa Bẫy 2)
      final existingItem = _items[existingIndex];
      int combinedQty = existingItem.quantity + oldItem.quantity;
      if (maxVariantStock != null &&
          maxVariantStock > 0 &&
          combinedQty > maxVariantStock) {
        combinedQty = maxVariantStock;
      }

      _items[existingIndex] = existingItem.copyWith(
        quantity: combinedQty,
        isSelected: true,
      );
      _items.removeAt(oldIndex);
    } else {
      // Chưa có -> Cập nhật trực tiếp dòng này với ID mới
      int finalQty = oldItem.quantity;
      if (maxVariantStock != null &&
          maxVariantStock > 0 &&
          finalQty > maxVariantStock) {
        finalQty = maxVariantStock;
      }

      _items[oldIndex] = oldItem.copyWith(
        cartItemId: newCartItemId,
        size: newSize,
        color: newColor,
        quantity: finalQty,
      );
    }

    _recalculateVoucher();
    _syncWithFirestore();
    notifyListeners();
  }

  /// Xóa một món ra khỏi giỏ
  void removeItem(String cartItemId) {
    _items.removeWhere((item) => item.cartItemId == cartItemId);
    _recalculateVoucher();
    _syncWithFirestore();
    notifyListeners();
  }


  /// Chỉ xóa các món đã tích chọn thanh toán sau khi đặt hàng thành công (Khóa Bẫy 6)
  void removePurchasedItems() {
    _items.removeWhere((item) => item.isSelected);
    _recalculateVoucher();
    _syncWithFirestore();
    notifyListeners();
  }

  /// Khi đăng xuất: Chỉ dọn sạch RAM trên máy, giữ nguyên 100% giỏ hàng trên Cloud (Khóa Bẫy 13)
  void unloadCartOnLogout() {
    _cartSub?.cancel();
    _cartSub = null;
    _activeUserId = null;
    _items.clear();
    _voucherCode = '';
    _discountAmount = 0;
    _syncCount = 0;
    notifyListeners();
  }

  /// Xóa sạch giỏ hàng thủ công
  void clearCart() {
    _items.clear();
    _voucherCode = '';
    _discountAmount = 0;
    _syncWithFirestore();
    notifyListeners();
  }

  /// Đối chiếu giỏ hàng với dữ liệu sản phẩm mới nhất từ Firestore (Khóa Bẫy 9)
  /// Tự động cập nhật giá mới, kẹp trần số lượng theo tồn kho, nếu hết hàng hoặc ngừng kinh doanh thì tự động bỏ chọn isSelected = false
  void validateAndAlignCart(List<ProductModel> liveProducts) {
    if (_items.isEmpty || liveProducts.isEmpty) return;

    bool hasChanges = false;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final product = liveProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => const ProductModel(
          id: '',
          name: '',
          categoryId: '',
          price: 0,
          description: '',
          imageUrls: [],
          sizes: [],
          colors: [],
        ),
      );

      if (product.id.isNotEmpty) {
        final variantStock =
            product.getStockForVariant(item.size, item.color);
        final isAvailable = product.isActive && variantStock > 0;
        final clampedQty = (variantStock > 0 && item.quantity > variantStock)
            ? variantStock
            : item.quantity;

        if (item.price != product.price ||
            item.quantity != clampedQty ||
            (!isAvailable && item.isSelected)) {
          _items[i] = item.copyWith(
            price: product.price,
            quantity: clampedQty,
            isSelected: isAvailable ? item.isSelected : false,
          );
          hasChanges = true;
        }
      } else {
        // Sản phẩm đã bị gỡ hoàn toàn khỏi hệ thống
        if (item.isSelected) {
          _items[i] = item.copyWith(isSelected: false);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      _recalculateVoucher();
      notifyListeners();
      _syncWithFirestore();
    }
  }

  /// Hàm tính toán tài chính đơn hàng độc lập (Khóa Bẫy 1 & Bẫy 3 - Chống bẫy FREESHIP -0đ)
  OrderPricingResult calculateOrderPricing({
    required List<CartItemModel> items,
    required String deliveryMethod, // 'DELIVERY' hoặc 'PICKUP'
    String? voucherCode,
  }) {
    final num itemsSubtotal =
        items.fold<num>(0, (sum, item) => sum + item.itemTotal);

    // 1. Phí vận chuyển
    num fee = 0;
    if (deliveryMethod == 'PICKUP') {
      fee = 0;
    } else {
      fee = (itemsSubtotal >= AppConstants.freeShippingThreshold)
          ? 0
          : AppConstants.standardShippingFee;
    }

    num prodDiscount = 0;
    num shipDiscount = 0;
    String effectiveCode = '';
    String? msg;

    if (voucherCode != null && voucherCode.trim().isNotEmpty) {
      final code = voucherCode.trim().toUpperCase();
      final rule = AppConstants.findVoucher(code);

      if (rule != null) {
        // Kiểm tra điều kiện đơn tối thiểu
        if (itemsSubtotal < rule.minOrder) {
          msg =
              'Đơn hàng chưa đạt mức tối thiểu ${rule.minOrder}đ để áp dụng voucher $code.';
        } else if (rule.isShippingVoucher) {
          // Khóa Bẫy 3: Voucher FREESHIP
          if (fee == 0) {
            msg =
                'Đơn hàng đã được Miễn phí vận chuyển (0đ)! Hãy dùng mã giảm giá tiền hàng như SALE10 để được ưu đãi thêm.';
          } else {
            effectiveCode = code;
            shipDiscount = rule.value > fee ? fee : rule.value;
          }
        } else {
          // Voucher giảm giá sản phẩm
          effectiveCode = code;
          if (rule.type == 'percent') {
            num discount = itemsSubtotal * rule.value;
            if (rule.maxDiscount != null && discount > rule.maxDiscount!) {
              discount = rule.maxDiscount!;
            }
            prodDiscount = discount.round();
          } else if (rule.type == 'fixed') {
            prodDiscount = rule.value;
          }
        }
      } else {
        msg = 'Mã voucher "$code" không tồn tại hoặc đã hết hạn.';
      }
    }

    final netProduct =
        itemsSubtotal > prodDiscount ? itemsSubtotal - prodDiscount : 0;
    final netShipping = fee > shipDiscount ? fee - shipDiscount : 0;
    final finalTotal = netProduct + netShipping;

    return OrderPricingResult(
      subtotal: itemsSubtotal,
      shippingFee: fee,
      productDiscount: prodDiscount,
      shippingDiscount: shipDiscount,
      finalTotalPrice: finalTotal,
      effectiveVoucherCode: effectiveCode,
      message: msg,
    );
  }

  /// Áp dụng mã giảm giá Voucher
  bool applyVoucher(String code) {
    final pricing = calculateOrderPricing(
      items: selectedItems.isNotEmpty ? selectedItems : _items,
      deliveryMethod: 'DELIVERY',
      voucherCode: code,
    );

    if (pricing.effectiveVoucherCode.isNotEmpty) {
      _voucherCode = pricing.effectiveVoucherCode;
      _discountAmount = pricing.totalDiscount;
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

  /// Tính lại số tiền giảm khi số lượng hoặc danh sách món thay đổi
  void _recalculateVoucher() {
    if (_voucherCode.isNotEmpty) {
      final pricing = calculateOrderPricing(
        items: selectedItems.isNotEmpty ? selectedItems : _items,
        deliveryMethod: 'DELIVERY',
        voucherCode: _voucherCode,
      );
      _voucherCode = pricing.effectiveVoucherCode;
      _discountAmount = pricing.totalDiscount;
    } else {
      _discountAmount = 0;
    }
  }

  /// Đồng bộ giỏ hàng với Firestore
  Future<void> _syncWithFirestore() async {
    final service = firestoreService;
    final uid = _activeUserId ?? userId;
    if (service != null && uid != null && uid.isNotEmpty) {
      _syncCount++;
      try {
        await service.saveCart(uid, _items);
      } catch (_) {
      } finally {
        if (_syncCount > 0) _syncCount--;
      }
    }
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
  }
}

