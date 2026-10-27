import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import 'admin_product_form_screen.dart';

/// Màn hình Quản lý Danh sách Sản phẩm, Kho hàng và Danh mục dành cho Shop Admin
class AdminProductListScreen extends StatefulWidget {
  const AdminProductListScreen({super.key});

  @override
  State<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends State<AdminProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteProduct(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa sản phẩm "${product.name}" khỏi hệ thống? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY BỎ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final productProvider = context.read<ProductProvider>();
              final success = await productProvider.deleteProduct(product.id);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🗑️ Đã xóa sản phẩm "${product.name}"'),
                      backgroundColor: AppColors.black,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        productProvider.errorMessage ?? 'Xóa sản phẩm thất bại',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('XÓA VĨNH VIỄN'),
          ),
        ],
      ),
    );
  }

  /// Hộp thoại Nhập kho nhanh (+Stock) và chuyển trạng thái kinh doanh
  void _showQuickRestockDialog(BuildContext context, ProductModel product) {
    final stockController = TextEditingController(text: '10');
    String? selectedSku;
    bool isActive = product.isActive;

    // Danh sách SKU nếu có
    final skuKeys = product.variantStock.keys.toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.add_box_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nhập kho: ${product.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng tồn kho hiện tại:',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${product.stock} sp',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (skuKeys.isNotEmpty) ...[
                    const Text(
                      'Chọn biến thể SKU cần nhập thêm:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedSku,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tất cả (Cộng dồn kho chung)'),
                        ),
                        ...skuKeys.map((sku) {
                          final currentSkuStock =
                              product.variantStock[sku] ?? 0;
                          return DropdownMenuItem<String?>(
                            value: sku,
                            child: Text('$sku (hiện có: $currentSkuStock)'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedSku = val);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextFormField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng nhập thêm (+Stock) *',
                      hintText: 'VD: 10, 50, 100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_outlined),
                      suffixText: 'sản phẩm',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Trạng thái kinh doanh',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isActive ? 'Đang mở bán' : 'Đang ngừng bán',
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive ? AppColors.success : AppColors.error,
                        ),
                      ),
                      value: isActive,
                      activeThumbColor: AppColors.success,
                      onChanged: (val) {
                        setDialogState(() => isActive = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final addStock = int.tryParse(stockController.text.trim()) ?? 0;
                  if (addStock < 0 || (addStock == 0 && isActive == product.isActive)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập số lượng hợp lệ (>= 0)'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  final productProvider = context.read<ProductProvider>();

                  bool success = true;
                  if (addStock > 0) {
                    success = await productProvider.quickRestockProduct(
                      productId: product.id,
                      additionalStock: addStock,
                      skuKey: selectedSku,
                    );
                  }

                  // Cập nhật trạng thái isActive nếu có thay đổi
                  if (isActive != product.isActive) {
                    final updated = product.copyWith(isActive: isActive);
                    await productProvider.updateProduct(updated);
                  }

                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Đã nhập kho thành công cho "${product.name}"!',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            productProvider.errorMessage ??
                                'Nhập kho thất bại',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('CẬP NHẬT KHO'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() => stockController.dispose());
  }

  /// Mở hộp thoại Quản lý Danh mục (Thêm / Sửa / Xóa)
  void _showCategoryManagementDialog(BuildContext context) {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final productProvider = context.watch<ProductProvider>();
            final categories = productProvider.categories;

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.category, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'QUẢN LÝ DANH MỤC',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Thêm danh mục mới
                    const Text(
                      'Thêm danh mục mới:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              hintText: 'Nhập tên danh mục (VD: Quần Short)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            final newCat = CategoryModel(
                              id: '',
                              name: name,
                              iconUrl:
                                  'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=100',
                            );
                            nameController.clear();

                            final success = await context
                                .read<ProductProvider>()
                                .addCategory(newCat);

                            if (context.mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 Đã thêm danh mục "$name"'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      productProvider.errorMessage ??
                                          'Thêm danh mục thất bại',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('THÊM'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Danh sách danh mục hiện có
                    const Text(
                      'Danh mục hiện hành trên Firestore:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Chưa có danh mục nào',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final cat = categories[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              cat.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${cat.id}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Sửa danh mục
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Đổi tên',
                                  onPressed: () {
                                    _showEditCategoryDialog(context, cat);
                                  },
                                ),
                                // Xóa danh mục
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  tooltip: 'Xóa',
                                  onPressed: () {
                                    _confirmDeleteCategory(context, cat);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => nameController.dispose());
  }

  void _showEditCategoryDialog(BuildContext context, CategoryModel category) {
    final editController = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Đổi tên danh mục',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: TextFormField(
          controller: editController,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục mới *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);

              final updated = category.copyWith(name: newName);
              final success = await context
                  .read<ProductProvider>()
                  .updateCategory(updated);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Đã cập nhật danh mục "$newName"'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('LƯU'),
          ),
        ],
      ),
    ).whenComplete(() => editController.dispose());
  }

  void _confirmDeleteCategory(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa danh mục "${category.name}"? Danh mục đang có sản phẩm sẽ không thể xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final productProvider = context.read<ProductProvider>();
              final success =
                  await productProvider.deleteCategory(category.id);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🗑️ Đã xóa danh mục "${category.name}"'),
                      backgroundColor: AppColors.black,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        productProvider.errorMessage ??
                            'Không thể xóa danh mục này',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final allProducts = productProvider.allProducts;
    final categories = productProvider.categories;

    // Lọc theo từ khóa và danh mục động
    final query = _searchController.text.trim().toLowerCase();
    final filtered = allProducts.where((p) {
      final matchesCat =
          _selectedCategory == 'all' || p.categoryId == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.id.toLowerCase().contains(query);
      return matchesCat && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'QUẢN LÝ KHO SẢN PHẨM',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Quản lý Danh mục',
            onPressed: () => _showCategoryManagementDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'THÊM SẢN PHẨM',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminProductFormScreen(),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // 1. THANH TÌM KIẾM
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên sản phẩm hoặc mã...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // 2. THANH LỌC DANH MỤC ĐỘNG TỪ FIRESTORE
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _selectedCategory == 'all',
                    selectedColor: AppColors.black,
                    backgroundColor: AppColors.background,
                    labelStyle: TextStyle(
                      color: _selectedCategory == 'all'
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: _selectedCategory == 'all'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = 'all');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((cat) {
                    final isSelected = _selectedCategory == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        selectedColor: AppColors.black,
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat.id);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // 3. DANH SÁCH SẢN PHẨM
          Expanded(
            child: productProvider.isLoading && allProducts.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              query.isNotEmpty
                                  ? 'Không tìm thấy sản phẩm nào khớp với "$query"'
                                  : 'Kho hàng chưa có sản phẩm nào',
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => productProvider.loadData(),
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            return _buildProductAdminCard(context, product);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductAdminCard(BuildContext context, ProductModel product) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Ảnh
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade100,
                child: product.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrls.first,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          size: 30,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(Icons.image, size: 30, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),

            // Thông tin sản phẩm
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        AppFormatters.formatVND(product.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      if (product.originalPrice != null &&
                          product.originalPrice! > product.price) ...[
                        const SizedBox(width: 6),
                        Text(
                          AppFormatters.formatVND(product.originalPrice!),
                          style: TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Tồn kho, Đã bán & Trạng thái kinh doanh
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildMiniBadge(
                        product.isActive ? 'Đang bán' : 'Ngừng bán',
                        product.isActive
                            ? Colors.green.shade50
                            : Colors.grey.shade200,
                        product.isActive
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                      ),
                      _buildMiniBadge(
                        'Tồn kho: ${product.stock} | Đã bán: ${product.soldCount}',
                        Colors.indigo.shade50,
                        Colors.indigo.shade800,
                      ),
                      _buildMiniBadge(
                        'Size: ${product.sizes.join(", ")}',
                        Colors.blueGrey.shade50,
                        Colors.blueGrey.shade800,
                      ),
                      _buildMiniBadge(
                        '${product.colors.length} màu',
                        Colors.orange.shade50,
                        Colors.orange.shade900,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Nút Nhập kho nhanh (+Stock)
                  InkWell(
                    onTap: () => _showQuickRestockDialog(context, product),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_box_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '+Stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Nút Thao tác: Sửa & Xóa
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.blue, size: 20),
                  tooltip: 'Chỉnh sửa sản phẩm',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminProductFormScreen(product: product),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  tooltip: 'Xóa sản phẩm',
                  onPressed: () => _confirmDeleteProduct(context, product),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
