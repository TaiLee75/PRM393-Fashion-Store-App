// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/cart_item_model.dart';
import '../map/store_map_screen.dart';
import '../main_nav_screen.dart';
import 'widgets/vietqr_dialog.dart';

/// Màn hình Thanh toán & Xác nhận đơn hàng (COD / VietQR)
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
  String _paymentMethod = 'COD'; // 'COD' hoặc 'VIETQR'
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handlePlaceOrder() async {
    final cartProvider = context.read<CartProvider>();
    final effectiveItems = widget.directBuyItems ?? cartProvider.items;
    if (effectiveItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Giỏ hàng của bạn đang trống!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    final orderProvider = context.read<OrderProvider>();

    final subtotal = widget.directBuyItems != null
        ? widget.directBuyItems!.fold<num>(0, (sum, i) => sum + i.itemTotal)
        : cartProvider.subtotal;
    final totalPaid = widget.directBuyItems != null
        ? subtotal
        : cartProvider.totalPrice;
    final voucher = widget.directBuyItems != null ? '' : cartProvider.voucherCode;
    final discount = widget.directBuyItems != null ? 0 : cartProvider.discountAmount;

    final orderId = await orderProvider.createOrder(
      userId: authProvider.userId.isNotEmpty ? authProvider.userId : 'guest_user',
      userName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      shippingAddress: _addressController.text.trim(),
      items: effectiveItems,
      subtotal: subtotal,
      voucherCode: voucher,
      discountAmount: discount,
      totalPrice: totalPaid,
      paymentMethod: _paymentMethod,
    );

    // Nếu người dùng chọn lưu làm địa chỉ mặc định
    if (_saveAsDefaultAddress && authProvider.isAuthenticated) {
      await authProvider.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        defaultAddress: _addressController.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (orderId != null) {
      if (widget.directBuyItems == null) {
        cartProvider.clearCart();
      }

      if (_paymentMethod == 'VIETQR') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => VietQrPaymentDialog(
            orderId: orderId,
            totalPrice: totalPaid,
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Phương thức: Thanh toán khi nhận hàng (COD)'),
                const SizedBox(height: 6),
                const Text(
                  'Cảm ơn bạn đã mua sắm! Đơn hàng sẽ được nhân viên chuẩn bị và giao sớm nhất.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();

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
            if (context.watch<AuthProvider>().isAdmin)
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

            // 1. THÔNG TIN GIAO HÀNG
            const Text(
              '1. ĐỊA CHỈ NHẬN HÀNG',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            // BANNER BÁO ĐÃ TỰ ĐỘNG ĐIỀN TỪ PROFILE
            if (context.watch<AuthProvider>().userModel?.defaultAddress.isNotEmpty == true)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Đã tự động điền Họ tên, SĐT & Địa chỉ từ Hồ sơ cá nhân của bạn.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final auth = context.read<AuthProvider>();
                        setState(() {
                          _nameController.text = auth.userFullName;
                          _phoneController.text = auth.userModel?.phone ?? '';
                          _addressController.text = auth.userModel?.defaultAddress ?? '';
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Điền lại',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ tên người nhận *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                    validator: (v) =>
                        AppValidators.validateRequired(v, 'Họ tên người nhận'),
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
                            final selectedAddr = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StoreMapScreen(isPickerMode: true),
                              ),
                            );
                            if (selectedAddr != null && selectedAddr.isNotEmpty) {
                              setState(() {
                                _addressController.text = selectedAddr;
                              });
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _saveAsDefaultAddress = val ?? false);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 32),

            // 2. PHƯƠNG THỨC THANH TOÁN
            const Text(
              '2. PHƯƠNG THỨC THANH TOÁN',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            RadioListTile<String>(
              value: 'COD',
              groupValue: _paymentMethod,
              title: const Text('Thanh toán khi nhận hàng (COD)'),
              subtitle: const Text('Nhận hàng và thanh toán tiền mặt trực tiếp cho shipper'),
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),
            RadioListTile<String>(
              value: 'VIETQR',
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
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),
            if (_paymentMethod == 'VIETQR')
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.ultraLightGrey,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 36, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ngân hàng Quân Đội (MB Bank)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mã QR thanh toán động sẽ xuất hiện ngay sau khi bạn bấm xác nhận đặt hàng.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),

            // 3. TÓM TẮT ĐƠN HÀNG
            const Text(
              '3. TÓM TẮT ĐƠN HÀNG',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            ...((widget.directBuyItems ?? cartProvider.items).map((item) => Padding(
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
                ))),
            const Divider(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tạm tính:', style: TextStyle(color: AppColors.textSecondary)),
                Text(AppFormatters.formatCurrency(
                  widget.directBuyItems != null
                      ? widget.directBuyItems!.fold<num>(0, (sum, i) => sum + i.itemTotal)
                      : cartProvider.subtotal,
                )),
              ],
            ),
            if (widget.directBuyItems == null && cartProvider.discountAmount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chiết khấu Voucher (${cartProvider.voucherCode}):',
                      style: const TextStyle(color: AppColors.primary)),
                  Text(
                    '-${AppFormatters.formatCurrency(cartProvider.discountAmount)}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng thanh toán:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  AppFormatters.formatCurrency(
                    widget.directBuyItems != null
                        ? widget.directBuyItems!.fold<num>(0, (sum, i) => sum + i.itemTotal)
                        : cartProvider.totalPrice,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.priceHighlight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Nút Xác nhận đặt hàng
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
