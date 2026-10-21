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
    final authProvider = context.read<AuthProvider>();

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
                  // Giá tiền đỏ Uniqlo
                  Text(
                    AppFormatters.formatCurrency(product.price),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.priceHighlight,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Tên sản phẩm & Rating
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
                          if (val) setState(() => _selectedColor = color);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 3. CHỌN KÍCH CỠ (SIZE S/M/L/XL)
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
                        onTap: () => _showSizeChartModal(context),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.straighten, size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Bảng quy đổi kích cỡ',
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
                          if (val) setState(() => _selectedSize = size);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 4. SỐ LƯỢNG
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
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Text(
                              '$_quantity',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: () => setState(() => _quantity++),
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
                ],
              ),
            ),
          ],
        ),
      ),

      // 7. BOTTOM BAR: NÚT THÊM VÀO GIỎ HÀNG
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
          child: ElevatedButton(
            onPressed: () {
              final cartItemId = '${product.id}_${_selectedSize}_$_selectedColor';
              cartProvider.addItem(CartItemModel(
                cartItemId: cartItemId,
                productId: product.id,
                productName: product.name,
                imageUrl: product.mainImage,
                price: product.price,
                size: _selectedSize,
                color: _selectedColor,
                quantity: _quantity,
              ));

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã thêm ${product.name} ($_selectedSize, $_selectedColor) vào giỏ!'),
                  backgroundColor: AppColors.black,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text(
              'THÊM VÀO GIỎ HÀNG',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
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
              Text(
                review.userName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
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

  void _showSizeChartModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                        Icon(Icons.straighten, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'BẢNG QUY ĐỔI KÍCH CỠ (SIZE CHART)',
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
                  'Thông số kích cỡ tiêu chuẩn Châu Á dành cho trang phục nam & nữ phong cách Lifewear.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Divider(height: 24),

                // BẢNG THÔNG SỐ (Data Table)
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
                      // Header Row
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
                      // Size S
                      TableRow(
                        decoration: BoxDecoration(
                          color: _selectedSize == 'S' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        ),
                        children: [
                          _buildTableCell('S', isBold: true, highlight: _selectedSize == 'S'),
                          _buildTableCell('155 - 165 cm'),
                          _buildTableCell('48 - 55 kg'),
                          _buildTableCell('84 - 88 cm'),
                        ],
                      ),
                      // Size M
                      TableRow(
                        decoration: BoxDecoration(
                          color: _selectedSize == 'M' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        ),
                        children: [
                          _buildTableCell('M', isBold: true, highlight: _selectedSize == 'M'),
                          _buildTableCell('164 - 172 cm'),
                          _buildTableCell('56 - 65 kg'),
                          _buildTableCell('88 - 94 cm'),
                        ],
                      ),
                      // Size L
                      TableRow(
                        decoration: BoxDecoration(
                          color: _selectedSize == 'L' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        ),
                        children: [
                          _buildTableCell('L', isBold: true, highlight: _selectedSize == 'L'),
                          _buildTableCell('170 - 178 cm'),
                          _buildTableCell('66 - 75 kg'),
                          _buildTableCell('94 - 100 cm'),
                        ],
                      ),
                      // Size XL
                      TableRow(
                        decoration: BoxDecoration(
                          color: _selectedSize == 'XL' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        ),
                        children: [
                          _buildTableCell('XL', isBold: true, highlight: _selectedSize == 'XL'),
                          _buildTableCell('175 - 185 cm'),
                          _buildTableCell('76 - 88 kg'),
                          _buildTableCell('100 - 108 cm'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // GHI CHÚ MẸO CHỌN SIZE
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ultraLightGrey,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Mẹo chọn size Uniqlo Lifewear:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Muốn mặc ôm vừa vặn (Regular Fit): Hãy chọn đúng theo bảng cân nặng trên.\n• Muốn mặc rộng rãi, thoáng mát (Oversize): Nên tăng lên 1 size.\n• Nếu chiều cao và cân nặng ở 2 mốc khác nhau, nên ưu tiên chọn theo CÂN NẶNG.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Nút Đóng
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'ĐÃ HIỂU, ĐÓNG HƯỚNG DẪN',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

