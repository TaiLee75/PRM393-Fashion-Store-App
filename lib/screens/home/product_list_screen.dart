import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import 'product_detail_screen.dart';
import '../admin/shop_admin_screen.dart';

/// Màn hình Danh sách sản phẩm (Home & Catalog) chuẩn phong cách Uniqlo
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.filteredProducts;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => productProvider.loadData(),
      child: CustomScrollView(
        slivers: [
          // 1. THANH TÌM KIẾM TỨC THÌ (Real-time Search) & NÚT BỘ LỌC NÂNG CAO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => productProvider.setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm áo thun, áo khoác, quần jean...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.black),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  productProvider.setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.ultraLightGrey,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showFilterBottomSheet(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: productProvider.activeFiltersCount > 0
                            ? AppColors.primary
                            : AppColors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, color: Colors.white, size: 18),
                          if (productProvider.activeFiltersCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${productProvider.activeFiltersCount}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 1.1. DANH SÁCH BỘ LỌC ĐANG HOẠT ĐỘNG (Active Filter Chips)
          if (productProvider.activeFiltersCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (productProvider.selectedPriceRange != 'all')
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            side: const BorderSide(color: AppColors.primary, width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: Text(
                              _formatPriceRangeLabel(productProvider.selectedPriceRange),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                            onDeleted: () => productProvider.clearPriceFilter(),
                          ),
                        ),
                      if (productProvider.selectedSize != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            side: const BorderSide(color: AppColors.primary, width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: Text(
                              'Size: ${productProvider.selectedSize}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                            onDeleted: () => productProvider.clearSizeFilter(),
                          ),
                        ),
                      if (productProvider.selectedColor != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            side: const BorderSide(color: AppColors.primary, width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: Text(
                              'Màu: ${productProvider.selectedColor}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                            onDeleted: () => productProvider.clearColorFilter(),
                          ),
                        ),
                      TextButton(
                        onPressed: () => productProvider.resetFilters(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Xóa tất cả',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. BANNER QUẢNG CÁO PHONG CÁCH UNIQLO LIFEWEAR
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'BỘ SƯU TẬP MỚI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'LIFEWEAR 2026\nĐƠN GIẢN MÀ ĐẲNG CẤP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Mã SALE10 giảm 10% • FREESHIP giảm 30k',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
                ],
              ),
            ),
          ),

          // 3. THANH DANH MỤC NGANG (Horizontal Categories)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildCategoryChip(
                    id: 'all',
                    name: 'Tất cả',
                    isSelected: productProvider.selectedCategoryId == 'all',
                    onTap: () => productProvider.selectCategory('all'),
                  ),
                  ...productProvider.categories.map((cat) {
                    return _buildCategoryChip(
                      id: cat.id,
                      name: cat.name,
                      isSelected: productProvider.selectedCategoryId == cat.id,
                      onTap: () => productProvider.selectCategory(cat.id),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 4. BỘ LỌC & SẮP XẾP THEO GIÁ (Sort Controls)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${products.length} Sản phẩm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: productProvider.sortBy,
                      icon: const Icon(Icons.sort, size: 18, color: AppColors.black),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (val) {
                        if (val != null) productProvider.setSortBy(val);
                      },
                      items: const [
                        DropdownMenuItem(value: 'popular', child: Text('Phổ biến')),
                        DropdownMenuItem(value: 'price_asc', child: Text('Giá: Thấp -> Cao')),
                        DropdownMenuItem(value: 'price_desc', child: Text('Giá: Cao -> Thấp')),
                        DropdownMenuItem(value: 'rating', child: Text('Đánh giá cao nhất')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. GRIDVIEW SẢN PHẨM HOẶC TRẠNG THÁI RỖNG
          if (productProvider.isLoading && products.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (products.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text(
                        'Chưa có dữ liệu sản phẩm trên Firestore',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hãy bấm nút bên dưới để tự động nạp 8 sản phẩm mẫu Unsplash vào hệ thống:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShopAdminScreen()),
                          );
                        },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Mở Admin Tool & Nạp Seed Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];
                    return _buildProductCard(context, product);
                  },
                  childCount: products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String id,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.ultraLightGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.black,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: product.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh sản phẩm Unsplash với tỷ lệ chuẩn
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: product.mainImage,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.ultraLightGrey,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.ultraLightGrey,
                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                    ),
                  ),
                  // Rating Badge
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 12, color: AppColors.star),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tên sản phẩm
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),

          // Giá tiền VND màu đỏ Uniqlo
          Text(
            AppFormatters.formatCurrency(product.price),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.priceHighlight,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPriceRangeLabel(String range) {
    switch (range) {
      case 'under_200k':
        return '< 200.000đ';
      case '200k_400k':
        return '200k - 400k';
      case 'above_400k':
        return '> 400.000đ';
      default:
        return 'Khoảng giá';
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    final productProvider = context.read<ProductProvider>();
    String tempPriceRange = productProvider.selectedPriceRange;
    String? tempSize = productProvider.selectedSize;
    String? tempColor = productProvider.selectedColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableColors = productProvider.availableColors;
            final availableSizes = productProvider.availableSizes;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh gạt modal
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

                    // Tiêu đề & Nút Thiết lập lại
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, color: AppColors.black, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'BỘ LỌC TÌM KIẾM NÂNG CAO',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempPriceRange = 'all';
                              tempSize = null;
                              tempColor = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Thiết lập lại',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // 1. Khoảng giá
                    const Text(
                      'KHOẢNG GIÁ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'Tất cả mức giá',
                          isSelected: tempPriceRange == 'all',
                          onTap: () => setModalState(() => tempPriceRange = 'all'),
                        ),
                        _buildFilterChip(
                          label: 'Dưới 200.000đ',
                          isSelected: tempPriceRange == 'under_200k',
                          onTap: () => setModalState(() => tempPriceRange = 'under_200k'),
                        ),
                        _buildFilterChip(
                          label: '200k - 400.000đ',
                          isSelected: tempPriceRange == '200k_400k',
                          onTap: () => setModalState(() => tempPriceRange = '200k_400k'),
                        ),
                        _buildFilterChip(
                          label: 'Trên 400.000đ',
                          isSelected: tempPriceRange == 'above_400k',
                          onTap: () => setModalState(() => tempPriceRange = 'above_400k'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. Kích cỡ (Size)
                    const Text(
                      'KÍCH CỠ (SIZE)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'Tất cả size',
                          isSelected: tempSize == null,
                          onTap: () => setModalState(() => tempSize = null),
                        ),
                        ...availableSizes.map((size) {
                          return _buildFilterChip(
                            label: size,
                            isSelected: tempSize == size,
                            onTap: () => setModalState(() {
                              tempSize = (tempSize == size) ? null : size;
                            }),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 3. Màu sắc (Color)
                    const Text(
                      'MÀU SẮC',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'Tất cả màu',
                          isSelected: tempColor == null,
                          onTap: () => setModalState(() => tempColor = null),
                        ),
                        ...availableColors.map((color) {
                          return _buildFilterChip(
                            label: color,
                            isSelected: tempColor == color,
                            onTap: () => setModalState(() {
                              tempColor = (tempColor == color) ? null : color;
                            }),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 26),

                    // Nút Áp dụng bộ lọc
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          productProvider.setAdvancedFilters(
                            priceRange: tempPriceRange,
                            size: tempSize,
                            color: tempColor,
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'ÁP DỤNG BỘ LỌC',
                          style: TextStyle(
                            fontSize: 14,
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
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.ultraLightGrey,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.black : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
