import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart_item_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../cart/checkout_screen.dart';

/// Màn hình Chi tiết sản phẩm: Chọn Size/Màu, Thêm vào giỏ & Viết Review
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;
  String _selectedSize = '';
  String _selectedColor = '';
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cartProvider = context.read<CartProvider>();
    final authProvider = context.watch<AuthProvider>();

    final ProductModel product = productProvider.allProducts.firstWhere(
      (p) => p.id == widget.productId,
      orElse: () => const ProductModel(
        id: '',
        name: 'Đang tải...',
        categoryId: '',
        price: 0,
        description: '',
        imageUrls: [],
        sizes: [],
        colors: [],
      ),
    );

    if (product.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Tự động chọn size và color đầu tiên nếu chưa chọn
    if (_selectedSize.isEmpty && product.sizes.isNotEmpty) {
      _selectedSize = product.sizes.first;
    }
    if (_selectedColor.isEmpty && product.colors.isNotEmpty) {
      _selectedColor = product.colors.first;
    }

    final variantStock = product.getStockForVariant(_selectedSize, _selectedColor);
    final isFav = authProvider.isFavorite(product.id);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0.5,
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? AppColors.primary : AppColors.black,
            ),
            tooltip: 'Yêu thích',
            onPressed: () {
              if (!authProvider.isAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng đăng nhập để lưu sản phẩm yêu thích!'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              authProvider.toggleWishlist(product.id);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. GALLERY HÌNH ẢNH SẢN PHẨM
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: product.imageUrls.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: product.imageUrls[index],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.ultraLightGrey,
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                  if (product.imageUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${product.imageUrls.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Giá tiền đỏ Uniqlo + Giá gốc nếu có + Huy hiệu giảm giá
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        AppFormatters.formatCurrency(product.price),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.priceHighlight,
                        ),
                      ),
                      if (product.hasDiscount && product.originalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          AppFormatters.formatCurrency(product.originalPrice!),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Tên sản phẩm & Rating & Lượt bán
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.star, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${product.rating.toStringAsFixed(1)} / 5.0',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${product.reviews.length} đánh giá)',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 12, color: Colors.grey.shade300),
                      const SizedBox(width: 12),
                      Text(
                        'Đã bán ${product.soldCount}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // 2. CHỌN MÀU SẮC
                  const Text(
                    'MÀU SẮC',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.colors.map((color) {
                      final isSelected = _selectedColor == color;
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
                          if (val) {
                            setState(() {
                              _selectedColor = color;
                              final newStock = product.getStockForVariant(_selectedSize, color);
                              if (newStock > 0) {
                                if (_quantity > newStock) _quantity = newStock;
                                if (_quantity < 1) _quantity = 1;
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 3. CHỌN KÍCH CỠ (SIZE S/M/L/XL) & TRỢ LÝ SIZE THÔNG MINH
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'KÍCH CỠ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showSmartSizeGuideModal(context, authProvider),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Trợ lý chọn size thông minh',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.sizes.map((size) {
                      final isSelected = _selectedSize == size;
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
                          if (val) {
                            setState(() {
                              _selectedSize = size;
                              final newStock = product.getStockForVariant(size, _selectedColor);
                              if (newStock > 0) {
                                if (_quantity > newStock) _quantity = newStock;
                                if (_quantity < 1) _quantity = 1;
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  // CẢNH BÁO TỒN KHO BIẾN THỂ SKU (Khóa Bẫy 9)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          variantStock > 0 ? Icons.check_circle_outline : Icons.highlight_off,
                          size: 15,
                          color: variantStock > 0 ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          variantStock > 0
                              ? 'Kho còn: $variantStock sản phẩm ($_selectedSize - $_selectedColor)'
                              : 'Hết hàng phân loại này ($_selectedSize - $_selectedColor)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: variantStock > 0 ? Colors.grey.shade700 : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. SỐ LƯỢNG (Tự động kẹp theo tồn kho SKU)
                  Row(
                    children: [
                      const Text(
                        'SỐ LƯỢNG',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: (variantStock > 0 && _quantity > 1)
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Text(
                              '$_quantity',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: (variantStock > 0 && _quantity < variantStock)
                                  ? () => setState(() => _quantity++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // 5. MÔ TẢ SẢN PHẨM
                  const Text(
                    'THÔNG TIN SẢN PHẨM',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 32),

                  // 6. PHẦN ĐÁNH GIÁ (REVIEWS) & NÚT VIẾT ĐÁNH GIÁ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ĐÁNH GIÁ TỪ KHÁCH HÀNG (${product.reviews.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddReviewDialog(context, product, authProvider),
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: const Text('Viết đánh giá'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (product.reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Chưa có đánh giá nào cho sản phẩm này. Hãy là người đầu tiên trải nghiệm!',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    )
                  else
                    ...product.reviews.map((r) => _buildReviewItem(r)),

                  // 7. GỢI Ý SẢN PHẨM TƯƠNG TỰ
                  Builder(
                    builder: (context) {
                      final similarProducts = productProvider.allProducts
                          .where((p) => p.categoryId == product.categoryId && p.id != product.id && p.isActive)
                          .take(4)
                          .toList();

                      if (similarProducts.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 36),
                          const Text(
                            'GỢI Ý SẢN PHẨM TƯƠNG TỰ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: similarProducts.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                final sp = similarProducts[idx];
                                return InkWell(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailScreen(productId: sp.id),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 110,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: CachedNetworkImage(
                                            imageUrl: sp.mainImage,
                                            width: 110,
                                            height: 110,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: AppColors.ultraLightGrey),
                                            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          sp.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppFormatters.formatCurrency(sp.price),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.priceHighlight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 8. BOTTOM BAR: THÊM VÀO GIỎ & MUA NGAY ĐỘC LẬP (Khóa Bẫy 1)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: SafeArea(
          child: variantStock <= 0
              ? SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text(
                      'HẾT HÀNG PHÂN LOẠI NÀY',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Nút THÊM VÀO GIỎ HÀNG
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final cartItemId =
                                '${product.id}_${_selectedSize}_$_selectedColor';
                            final existingIdx = cartProvider.items
                                .indexWhere((i) => i.cartItemId == cartItemId);
                            final currentInCart = existingIdx >= 0
                                ? cartProvider.items[existingIdx].quantity
                                : 0;

                            if (currentInCart >= variantStock) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Giỏ hàng đã có $variantStock sản phẩm (tối đa tồn kho của phân loại này)!',
                                  ),
                                  backgroundColor: AppColors.black,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            cartProvider.addItem(
                              CartItemModel(
                                cartItemId: cartItemId,
                                productId: product.id,
                                productName: product.name,
                                imageUrl: product.mainImage,
                                price: product.price,
                                size: _selectedSize,
                                color: _selectedColor,
                                quantity: _quantity,
                              ),
                              variantStock,
                            );

                            final isMaxed = (currentInCart + _quantity) >= variantStock;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isMaxed && (currentInCart + _quantity) > variantStock
                                      ? 'Đã cập nhật số lượng trong giỏ lên tối đa ($variantStock sản phẩm)!'
                                      : 'Đã thêm ${product.name} ($_selectedSize, $_selectedColor) x$_quantity vào giỏ!',
                                ),
                                backgroundColor: AppColors.black,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text(
                            'THÊM VÀO GIỎ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.black,
                            side: const BorderSide(color: AppColors.black, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nút MUA NGAY ĐỘC LẬP (Khóa Bẫy 1)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            final directItem = CartItemModel(
                              cartItemId: '${product.id}_${_selectedSize}_$_selectedColor',
                              productId: product.id,
                              productName: product.name,
                              imageUrl: product.mainImage,
                              price: product.price,
                              size: _selectedSize,
                              color: _selectedColor,
                              quantity: _quantity,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(directBuyItems: [directItem]),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'MUA NGAY',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ultraLightGrey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        review.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (review.isVerifiedPurchase) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppColors.success, width: 0.6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 10, color: AppColors.success),
                            SizedBox(width: 2),
                            Text(
                              'Đã mua hàng',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppColors.star,
                  ),
                ),
              ),
            ],
          ),
          if (review.variantInfo.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              review.variantInfo,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.formatRelativeTime(review.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _showAddReviewDialog(
    BuildContext context,
    ProductModel product,
    AuthProvider authProvider,
  ) {
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để viết đánh giá sản phẩm!'),
          backgroundColor: AppColors.black,
        ),
      );
      return;
    }

    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Viết Đánh Giá Sản Phẩm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: AppColors.star,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = (index + 1).toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nhận xét về chất vải, form áo, độ co giãn...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      filled: true,
                      fillColor: AppColors.ultraLightGrey,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy', style: TextStyle(color: AppColors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (commentController.text.trim().isEmpty) return;

                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogCtx);
                    final productProvider = context.read<ProductProvider>();
                    final success = await productProvider.addReview(
                      productId: product.id,
                      userName: authProvider.userFullName,
                      rating: selectedRating,
                      comment: commentController.text.trim(),
                      userId: authProvider.userId,
                      variantInfo: 'Phân loại: Size $_selectedSize, Màu $_selectedColor',
                    );

                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Đã gửi đánh giá thành công!'
                              : 'Gửi đánh giá thất bại',
                        ),
                        backgroundColor:
                            success ? AppColors.success : AppColors.error,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Gửi Đánh Giá'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSmartSizeGuideModal(BuildContext context, AuthProvider authProvider) {
    double tempHeight = (authProvider.savedHeight ?? 168.0).clamp(145.0, 195.0);
    double tempWeight = (authProvider.savedWeight ?? 60.0).clamp(40.0, 100.0);

    String calculateSuggestedSize(double height, double weight) {
      if (weight <= 55 && height <= 165) return 'S';
      if (weight <= 65 && height <= 172) return 'M';
      if (weight <= 76 && height <= 178) return 'L';
      return 'XL';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final suggestedSize = calculateSuggestedSize(tempHeight, tempWeight);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                    const SizedBox(height: 14),

                    // Tiêu đề & Nút đóng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'TRỢ LÝ CHỌN SIZE THÔNG MINH',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
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
                    const Text(
                      'Kéo thanh trượt để hệ thống đề xuất size chuẩn Lifewear vừa vặn nhất với cơ thể bạn:',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 24),

                    // 1. THANH TRƯỢT CHIỀU CAO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chiều cao của bạn',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${tempHeight.round()} cm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: tempHeight,
                      min: 145.0,
                      max: 195.0,
                      divisions: 50,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.ultraLightGrey,
                      onChanged: (val) {
                        setModalState(() => tempHeight = val);
                      },
                    ),
                    const SizedBox(height: 8),

                    // 2. THANH TRƯỢT CÂN NẶNG
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cân nặng của bạn',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${tempWeight.round()} kg',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: tempWeight,
                      min: 40.0,
                      max: 100.0,
                      divisions: 60,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.ultraLightGrey,
                      onChanged: (val) {
                        setModalState(() => tempWeight = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // 3. KHỐI HIỂN THỊ KẾT QUẢ GỢI Ý SIZE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'KÍCH CỠ ĐỀ XUẤT TỐI ƯU DÀNH CHO BẠN:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SIZE $suggestedSize',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Form vừa vặn (Regular Fit): Hãy chọn Size $suggestedSize.\n• Thích mặc rộng rãi (Oversize): Bạn có thể cân nhắc tăng lên 1 size.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nút Áp dụng Size này & Lưu số đo
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _selectedSize = suggestedSize;
                            final product = context.read<ProductProvider>().allProducts.firstWhere(
                                  (p) => p.id == widget.productId,
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
                            final newStock = product.getStockForVariant(suggestedSize, _selectedColor);
                            if (newStock > 0) {
                              if (_quantity > newStock) _quantity = newStock;
                              if (_quantity < 1) _quantity = 1;
                            }
                          });

                          if (authProvider.isAuthenticated) {
                            await authProvider.saveBodyMeasurements(
                              heightCm: tempHeight.round(),
                              weightKg: tempWeight.round(),
                            );
                          }

                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã chọn Size $suggestedSize và cập nhật số đo của bạn!'),
                              backgroundColor: AppColors.black,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          'CHỌN SIZE $suggestedSize & LƯU SỐ ĐO',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const Divider(height: 32),

                    // BẢNG THÔNG SỐ CHI TIẾT (Data Table)
                    const Text(
                      'BẢNG THÔNG SỐ QUY ĐỔI TIÊU CHUẨN CHÂU Á',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(2.2),
                          2: FlexColumnWidth(2.0),
                          3: FlexColumnWidth(2.0),
                        },
                        border: TableBorder.symmetric(
                          inside: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                            children: [
                              _buildTableHeaderCell('SIZE'),
                              _buildTableHeaderCell('CHIỀU CAO'),
                              _buildTableHeaderCell('CÂN NẶNG'),
                              _buildTableHeaderCell('RỘNG NGỰC'),
                            ],
                          ),
                          TableRow(
                            decoration: BoxDecoration(
                              color: suggestedSize == 'S' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                            ),
                            children: [
                              _buildTableCell('S', isBold: true, highlight: suggestedSize == 'S'),
                              _buildTableCell('155 - 165 cm'),
                              _buildTableCell('48 - 55 kg'),
                              _buildTableCell('84 - 88 cm'),
                            ],
                          ),
                          TableRow(
                            decoration: BoxDecoration(
                              color: suggestedSize == 'M' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                            ),
                            children: [
                              _buildTableCell('M', isBold: true, highlight: suggestedSize == 'M'),
                              _buildTableCell('164 - 172 cm'),
                              _buildTableCell('56 - 65 kg'),
                              _buildTableCell('88 - 94 cm'),
                            ],
                          ),
                          TableRow(
                            decoration: BoxDecoration(
                              color: suggestedSize == 'L' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                            ),
                            children: [
                              _buildTableCell('L', isBold: true, highlight: suggestedSize == 'L'),
                              _buildTableCell('170 - 178 cm'),
                              _buildTableCell('66 - 75 kg'),
                              _buildTableCell('94 - 100 cm'),
                            ],
                          ),
                          TableRow(
                            decoration: BoxDecoration(
                              color: suggestedSize == 'XL' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                            ),
                            children: [
                              _buildTableCell('XL', isBold: true, highlight: suggestedSize == 'XL'),
                              _buildTableCell('175 - 185 cm'),
                              _buildTableCell('76 - 88 kg'),
                              _buildTableCell('100 - 108 cm'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: highlight ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

