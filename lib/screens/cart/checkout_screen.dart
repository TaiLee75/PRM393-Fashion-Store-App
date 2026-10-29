import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_validators.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart_item_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../main_nav_screen.dart';
import '../map/store_map_screen.dart';
import 'widgets/vietqr_dialog.dart';

/// Màn hình Thanh toán đơn hàng (Checkout) Đa kênh:
/// - Khóa Bẫy 1: Tính toán trên checkoutItems = widget.directBuyItems ?? cartProvider.selectedItems
/// - Nhận hàng 2 Tab: Giao tận nơi (DELIVERY) vs Nhận tại cửa hàng (PICKUP - miễn phí 100%)
/// - Khóa Bẫy 3: Kê khai 5 dòng tài chính minh bạch, chặn áp FREESHIP khi phí ship = 0đ
/// - Khóa Bẫy 6: Chỉ dọn món đã mua (removePurchasedItems), Mua ngay giữ nguyên giỏ
class CheckoutScreen extends StatefulWidget {
  final List<CartItemModel>? directBuyItems;

  const CheckoutScreen({super.key, this.directBuyItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _voucherController = TextEditingController();

  String _deliveryMethod = 'DELIVERY'; // 'DELIVERY' hoặc 'PICKUP'
  String _selectedBranch = AppConstants.storeBranches.first['name'] as String;
  String _paymentMethod = 'COD'; // 'COD' hoặc 'VIETQR'
  String _appliedVoucher = '';
  bool _saveAsDefaultAddress = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.userFullName;
    _phoneController.text = auth.userModel?.phone ?? '';
    _addressController.text = auth.effectiveDefaultAddress.isNotEmpty
        ? auth.effectiveDefaultAddress
        : (auth.userModel?.defaultAddress ?? '');

    // Nếu vào từ giỏ hàng đã có voucher trước đó
    if (widget.directBuyItems == null) {
      final cart = context.read<CartProvider>();
      if (cart.voucherCode.isNotEmpty) {
        _appliedVoucher = cart.voucherCode;
        _voucherController.text = cart.voucherCode;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  void _onDeliveryMethodChanged(String method) {
    if (_deliveryMethod == method) return;
    setState(() {
      _deliveryMethod = method;
      // Khóa Bẫy 3: Nếu chuyển sang PICKUP (phí ship = 0đ) mà đang áp mã FREESHIP thì tự động gỡ
      if (_deliveryMethod == 'PICKUP' && _appliedVoucher.toUpperCase() == 'FREESHIP') {
        _appliedVoucher = '';
        _voucherController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gỡ mã FREESHIP do Nhận tại cửa hàng được miễn phí vận chuyển 100%!'),
            backgroundColor: AppColors.black,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _applyVoucher(CartProvider cartProvider, List<CartItemModel> items) {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;

    final pricing = cartProvider.calculateOrderPricing(
      items: items,
      deliveryMethod: _deliveryMethod,
      voucherCode: code,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (pricing.effectiveVoucherCode.isNotEmpty) {
      setState(() {
        _appliedVoucher = pricing.effectiveVoucherCode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Áp dụng mã $_appliedVoucher thành công!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pricing.message ?? 'Mã voucher không hợp lệ hoặc chưa đủ điều kiện!'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _removeVoucher() {
    setState(() {
      _appliedVoucher = '';
      _voucherController.clear();
    });
  }

  Future<void> _handlePlaceOrder() async {
    if (_deliveryMethod == 'DELIVERY') {
      if (!_formKey.currentState!.validate()) return;
    } else {
      // Khi nhận tại cửa hàng, kiểm tra họ tên và SĐT người nhận
      if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập họ tên và số điện thoại người nhận hàng tại cửa hàng!'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    final cartProvider = context.read<CartProvider>();
    final authProvider = context.read<AuthProvider>();
    final orderProvider = context.read<OrderProvider>();

    // Khóa Bẫy 1: Nguồn sản phẩm đặt hàng
    final effectiveItems = widget.directBuyItems ?? cartProvider.selectedItems;
    if (effectiveItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có sản phẩm nào để đặt hàng!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Khóa Bẫy 9: Kiểm tra lại tồn kho tức thời trước khi chốt đơn
    final productProvider = context.read<ProductProvider>();
    if (productProvider.allProducts.isNotEmpty) {
      for (final item in effectiveItems) {
        final product = productProvider.allProducts.firstWhere(
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
          final stock = product.getStockForVariant(item.size, item.color);
          if (!product.isActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sản phẩm "${item.productName}" hiện đã ngừng kinh doanh!'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          if (stock < item.quantity) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sản phẩm "${item.productName}" (${item.size}, ${item.color}) hiện chỉ còn $stock sản phẩm trong kho! Vui lòng điều chỉnh lại.'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
        }
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // Tính toán tài chính độc lập cho đơn hàng
      final pricing = cartProvider.calculateOrderPricing(
        items: effectiveItems,
        deliveryMethod: _deliveryMethod,
        voucherCode: _appliedVoucher,
      );

      final shippingAddress = _deliveryMethod == 'DELIVERY'
          ? _addressController.text.trim()
          : 'Nhận tại cửa hàng: $_selectedBranch';

      final orderId = await orderProvider.createOrder(
        userId: authProvider.userId.isNotEmpty ? authProvider.userId : 'guest_user',
        userName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        shippingAddress: shippingAddress,
        deliveryMethod: _deliveryMethod,
        pickupBranchName: _deliveryMethod == 'PICKUP' ? _selectedBranch : '',
        note: _noteController.text.trim(),
        items: effectiveItems,
        subtotal: pricing.subtotal,
        shippingFee: pricing.shippingFee,
        productDiscount: pricing.productDiscount,
        shippingDiscount: pricing.shippingDiscount,
        voucherCode: pricing.effectiveVoucherCode,
        discountAmount: pricing.totalDiscount,
        totalPrice: pricing.finalTotalPrice,
        paymentMethod: _paymentMethod,
      );

      // Lưu làm địa chỉ mặc định nếu người dùng chọn
      if (_deliveryMethod == 'DELIVERY' && _saveAsDefaultAddress && authProvider.isAuthenticated) {
        await authProvider.updateProfile(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          defaultAddress: _addressController.text.trim(),
        );
      }

      if (!mounted) return;

      if (orderId != null) {
        // Khóa Bẫy 6: Nếu là mua từ giỏ hàng thì chỉ xóa các món đã mua
        if (widget.directBuyItems == null) {
          cartProvider.removePurchasedItems();
        }

        if (_paymentMethod == 'VIETQR') {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => VietQrPaymentDialog(
              orderId: orderId,
              totalPrice: pricing.finalTotalPrice,
              isFromCheckout: true,
              onFinished: () {
                MainNavScreen.switchToTab(context, 2);
              },
            ),
          );
        } else {
          // COD dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 26),
                  SizedBox(width: 8),
                  Text('Đặt hàng thành công!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mã đơn hàng: #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _deliveryMethod == 'DELIVERY'
                        ? 'Đơn hàng đang được chuẩn bị và sẽ giao sớm nhất tới địa chỉ của bạn.'
                        : 'Đơn hàng sẽ được chuẩn bị sẵn sàng tại chi nhánh $_selectedBranch để bạn đến nhận.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    MainNavScreen.switchToTab(context, 2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Xem đơn hàng của tôi'),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Đặt hàng không thành công. Vui lòng kiểm tra lại kết nối và thử lại!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã có lỗi xảy ra khi tạo đơn hàng: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Khóa Bẫy 1: Lấy đúng danh sách món thanh toán
    final effectiveItems = widget.directBuyItems ?? cartProvider.selectedItems;

    // Tính toán tài chính live
    final pricing = cartProvider.calculateOrderPricing(
      items: effectiveItems,
      deliveryMethod: _deliveryMethod,
      voucherCode: _appliedVoucher,
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'THANH TOÁN ĐƠN HÀNG',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BANNER CHẾ ĐỘ DEMO KHI LÀ ADMIN
            if (authProvider.isAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.ultraLightGrey,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chế độ Demo: Bạn đang đặt hàng với tư cách Quản trị viên (Admin) để kiểm thử luồng mua hàng.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. TÙY CHỌN HÌNH THỨC NHẬN HÀNG (2 TAB ĐA KÊNH)
            const Text(
              '1. HÌNH THỨC NHẬN HÀNG',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _onDeliveryMethodChanged('DELIVERY'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _deliveryMethod == 'DELIVERY' ? AppColors.black : AppColors.ultraLightGrey,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _deliveryMethod == 'DELIVERY' ? AppColors.black : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 22,
                            color: _deliveryMethod == 'DELIVERY' ? Colors.white : AppColors.black,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GIAO TẬN NƠI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _deliveryMethod == 'DELIVERY' ? Colors.white : AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pricing.subtotal >= AppConstants.freeShippingThreshold
                                ? 'Freeship 0đ'
                                : 'Phí ship 30.000đ',
                            style: TextStyle(
                              fontSize: 10,
                              color: _deliveryMethod == 'DELIVERY' ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _onDeliveryMethodChanged('PICKUP'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _deliveryMethod == 'PICKUP' ? AppColors.black : AppColors.ultraLightGrey,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _deliveryMethod == 'PICKUP' ? AppColors.black : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 22,
                            color: _deliveryMethod == 'PICKUP' ? Colors.white : AppColors.black,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'NHẬN TẠI CỬA HÀNG',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _deliveryMethod == 'PICKUP' ? Colors.white : AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Miễn phí 100%',
                            style: TextStyle(
                              fontSize: 10,
                              color: _deliveryMethod == 'PICKUP' ? Colors.white70 : AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // FORM THÔNG TIN CHI TIẾT
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _deliveryMethod == 'DELIVERY'
                          ? 'Họ tên người nhận *'
                          : 'Họ tên người đến lấy hàng *',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                    ),
                    validator: (v) => AppValidators.validateRequired(v, 'Họ tên'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại liên hệ *',
                      hintText: 'VD: 0901234567 (10 chữ số)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                    validator: AppValidators.validatePhone,
                  ),
                  const SizedBox(height: 12),

                  if (_deliveryMethod == 'DELIVERY') ...[
                    // Địa chỉ giao hàng tận nơi
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Địa chỉ nhận hàng chi tiết *',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                              alignLabelWithHint: true,
                            ),
                            validator: (v) => AppValidators.validateRequired(
                              v,
                              'Địa chỉ nhận hàng',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconButton.filled(
                            icon: const Icon(Icons.map_outlined),
                            tooltip: 'Chọn vị trí trên Bản đồ',
                            style: IconButton.styleFrom(backgroundColor: AppColors.black),
                            onPressed: () async {
                              final result = await Navigator.push<dynamic>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StoreMapScreen(isPickerMode: true),
                                ),
                              );
                              if (result != null) {
                                final selectedAddr =
                                    result is Map ? result['address']?.toString() : result.toString();
                                if (selectedAddr != null && selectedAddr.isNotEmpty) {
                                  setState(() {
                                    _addressController.text = selectedAddr;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    CheckboxListTile(
                      value: _saveAsDefaultAddress,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      dense: true,
                      title: const Text(
                        'Lưu thông tin này làm địa chỉ nhận hàng mặc định cho các đơn sau',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      onChanged: (val) {
                        setState(() => _saveAsDefaultAddress = val ?? false);
                      },
                    ),
                  ] else ...[
                    // Chọn chi nhánh nhận hàng
                    const Text(
                      'Chọn cửa hàng nhận hàng:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBranch,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.storefront, size: 20),
                      ),
                      items: AppConstants.storeBranches.map((branch) {
                        final name = branch['name'] as String;
                        final address = branch['address'] as String;
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(
                            '$name - $address',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBranch = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Ô nhập Ghi chú đơn hàng
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú cho đơn hàng (không bắt buộc)',
                      hintText: 'VD: Giao giờ hành chính, gọi trước khi đến...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),

            // 2. MÃ GIẢM GIÁ (VOUCHER) TRỰC TIẾP TẠI CHECKOUT
            const Text(
              '2. KHUYẾN MÃI & VOUCHER',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            if (_appliedVoucher.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã áp dụng: $_appliedVoucher (${AppFormatters.formatCurrency(pricing.totalDiscount)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _removeVoucher,
                      child: const Text(
                        'Gỡ mã',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập mã (SALE10 / FREESHIP)',
                        hintStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.confirmation_num_outlined, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _applyVoucher(cartProvider, effectiveItems),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
            const Divider(height: 32),

            // 3. PHƯƠNG THỨC THANH TOÁN
            const Text(
              '3. PHƯƠNG THỨC THANH TOÁN',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            // ignore: deprecated_member_use
            RadioListTile<String>(
              value: 'COD',
              // ignore: deprecated_member_use
              groupValue: _paymentMethod,
              title: const Text('Thanh toán khi nhận hàng (COD)'),
              subtitle: Text(
                _deliveryMethod == 'DELIVERY'
                    ? 'Thanh toán tiền mặt trực tiếp cho shipper khi nhận hàng'
                    : 'Thanh toán tiền mặt hoặc quẹt thẻ tại quầy chi nhánh',
              ),
              activeColor: AppColors.primary,
              // ignore: deprecated_member_use
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),
            // ignore: deprecated_member_use
            RadioListTile<String>(
              value: 'VIETQR',
              // ignore: deprecated_member_use
              groupValue: _paymentMethod,
              title: const Row(
                children: [
                  Text('Chuyển khoản VietQR'),
                  SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'NAPAS 24/7',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: const Text('Quét mã QR tự động điền STK & số tiền qua app Ngân hàng'),
              activeColor: AppColors.primary,
              // ignore: deprecated_member_use
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),
            const Divider(height: 32),

            // 4. TÓM TẮT ĐƠN HÀNG & 5 DÒNG KÊ KHAI TÀI CHÍNH
            const Text(
              '4. TÓM TẮT ĐƠN HÀNG',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            ...effectiveItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.productName} (${item.size}, ${item.color}) x${item.quantity}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        AppFormatters.formatCurrency(item.itemTotal),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),

            // Dòng 1: Tạm tính
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tạm tính tiền hàng:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text(AppFormatters.formatCurrency(pricing.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),

            // Dòng 2: Phí vận chuyển
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Phí vận chuyển:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text(
                  pricing.shippingFee == 0
                      ? 'MIỄN PHÍ (0đ)'
                      : AppFormatters.formatCurrency(pricing.shippingFee),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: pricing.shippingFee == 0 ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            // Dòng 3: Giảm giá tiền hàng
            if (pricing.productDiscount > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Giảm giá sản phẩm (${pricing.effectiveVoucherCode}):',
                      style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                  Text(
                    '-${AppFormatters.formatCurrency(pricing.productDiscount)}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],

            // Dòng 4: Giảm giá vận chuyển
            if (pricing.shippingDiscount > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Giảm phí ship (${pricing.effectiveVoucherCode}):',
                      style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                  Text(
                    '-${AppFormatters.formatCurrency(pricing.shippingDiscount)}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            // Dòng 5: Tổng thanh toán cuối cùng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng thanh toán:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  AppFormatters.formatCurrency(pricing.finalTotalPrice),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.priceHighlight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // NÚT XÁC NHẬN ĐẶT HÀNG
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (orderProvider.isLoading || _isSubmitting) ? null : _handlePlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: (orderProvider.isLoading || _isSubmitting)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'XÁC NHẬN ĐẶT HÀNG',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
