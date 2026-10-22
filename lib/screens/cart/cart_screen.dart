import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart';

/// Màn hình Giỏ hàng: Xem danh sách theo size/màu, tăng giảm SL, áp voucher
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _voucherController = TextEditingController();

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemoveItem(
    BuildContext context,
    dynamic item,
    CartProvider cartProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Xóa sản phẩm',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có muốn xóa "${item.productName} (${item.size}, ${item.color})" khỏi giỏ hàng?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      cartProvider.removeItem(item.cartItemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final items = cartProvider.items;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[350]),
            const SizedBox(height: 16),
            const Text(
              'Giỏ hàng của bạn đang trống',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy chọn cho mình những bộ trang phục thời thượng nhất',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 1. DANH SÁCH MÓN TRONG GIỎ
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final item = items[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ảnh món
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.ultraLightGrey),
                      errorWidget: (_, __, ___) => const Icon(Icons.image),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Tên + Size/Color + Giá
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Size: ${item.size}  |  Màu: ${item.color}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormatters.formatCurrency(item.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.priceHighlight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bộ tăng giảm số lượng & Nút xóa
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.grey),
                        onPressed: () => _confirmRemoveItem(context, item, cartProvider),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (item.quantity <= 1) {
                                  _confirmRemoveItem(context, item, cartProvider);
                                } else {
                                  cartProvider.updateQuantity(
                                    item.cartItemId,
                                    item.quantity - 1,
                                  );
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Icon(Icons.remove, size: 14),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => cartProvider.updateQuantity(
                                item.cartItemId,
                                item.quantity + 1,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Icon(Icons.add, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        // 2. PHẦN TỔNG TIỀN & ÁP MÃ VOUCHER
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Badge Voucher đang áp dụng
              if (cartProvider.voucherCode.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          'Đang áp dụng mã: ${cartProvider.voucherCode}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          cartProvider.removeVoucher();
                          _voucherController.clear();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Hủy mã',
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

              // Ô nhập Voucher
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherController,
                      decoration: InputDecoration(
                        hintText: 'Nhập mã giảm giá (SALE10 / FREESHIP)',
                        hintStyle: const TextStyle(fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.ultraLightGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final ok = cartProvider.applyVoucher(_voucherController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Áp dụng mã ${cartProvider.voucherCode} thành công!'
                                : 'Mã giảm giá không hợp lệ',
                          ),
                          backgroundColor: ok ? AppColors.success : AppColors.error,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bảng tóm tắt tiền
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tạm tính:', style: TextStyle(color: AppColors.textSecondary)),
                  Text(
                    AppFormatters.formatCurrency(cartProvider.subtotal),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (cartProvider.discountAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Giảm giá (${cartProvider.voucherCode}):',
                        style: const TextStyle(color: AppColors.primary)),
                    Text(
                      '-${AppFormatters.formatCurrency(cartProvider.discountAmount)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng thanh toán:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    AppFormatters.formatCurrency(cartProvider.totalPrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.priceHighlight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Nút Đặt hàng / Thanh toán
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text(
                    'TIẾN HÀNH THANH TOÁN',
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
      ],
    );
  }
}
