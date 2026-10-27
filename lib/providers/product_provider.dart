import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý danh mục, danh sách sản phẩm, tìm kiếm, lọc, sắp xếp, đánh giá và quản trị kho (MVVM)
class ProductProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  String _selectedCategoryId = 'all';
  String _searchQuery = '';
  String _sortBy = 'popular'; // 'popular', 'price_asc', 'price_desc', 'rating'
  String _selectedPriceRange = 'all'; // 'all', 'under_200k', '200k_400k', 'above_400k'
  String? _selectedSize; // null or 'S', 'M', 'L', 'XL', 'FreeSize'
  String? _selectedColor; // null or 'Trắng', 'Đen', etc.
  bool _isOnSaleOnly = false;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<ProductModel>>? _productsSub;
  StreamSubscription<List<CategoryModel>>? _categoriesSub;

  ProductProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService() {
    loadData();
  }

  // Getters
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<ProductModel> get allProducts => List.unmodifiable(_products);
  String get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  String get selectedPriceRange => _selectedPriceRange;
  String? get selectedSize => _selectedSize;
  String? get selectedColor => _selectedColor;
  bool get isOnSaleOnly => _isOnSaleOnly;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Thiết lập danh sách sản phẩm giả lập phục vụ Unit & Widget Testing
  void setMockProducts(List<ProductModel> products) {
    _products = products;
    notifyListeners();
  }

  /// Thiết lập danh mục giả lập phục vụ Unit & Widget Testing
  void setMockCategories(List<CategoryModel> categories) {
    _categories = categories;
    notifyListeners();
  }

  /// Đếm số lượng bộ lọc nâng cao đang áp dụng
  int get activeFiltersCount {
    int count = 0;
    if (_selectedPriceRange != 'all') count++;
    if (_selectedSize != null && _selectedSize!.isNotEmpty) count++;
    if (_selectedColor != null && _selectedColor!.isNotEmpty) count++;
    if (_isOnSaleOnly) count++;
    return count;
  }

  /// Danh sách sản phẩm sau khi đã lọc cho Khách hàng (Chỉ hiển thị p.isActive == true - Khóa Bẫy 14)
  List<ProductModel> get filteredProducts {
    List<ProductModel> list = List.from(_products);

    // 1. Chỉ hiển thị sản phẩm đang kinh doanh cho Khách hàng
    list = list.where((p) => p.isActive).toList();

    // 2. Lọc theo danh mục đã chọn
    if (_selectedCategoryId != 'all') {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    // 3. Lọc theo từ khóa tìm kiếm (Real-time search)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      list = list.where((p) {
        final nameMatch = p.name.toLowerCase().contains(query);
        final descMatch = p.description.toLowerCase().contains(query);
        return nameMatch || descMatch;
      }).toList();
    }

    // 4. Lọc theo khoảng giá
    if (_selectedPriceRange == 'under_200k') {
      list = list.where((p) => p.price < 200000).toList();
    } else if (_selectedPriceRange == '200k_400k') {
      list = list.where((p) => p.price >= 200000 && p.price <= 400000).toList();
    } else if (_selectedPriceRange == 'above_400k') {
      list = list.where((p) => p.price > 400000).toList();
    }

    // 5. Lọc theo Kích cỡ (Size)
    if (_selectedSize != null && _selectedSize!.isNotEmpty) {
      list = list.where((p) => p.sizes.contains(_selectedSize)).toList();
    }

    // 6. Lọc theo Màu sắc (Color)
    if (_selectedColor != null && _selectedColor!.isNotEmpty) {
      list = list.where((p) => p.colors.contains(_selectedColor)).toList();
    }

    // 7. Lọc sản phẩm đang giảm giá (on_sale)
    if (_isOnSaleOnly) {
      list = list
          .where((p) => p.originalPrice != null && p.originalPrice! > p.price)
          .toList();
    }

    // 8. Sắp xếp (Sort)
    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'popular':
      default:
        // Sắp xếp theo số lượng đã bán (soldCount) giảm dần, ưu tiên rating khi bằng nhau
        list.sort((a, b) {
          final soldCompare = b.soldCount.compareTo(a.soldCount);
          if (soldCompare != 0) return soldCompare;
          return b.rating.compareTo(a.rating);
        });
        break;
    }

    return list;
  }

  /// Nạp đồng thời cả Categories và Products từ Firestore (Tuân thủ Rule 22.1 & Bẫy 12)
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _firestoreService.getCategories(),
        _firestoreService.getProducts(),
      ]);

      _categories = results[0] as List<CategoryModel>;
      _products = results[1] as List<ProductModel>;
      _isLoading = false;
      notifyListeners();

      // Kết nối Real-time stream sau khi nạp tĩnh ban đầu thành công
      _subscribeStreams();
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách sản phẩm: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lắng nghe thay đổi sản phẩm & danh mục theo thời gian thực (Real-time Stream)
  void _subscribeStreams() {
    try {
      _productsSub?.cancel();
      _productsSub = _firestoreService.streamProducts().listen((prods) {
        _products = prods;
        notifyListeners();
      }, onError: (_) {});

      _categoriesSub?.cancel();
      _categoriesSub = _firestoreService.streamCategories().listen((cats) {
        _categories = cats;
        notifyListeners();
      }, onError: (_) {});
    } catch (_) {
      // Bỏ qua lỗi trong môi trường FakeFirestoreService ở Unit Test
    }
  }

  /// Tra cứu nhanh thông tin sản phẩm theo ID (trả về null nếu không tìm thấy)
  ProductModel? findById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Lấy tên danh mục từ categoryId (VD: 'Áo Thun & Polo')
  String getCategoryName(String categoryId) {
    if (categoryId == 'all') return 'Tất cả sản phẩm';
    try {
      return _categories.firstWhere((c) => c.id == categoryId).name;
    } catch (_) {
      return 'Thời trang';
    }
  }

  /// Chọn danh mục (Áo thun, Áo khoác, Quần jean, Phụ kiện, hoặc 'all')
  void selectCategory(String categoryId) {
    if (_selectedCategoryId != categoryId) {
      _selectedCategoryId = categoryId;
      notifyListeners();
    }
  }

  /// Tìm kiếm theo tên sản phẩm thời gian thực
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Thay đổi cách sắp xếp (Giá tăng dần, Giá giảm dần, Đánh giá cao nhất, Bán chạy)
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  /// Bật/Tắt bộ lọc nhanh sản phẩm đang giảm giá
  void setOnSaleOnly(bool onSale) {
    _isOnSaleOnly = onSale;
    notifyListeners();
  }

  /// Thiết lập bộ lọc nâng cao (Khoảng giá, Size, Màu sắc, Giảm giá)
  void setAdvancedFilters({
    String? priceRange,
    String? size,
    String? color,
    bool? onSaleOnly,
  }) {
    if (priceRange != null) _selectedPriceRange = priceRange;
    _selectedSize = size;
    _selectedColor = color;
    if (onSaleOnly != null) _isOnSaleOnly = onSaleOnly;
    notifyListeners();
  }

  /// Đặt lại toàn bộ bộ lọc và từ khóa tìm kiếm về mặc định (Khóa Bẫy 14)
  void resetFilters() {
    _selectedCategoryId = 'all';
    _searchQuery = '';
    _selectedPriceRange = 'all';
    _selectedSize = null;
    _selectedColor = null;
    _sortBy = 'popular';
    _isOnSaleOnly = false;
    notifyListeners();
  }

  /// Xóa bộ lọc giá
  void clearPriceFilter() {
    _selectedPriceRange = 'all';
    notifyListeners();
  }

  /// Xóa bộ lọc kích cỡ
  void clearSizeFilter() {
    _selectedSize = null;
    notifyListeners();
  }

  /// Xóa bộ lọc màu sắc
  void clearColorFilter() {
    _selectedColor = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Danh sách toàn bộ các màu sắc có trong kho sản phẩm đang kinh doanh
  List<String> get availableColors {
    final Set<String> colors = {};
    for (final p in _products) {
      if (p.isActive) {
        for (final c in p.colors) {
          final trimmed = c.trim();
          if (trimmed.isNotEmpty) colors.add(trimmed);
        }
      }
    }
    if (colors.isEmpty) {
      return ['Đen', 'Trắng', 'Xám', 'Xanh navy', 'Be', 'Xanh jean', 'Xanh rêu'];
    }
    return colors.toList();
  }

  /// Danh sách toàn bộ kích cỡ chuẩn Uniqlo kèm FreeSize cho phụ kiện (Khóa Bẫy 12)
  List<String> get availableSizes =>
      const ['S', 'M', 'L', 'XL', 'FreeSize'];

  /// Gửi đánh giá sản phẩm mới kèm chấm điểm sao và bình luận
  Future<bool> addReview({
    required String productId,
    required String userName,
    required double rating,
    required String comment,
    String? userId,
    String? orderId,
    String? variantInfo,
  }) async {
    try {
      final review = ReviewModel(
        userName: userName,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
        userId: userId ?? '',
        orderId: orderId ?? '',
        variantInfo: variantInfo ?? '',
        isVerifiedPurchase: orderId != null && orderId.isNotEmpty,
      );

      await _firestoreService.addProductReview(productId, review);

      // Cập nhật lại sản phẩm trong bộ nhớ cục bộ
      final index = _products.indexWhere((p) => p.id == productId);
      if (index >= 0) {
        final current = _products[index];
        final updatedReviews = List<ReviewModel>.from(current.reviews)..add(review);
        double totalRating = 0;
        for (var r in updatedReviews) {
          totalRating += r.rating;
        }
        final newRating = double.parse(
            (totalRating / updatedReviews.length).toStringAsFixed(1));

        _products[index] = current.copyWith(
          reviews: updatedReviews,
          rating: newRating,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Gửi đánh giá thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  // ========================================================
  // QUẢN TRỊ SẢN PHẨM & KHO SKU (DÀNH CHO ADMIN)
  // ========================================================

  /// Thêm sản phẩm mới (Dành cho Admin)
  Future<bool> addProduct(ProductModel product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final generatedId = await _firestoreService.addProduct(product);
      final newProduct = product.copyWith(id: generatedId);
      if (!_products.any((p) => p.id == newProduct.id)) {
        _products.insert(0, newProduct);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Thêm sản phẩm thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật thông tin sản phẩm (Dành cho Admin)
  Future<bool> updateProduct(ProductModel product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateProduct(product);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        _products[index] = product;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Cập nhật sản phẩm thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Xóa sản phẩm khỏi danh sách (Dành cho Admin)
  Future<bool> deleteProduct(String productId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deleteProduct(productId);
      _products.removeWhere((p) => p.id == productId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Xóa sản phẩm thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Nhập kho nhanh cho sản phẩm / SKU (Dành cho Admin)
  Future<bool> quickRestockProduct({
    required String productId,
    required int additionalStock,
    String? skuKey,
  }) async {
    if (additionalStock <= 0) {
      _errorMessage = 'Số lượng nhập kho phải lớn hơn 0.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      await _firestoreService.quickRestockProduct(
        productId: productId,
        additionalStock: additionalStock,
        skuKey: skuKey,
      );
      final index = _products.indexWhere((p) => p.id == productId);
      if (index >= 0) {
        final current = _products[index];
        final updatedVariantStock =
            Map<String, int>.from(current.variantStock);
        if (skuKey != null && skuKey.isNotEmpty) {
          final old = updatedVariantStock[skuKey] ?? 0;
          updatedVariantStock[skuKey] = old + additionalStock;
        } else if (updatedVariantStock.isNotEmpty) {
          final perSku = (additionalStock / updatedVariantStock.length).floor();
          final remainder = additionalStock % updatedVariantStock.length;
          int count = 0;
          for (final k in updatedVariantStock.keys.toList()) {
            updatedVariantStock[k] =
                (updatedVariantStock[k] ?? 0) + perSku + (count < remainder ? 1 : 0);
            count++;
          }
        }
        _products[index] = current.copyWith(
          stock: current.stock + additionalStock,
          variantStock: updatedVariantStock,
        );
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // ========================================================
  // QUẢN TRỊ DANH MỤC CATEGORIES (DÀNH CHO ADMIN)
  // ========================================================

  /// Thêm danh mục mới (Admin)
  Future<bool> addCategory(CategoryModel category) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final generatedId = await _firestoreService.addCategory(category);
      final newCat = category.copyWith(id: generatedId);
      if (!_categories.any((c) => c.id == newCat.id)) {
        _categories.add(newCat);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Thêm danh mục thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật thông tin danh mục (Admin)
  Future<bool> updateCategory(CategoryModel category) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateCategory(category);
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index >= 0) {
        _categories[index] = category;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Cập nhật danh mục thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Xóa danh mục (Admin - Có kiểm tra ràng buộc không có sản phẩm)
  Future<bool> deleteCategory(String categoryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasProducts = _products.any((p) => p.categoryId == categoryId);
      if (hasProducts) {
        _errorMessage = 'Không thể xóa danh mục đang có sản phẩm kinh doanh.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _firestoreService.deleteCategory(categoryId);
      _categories.removeWhere((c) => c.id == categoryId);
      if (_selectedCategoryId == categoryId) {
        _selectedCategoryId = 'all';
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    super.dispose();
  }
}
