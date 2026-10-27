import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart_item_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import 'checkout_screen.dart';

/// Màn hình Giỏ hàng chuẩn Uniqlo Lifewear:
/// - Checkbox chọn từng món & "Chọn tất cả" (Khóa Bẫy 1)
/// - Thanh tiến trình Miễn phí Vận chuyển trực quan (Freeship Progress Bar)
/// - Đối chiếu live với ProductProvider: cảnh báo hết hàng/ngừng kinh doanh (Khóa Bẫy 9)
/// - Đổi nhanh Size/Màu ngay trong Giỏ hàng & tự động gộp số lượng (Khóa Bẫy 2)
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
    CartItemModel item,
    CartProvider cartProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('HỦY', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
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

  void _showChangeVariantModal(
    BuildContext context,
    CartItemModel item,
    ProductModel product,
    CartProvider cartProvider,
  ) {
    if (product.id.isEmpty) return;

    String tempSize = item.size;
    String tempColor = item.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final variantStock = product.getStockForVariant(tempSize, tempColor);
            final isStockAvailable = variantStock > 0;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ĐỔI PHÂN LOẠI SẢN PHẨM',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 20),

                    // 1. CHỌN MÀU SẮC
                    const Text(
                      'MÀU SẮC',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: product.colors.map((color) {
                        final isSelected = tempColor == color;
                        return ChoiceChip(
                          label: Text(color),
                          selected: isSelected,
                          selectedColor: AppColors.black,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.ultraLightGrey,
                          onSelected: (val) {
                            if (val) setModalState(() => tempColor = color);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 2. CHỌN KÍCH CỠ
                    const Text(
                      'KÍCH CỠ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: product.sizes.map((size) {
                        final isSelected = tempSize == size;
                        return ChoiceChip(
                          label: Text(size),
                          selected: isSelected,
                          selectedColor: AppColors.black,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.ultraLightGrey,
                          onSelected: (val) {
                            if (val) setModalState(() => tempSize = size);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // TỒN KHO BIẾN THỂ
                    Row(
                      children: [
                        Icon(
                          isStockAvailable ? Icons.check_circle_outline : Icons.highlight_off,
                          size: 15,
                          color: isStockAvailable ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isStockAvailable
                              ? 'Kho còn: $variantStock sản phẩm ($tempSize - $tempColor)'
                              : 'Hết hàng phân loại này ($tempSize - $tempColor)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isStockAvailable ? Colors.grey.shade700 : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // NÚT XÁC NHẬN
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: isStockAvailable
                            ? () {
                                cartProvider.updateItemVariant(
                                  oldCartItemId: item.cartItemId,
                                  newSize: tempSize,
                                  newColor: tempColor,
                                  maxVariantStock: variantStock,
                                );
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã đổi sang phân loại $tempSize, $tempColor!'),
                                    backgroundColor: AppColors.black,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: Text(
                          isStockAvailable ? 'XÁC NHẬN ĐỔI' : 'HẾT HÀNG PHÂN LOẠI NÀY',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final productProvider = context.watch<ProductProvider>();
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

    // Khóa Bẫy 9: Nhận diện danh sách biến thể hết hàng hoặc ngừng kinh doanh
    final unavailableIds = <String>{};
    if (productProvider.allProducts.isNotEmpty) {
      for (final item in items) {
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
        final variantStock = product.id.isNotEmpty
            ? product.getStockForVariant(item.size, item.color)
            : 0;
        final isAvailable =
            product.id.isNotEmpty && product.isActive && variantStock > 0;
        if (!isAvailable) {
          unavailableIds.add(item.cartItemId);
        }
      }
    }

    return Column(
      children: [
        // 1. THANH TIẾN TRÌNH MIỄN PHÍ VẬN CHUYỂN (FREESHIP PROGRESS BAR)
        _buildFreeshipBanner(cartProvider.subtotal),

        // 2. THANH CHỌN TẤT CẢ (SELECT ALL HEADER)
        _buildSelectAllHeader(cartProvider, unavailableIds),

        // 3. DANH SÁCH MÓN TRONG GIỎ HÀNG
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final item = items[index];
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

              final variantStock = product.id.isNotEmpty
                  ? product.getStockForVariant(item.size, item.color)
                  : 0;
              final isAvailable =
                  product.id.isNotEmpty && product.isActive && variantStock > 0;

              return _buildCartItemCard(
                context,
                item: item,
                product: product,
                variantStock: variantStock,
                isAvailable: isAvailable,
                cartProvider: cartProvider,
              );
            },
          ),
        ),

        // 4. FOOTER TỔNG TIỀN & CHECKOUT
        _buildBottomCheckoutBar(context, cartProvider),
      ],
    );
  }

  /// 1. Thanh tiến trình Freeship
  Widget _buildFreeshipBanner(num currentSubtotal) {
    const threshold = AppConstants.freeShippingThreshold; // 499.000đ
    final isQualified = currentSubtotal >= threshold;
    final remaining = isQualified ? 0 : threshold - currentSubtotal;
    final progress = (currentSubtotal / threshold).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      color: isQualified
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isQualified ? Icons.local_shipping : Icons.local_shipping_outlined,
                size: 18,
                color: isQualified ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isQualified
                      ? '🎉 Đơn hàng đã đủ điều kiện MIỄN PHÍ VẬN CHUYỂN!'
                      : 'Mua thêm ${AppFormatters.formatCurrency(remaining)} để được MIỄN PHÍ VẬN CHUYỂN!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isQualified ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isQualified ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Header chọn tất cả (Loại trừ các món hết hàng/ngừng bán - Khóa Bẫy 9)
  Widget _buildSelectAllHeader(CartProvider cartProvider, Set<String> unavailableIds) {
    final isAll = cartProvider.isAllSelected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isAll,
            activeColor: AppColors.primary,
            onChanged: (val) {
              cartProvider.toggleSelectAll(val ?? false, unavailableIds);
            },
          ),
          Text(
            'Chọn tất cả (${cartProvider.selectedQuantity}/${cartProvider.totalQuantity} món)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (cartProvider.selectedQuantity > 0)
            TextButton.icon(
              onPressed: () => cartProvider.removePurchasedItems(),
              icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.grey),
              label: const Text(
                'Xóa đã chọn',
                style: TextStyle(fontSize: 12, color: AppColors.grey),
              ),
            ),
        ],
      ),
    );
  }

  /// 3. Thẻ sản phẩm
  Widget _buildCartItemCard(
    BuildContext context, {
    required CartItemModel item,
    required ProductModel product,
    required int variantStock,
    required bool isAvailable,
    required CartProvider cartProvider,
  }) {
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.55,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox chọn món (Khóa Bẫy 1 & Bẫy 9)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Checkbox(
              value: item.isSelected && isAvailable,
              activeColor: AppColors.primary,
              onChanged: isAvailable
                  ? (_) => cartProvider.toggleItemSelection(item.cartItemId)
                  : null,
            ),
          ),

          // Ảnh sản phẩm
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

          // Chi tiết & Đổi phân loại
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên sản phẩm
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // Nút Đổi phân loại Size/Màu nhanh (Khóa Bẫy 2)
                InkWell(
                  onTap: product.id.isNotEmpty
                      ? () => _showChangeVariantModal(context, item, product, cartProvider)
                      : null,
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.ultraLightGrey,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Size: ${item.size}  |  Màu: ${item.color}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),

                // Cảnh báo hết hàng / ngừng bán (Khóa Bẫy 9)
                if (!isAvailable) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.id.isEmpty
                        ? 'Sản phẩm không còn tồn tại'
                        : (!product.isActive
                            ? 'Sản phẩm ngừng kinh doanh'
                            : 'Hết hàng phân loại này'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],

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

          // Bộ tăng giảm số lượng & Xóa
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmRemoveItem(context, item, cartProvider),
              ),
              const SizedBox(height: 16),
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
                      onTap: (isAvailable && item.quantity < variantStock)
                          ? () => cartProvider.updateQuantity(
                                item.cartItemId,
                                item.quantity + 1,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Icon(
                          Icons.add,
                          size: 14,
                          color: (isAvailable && item.quantity < variantStock)
                              ? AppColors.black
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. Footer tổng tiền & Checkout
  Widget _buildBottomCheckoutBar(BuildContext context, CartProvider cartProvider) {
    final selectedCount = cartProvider.selectedQuantity;
    final subtotal = cartProvider.subtotal;

    return Container(
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
          // Bảng tóm tắt tiền (chỉ tính trên các món được chọn)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tạm tính ($selectedCount món):',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              Text(
                AppFormatters.formatCurrency(subtotal),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          if (cartProvider.discountAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Giảm giá (${cartProvider.voucherCode}):',
                    style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                Text(
                  '-${AppFormatters.formatCurrency(cartProvider.discountAmount)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng thanh toán:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
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
          const SizedBox(height: 12),

          // Nút Thanh toán
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedCount > 0
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                      );
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn ít nhất 1 sản phẩm để thanh toán!'),
                          backgroundColor: AppColors.black,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedCount > 0 ? AppColors.primary : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: Text(
                selectedCount > 0
                    ? 'TIẾN HÀNH THANH TOÁN ($selectedCount)'
                    : 'CHỌN SẢN PHẨM ĐỂ THANH TOÁN',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
