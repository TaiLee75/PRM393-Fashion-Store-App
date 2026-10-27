import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';

/// Màn hình Thêm mới hoặc Chỉnh sửa Sản phẩm dành cho Admin (Khóa Bẫy 12 & Bẫy 17)
class AdminProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const AdminProductFormScreen({super.key, this.product});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  final List<TextEditingController> _additionalImageControllers = [];

  String _selectedCategoryId = 'cat_aothun';
  final List<String> _selectedSizes = [];
  final List<String> _selectedColors = [];
  bool _isActive = true;
  bool _isSaving = false;

  final List<String> _availableSizes = [
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'FreeSize',
  ];

  final List<String> _availableColors = [
    'Đen',
    'Trắng',
    'Xám',
    'Be',
    'Xanh Navy',
    'Nâu',
  ];

  bool get isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(
      text: p != null ? p.price.toInt().toString() : '',
    );
    _originalPriceController = TextEditingController(
      text: p?.originalPrice != null ? p!.originalPrice!.toInt().toString() : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.stock.toString() : '99',
    );
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _imageUrlController = TextEditingController(
      text: p != null && p.imageUrls.isNotEmpty ? p.imageUrls.first : '',
    );

    // Ảnh phụ nếu có
    if (p != null && p.imageUrls.length > 1) {
      for (int i = 1; i < p.imageUrls.length; i++) {
        _additionalImageControllers.add(
          TextEditingController(text: p.imageUrls[i]),
        );
      }
    }

    if (p != null) {
      _selectedCategoryId = p.categoryId;
      _selectedSizes.addAll(p.sizes);
      _selectedColors.addAll(p.colors);
      _isActive = p.isActive;

      // Bổ sung các size/màu tùy chỉnh nếu có trong sản phẩm cũ
      for (final s in p.sizes) {
        if (!_availableSizes.contains(s)) {
          _availableSizes.add(s);
        }
      }
      for (final c in p.colors) {
        if (!_availableColors.contains(c)) {
          _availableColors.add(c);
        }
      }
    } else {
      // Mặc định chọn một số size và màu phổ biến
      _selectedSizes.addAll(['M', 'L']);
      _selectedColors.addAll(['Đen', 'Trắng']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    for (final ctrl in _additionalImageControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _showAddCustomSizeDialog() {
    final customSizeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm kích cỡ mới', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: customSizeController,
          decoration: const InputDecoration(
            labelText: 'Kích cỡ (VD: 3XL, 29, 30, Oversized)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final newSize = customSizeController.text.trim();
              if (newSize.isNotEmpty) {
                setState(() {
                  if (!_availableSizes.contains(newSize)) {
                    _availableSizes.add(newSize);
                  }
                  if (!_selectedSizes.contains(newSize)) {
                    _selectedSizes.add(newSize);
                  }
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('THÊM'),
          ),
        ],
      ),
    ).whenComplete(() => customSizeController.dispose());
  }

  void _showAddCustomColorDialog() {
    final customColorController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm màu sắc mới', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: customColorController,
          decoration: const InputDecoration(
            labelText: 'Tên màu sắc (VD: Hồng pastel, Xanh rêu, Tím than)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final newColor = customColorController.text.trim();
              if (newColor.isNotEmpty) {
                setState(() {
                  if (!_availableColors.contains(newColor)) {
                    _availableColors.add(newColor);
                  }
                  if (!_selectedColors.contains(newColor)) {
                    _selectedColors.add(newColor);
                  }
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('THÊM'),
          ),
        ],
      ),
    ).whenComplete(() => customColorController.dispose());
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một kích cỡ (Size)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một màu sắc'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final cleanPrice = num.tryParse(
          _priceController.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    final originalPriceText = _originalPriceController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final cleanOriginalPrice = originalPriceText.isNotEmpty ? num.tryParse(originalPriceText) : null;

    final cleanStock = int.tryParse(
          _stockController.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        99;

    // Gom danh sách ảnh (Primary + Additional)
    final List<String> imageUrls = [];
    final primaryUrl = _imageUrlController.text.trim();
    if (primaryUrl.isNotEmpty) {
      imageUrls.add(primaryUrl);
    }
    for (final ctrl in _additionalImageControllers) {
      final extraUrl = ctrl.text.trim();
      if (extraUrl.isNotEmpty && !imageUrls.contains(extraUrl)) {
        imageUrls.add(extraUrl);
      }
    }
    if (imageUrls.isEmpty) {
      imageUrls.add(
        'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800',
      );
    }

    // Xây dựng variantStock cho các SKU
    final Map<String, int> variantStock =
        widget.product != null ? Map<String, int>.from(widget.product!.variantStock) : {};

    // Khởi tạo các SKU mới nếu chưa có
    final perSkuStock = (_selectedSizes.isNotEmpty && _selectedColors.isNotEmpty)
        ? (cleanStock / (_selectedSizes.length * _selectedColors.length)).floor()
        : cleanStock;

    for (final s in _selectedSizes) {
      for (final c in _selectedColors) {
        final key = '${s}_$c';
        variantStock.putIfAbsent(key, () => perSkuStock > 0 ? perSkuStock : 10);
      }
    }

    final productProvider = context.read<ProductProvider>();
    final categories = productProvider.categories;
    final saveCategoryId = categories.any((c) => c.id == _selectedCategoryId)
        ? _selectedCategoryId
        : (categories.isNotEmpty ? categories.first.id : _selectedCategoryId);

    bool success = false;

    // Khóa Bẫy 17: Giữ nguyên reviews, rating, soldCount
    if (isEditMode) {
      final updatedProduct = ProductModel(
        id: widget.product!.id,
        name: _nameController.text.trim(),
        categoryId: saveCategoryId,
        price: cleanPrice,
        originalPrice: (cleanOriginalPrice != null && cleanOriginalPrice > cleanPrice)
            ? cleanOriginalPrice
            : null,
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        sizes: _selectedSizes,
        colors: _selectedColors,
        stock: cleanStock,
        variantStock: variantStock,
        isActive: _isActive,
        soldCount: widget.product!.soldCount,
        rating: widget.product!.rating,
        reviews: widget.product!.reviews,
      );
      success = await productProvider.updateProduct(updatedProduct);
    } else {
      final newProduct = ProductModel(
        id: '', // FirestoreService sẽ tự sinh id
        name: _nameController.text.trim(),
        categoryId: saveCategoryId,
        price: cleanPrice,
        originalPrice: (cleanOriginalPrice != null && cleanOriginalPrice > cleanPrice)
            ? cleanOriginalPrice
            : null,
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        sizes: _selectedSizes,
        colors: _selectedColors,
        stock: cleanStock,
        variantStock: variantStock,
        isActive: _isActive,
        soldCount: 0,
        rating: 5.0,
        reviews: const [],
      );
      success = await productProvider.addProduct(newProduct);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? '✅ Cập nhật sản phẩm thành công!'
                : '🎉 Thêm mới sản phẩm thành công!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productProvider.errorMessage ?? 'Thao tác lưu sản phẩm thất bại!',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final categories = productProvider.categories;

    // Khóa Bẫy 12: Kiểm tra an toàn effectiveCategoryId để triệt tiêu lỗi DropdownButtonFormField AssertionError
    final effectiveCategoryId = categories.any((c) => c.id == _selectedCategoryId)
        ? _selectedCategoryId
        : (categories.isNotEmpty ? categories.first.id : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'CHỈNH SỬA SẢN PHẨM' : 'THÊM MỚI SẢN PHẨM',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. THÔNG TIN CƠ BẢN
            _buildSectionHeader('1. Thông tin cơ bản & Danh mục'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên sản phẩm *',
                      hintText: 'VD: Áo Thun Polo Nam Pique Cotton',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (v) =>
                        AppValidators.validateRequired(v, 'Tên sản phẩm'),
                  ),
                  const SizedBox(height: 16),

                  // Khóa Bẫy 12: Dropdown nạp động 100% từ Firestore với fallback an toàn
                  DropdownButtonFormField<String>(
                    initialValue: effectiveCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục sản phẩm *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categories.isEmpty
                        ? [
                            const DropdownMenuItem<String>(
                              value: 'cat_aothun',
                              child: Text('Áo Thun & Polo (Mặc định)'),
                            ),
                          ]
                        : categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.id,
                              child: Text(cat.name),
                            );
                          }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategoryId = val);
                      }
                    },
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn danh mục' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Giá bán hiện tại
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Đơn giá bán (VNĐ) *',
                            hintText: 'VD: 250000',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                            suffixText: 'đ',
                          ),
                          validator: AppValidators.validatePrice,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Giá gốc / niêm yết (nếu có giảm giá)
                      Expanded(
                        child: TextFormField(
                          controller: _originalPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giá niêm yết (Gốc)',
                            hintText: 'VD: 350000',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.money_off_outlined),
                            suffixText: 'đ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (_isDiscountApplicable) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        '🔥 Đang áp dụng giảm giá: -$_calculatedDiscountPercent% so với giá gốc',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết sản phẩm *',
                      hintText:
                          'Chất liệu 100% cotton thoáng mát, form dáng regular-fit thoải mái...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        AppValidators.validateRequired(v, 'Mô tả sản phẩm'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. HÌNH ẢNH SẢN PHẨM (Unsplash URL)
            _buildSectionHeader('2. Hình ảnh sản phẩm (Public URLs)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: InputDecoration(
                      labelText: 'Đường dẫn ảnh chính (URL) *',
                      hintText: 'https://images.unsplash.com/...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.image_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Tải lại xem trước',
                        onPressed: () => setState(() {}),
                      ),
                    ),
                    validator: AppValidators.validateUrl,
                    onChanged: (_) => setState(() {}),
                  ),

                  // Các ảnh phụ
                  if (_additionalImageControllers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...List.generate(_additionalImageControllers.length, (idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _additionalImageControllers[idx],
                                decoration: InputDecoration(
                                  labelText: 'Đường dẫn ảnh phụ ${idx + 1}',
                                  hintText: 'https://images.unsplash.com/...',
                                  border: const OutlineInputBorder(),
                                  prefixIcon:
                                      const Icon(Icons.add_photo_alternate_outlined),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.error),
                              tooltip: 'Xóa ảnh này',
                              onPressed: () {
                                setState(() {
                                  _additionalImageControllers[idx].dispose();
                                  _additionalImageControllers.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _additionalImageControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add_link, size: 18),
                    label: const Text('+ Thêm link ảnh phụ'),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Xem trước hình ảnh chính (Preview):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imageUrlController.text.trim().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _imageUrlController.text.trim(),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image,
                                        size: 40, color: Colors.grey),
                                    SizedBox(height: 6),
                                    Text('URL ảnh không hợp lệ hoặc bị lỗi',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          : const Center(
                              child: Text(
                                'Dán link ảnh để xem trước',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. KÍCH CỠ, MÀU SẮC & TỒN KHO
            _buildSectionHeader('3. Kích cỡ, Màu sắc & Tồn kho'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kích cỡ (Sizes) có sẵn *:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: _showAddCustomSizeDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Thêm size khác', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSizes.map((size) {
                      final isSelected = _selectedSizes.contains(size);
                      return FilterChip(
                        label: Text(size),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSizes.add(size);
                            } else {
                              _selectedSizes.remove(size);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Màu sắc (Colors) có sẵn *:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: _showAddCustomColorDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Thêm màu khác', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((color) {
                      final isSelected = _selectedColors.contains(color);
                      return FilterChip(
                        label: Text(color),
                        selected: isSelected,
                        selectedColor: AppColors.black,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedColors.add(color);
                            } else {
                              _selectedColors.remove(color);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const Divider(height: 28),

                  // Quản lý Tồn kho tổng và Trạng thái
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tổng tồn kho (Stock) *',
                      hintText: 'VD: 99, 150',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      suffixText: 'sản phẩm',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập số lượng tồn kho';
                      }
                      if (int.tryParse(v.trim()) == null) {
                        return 'Số lượng tồn kho phải là số nguyên';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Trạng thái kinh doanh trên App',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        _isActive
                            ? 'Đang mở bán công khai cho khách hàng'
                            : 'Tạm ẩn / Ngừng bán sản phẩm này',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isActive ? AppColors.success : AppColors.error,
                        ),
                      ),
                      value: _isActive,
                      activeThumbColor: AppColors.success,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // NÚT LƯU SẢN PHẨM
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSaving
                      ? 'ĐANG LƯU DỮ LIỆU...'
                      : (isEditMode
                          ? 'CẬP NHẬT SẢN PHẨM'
                          : 'THÊM MỚI VÀO KHO HÀNG'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  bool get _isDiscountApplicable {
    final price = num.tryParse(_priceController.text.trim()) ?? 0;
    final orig = num.tryParse(_originalPriceController.text.trim()) ?? 0;
    return orig > price && price > 0;
  }

  int get _calculatedDiscountPercent {
    final price = num.tryParse(_priceController.text.trim()) ?? 0;
    final orig = num.tryParse(_originalPriceController.text.trim()) ?? 0;
    if (orig <= price || orig <= 0) return 0;
    return (((orig - price) / orig) * 100).round();
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }
}
