import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý danh mục, danh sách sản phẩm, tìm kiếm, lọc và đánh giá
class ProductProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  String _selectedCategoryId = 'all';
  String _searchQuery = '';
  String _sortBy = 'popular'; // 'popular', 'price_asc', 'price_desc', 'rating'
  String _selectedPriceRange = 'all'; // 'all', 'under_200k', '200k_400k', 'above_400k'
  String? _selectedSize; // null or 'S', 'M', 'L', 'XL'
  String? _selectedColor; // null or 'Trắng', 'Đen', etc.
  bool _isLoading = false;
  String? _errorMessage;

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
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Đếm số lượng bộ lọc nâng cao đang áp dụng
  int get activeFiltersCount {
    int count = 0;
    if (_selectedPriceRange != 'all') count++;
    if (_selectedSize != null && _selectedSize!.isNotEmpty) count++;
    if (_selectedColor != null && _selectedColor!.isNotEmpty) count++;
    return count;
  }

  /// Danh sách sản phẩm sau khi đã lọc theo danh mục, từ khóa, bộ lọc nâng cao và sắp xếp
  List<ProductModel> get filteredProducts {
    List<ProductModel> list = List.from(_products);

    // 1. Lọc theo danh mục đã chọn
    if (_selectedCategoryId != 'all') {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    // 2. Lọc theo từ khóa tìm kiếm (Real-time search)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      list = list.where((p) {
        final nameMatch = p.name.toLowerCase().contains(query);
        final descMatch = p.description.toLowerCase().contains(query);
        return nameMatch || descMatch;
      }).toList();
    }

    // 3. Lọc theo khoảng giá
    if (_selectedPriceRange == 'under_200k') {
      list = list.where((p) => p.price < 200000).toList();
    } else if (_selectedPriceRange == '200k_400k') {
      list = list.where((p) => p.price >= 200000 && p.price <= 400000).toList();
    } else if (_selectedPriceRange == 'above_400k') {
      list = list.where((p) => p.price > 400000).toList();
    }

    // 4. Lọc theo Kích cỡ (Size)
    if (_selectedSize != null && _selectedSize!.isNotEmpty) {
      list = list.where((p) => p.sizes.contains(_selectedSize)).toList();
    }

    // 5. Lọc theo Màu sắc (Color)
    if (_selectedColor != null && _selectedColor!.isNotEmpty) {
      list = list.where((p) => p.colors.contains(_selectedColor)).toList();
    }

    // 6. Sắp xếp (Sort)
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
        // Giữ nguyên thứ tự danh sách hoặc ưu tiên rating cao
        break;
    }

    return list;
  }

  /// Nạp đồng thời cả Categories và Products từ Firestore
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
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách sản phẩm: $e';
      _isLoading = false;
      notifyListeners();
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

  /// Thay đổi cách sắp xếp (Giá tăng dần, Giá giảm dần, Đánh giá cao nhất)
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  /// Thiết lập bộ lọc nâng cao (Khoảng giá, Size, Màu sắc)
  void setAdvancedFilters({
    String? priceRange,
    String? size,
    String? color,
  }) {
    if (priceRange != null) _selectedPriceRange = priceRange;
    _selectedSize = size;
    _selectedColor = color;
    notifyListeners();
  }

  /// Đặt lại toàn bộ bộ lọc nâng cao về mặc định
  void resetFilters() {
    _selectedPriceRange = 'all';
    _selectedSize = null;
    _selectedColor = null;
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

  /// Danh sách toàn bộ các màu sắc có trong kho sản phẩm
  List<String> get availableColors {
    final Set<String> colors = {};
    for (final p in _products) {
      colors.addAll(p.colors);
    }
    if (colors.isEmpty) {
      return ['Đen', 'Trắng', 'Xám', 'Xanh navy', 'Be', 'Xanh jean', 'Xanh rêu'];
    }
    return colors.toList();
  }

  /// Danh sách toàn bộ kích cỡ chuẩn Uniqlo
  List<String> get availableSizes => const ['S', 'M', 'L', 'XL'];

  /// Gửi đánh giá sản phẩm mới kèm chấm điểm sao và bình luận
  Future<bool> addReview({
    required String productId,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    try {
      final review = ReviewModel(
        userName: userName,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
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

  /// Thêm sản phẩm mới (Dành cho Admin)
  Future<bool> addProduct(ProductModel product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final generatedId = await _firestoreService.addProduct(product);
      final newProduct = product.copyWith(id: generatedId);
      _products.insert(0, newProduct);
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
}
