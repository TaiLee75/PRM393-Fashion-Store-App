import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';

/// Màn hình Thêm mới hoặc Chỉnh sửa Sản phẩm dành cho Admin
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
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  String _selectedCategoryId = 'cat_aothun';
  final List<String> _selectedSizes = [];
  final List<String> _selectedColors = [];
  bool _isSaving = false;

  final List<Map<String, String>> _categories = const [
    {'id': 'cat_aothun', 'name': 'Áo Thun & Polo'},
    {'id': 'cat_aokhoac', 'name': 'Áo Khoác'},
    {'id': 'cat_quanjean', 'name': 'Quần Jean'},
    {'id': 'cat_phukien', 'name': 'Phụ Kiện'},
  ];

  final List<String> _availableSizes = const ['S', 'M', 'L', 'XL', 'XXL'];
  final List<String> _availableColors = const [
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
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _imageUrlController = TextEditingController(
      text: p != null && p.imageUrls.isNotEmpty ? p.imageUrls.first : '',
    );

    if (p != null) {
      if (_categories.any((c) => c['id'] == p.categoryId)) {
        _selectedCategoryId = p.categoryId;
      }
      _selectedSizes.addAll(p.sizes);
      _selectedColors.addAll(p.colors);
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
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
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

    final imageUrl = _imageUrlController.text.trim();
    final imageUrls = imageUrl.isNotEmpty
        ? [imageUrl]
        : [
            'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800',
          ];

    final productProvider = context.read<ProductProvider>();
    bool success = false;

    if (isEditMode) {
      final updatedProduct = widget.product!.copyWith(
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId,
        price: cleanPrice,
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        sizes: _selectedSizes,
        colors: _selectedColors,
      );
      success = await productProvider.updateProduct(updatedProduct);
    } else {
      final newProduct = ProductModel(
        id: '', // FirestoreService sẽ tự sinh id
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId,
        price: cleanPrice,
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        sizes: _selectedSizes,
        colors: _selectedColors,
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
            _buildSectionHeader('1. Thông tin cơ bản'),
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
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục sản phẩm *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat['id'],
                        child: Text(cat['name']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategoryId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Đơn giá bán (VNĐ) *',
                      hintText: 'VD: 250000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: 'VNĐ',
                    ),
                    validator: AppValidators.validatePrice,
                  ),
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
            _buildSectionHeader('2. Hình ảnh sản phẩm (Unsplash URL)'),
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
                      labelText: 'Đường dẫn ảnh Unsplash (URL) *',
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
                  const SizedBox(height: 14),
                  const Text(
                    'Xem trước hình ảnh (Preview):',
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

            // 3. KÍCH CỠ & MÀU SẮC BIẾN THỂ
            _buildSectionHeader('3. Kích cỡ & Màu sắc biến thể'),
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
                  const Text(
                    'Kích cỡ (Sizes) có sẵn *:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
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
                  const Text(
                    'Màu sắc (Colors) có sẵn *:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
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
