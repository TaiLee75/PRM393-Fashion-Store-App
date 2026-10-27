import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/category_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

/// Lớp giả lập FirestoreService để kiểm thử ProductProvider độc lập không cần Firebase
class FakeFirestoreService extends FirestoreService {
  final List<CategoryModel> mockCategoriesList;
  final List<ProductModel> mockProductsList;

  FakeFirestoreService({
    required this.mockCategoriesList,
    required this.mockProductsList,
  });

  @override
  Future<List<CategoryModel>> getCategories() async => mockCategoriesList;

  @override
  Future<List<ProductModel>> getProducts({String? categoryId}) async => mockProductsList;

  @override
  Stream<List<ProductModel>> streamProducts() => Stream.value(mockProductsList);

  @override
  Stream<List<CategoryModel>> streamCategories() => Stream.value(mockCategoriesList);

  @override
  Future<String> addCategory(CategoryModel category) async {
    mockCategoriesList.add(category);
    return category.id.isEmpty ? 'cat_new_gen' : category.id;
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    final idx = mockCategoriesList.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      mockCategoriesList[idx] = category;
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    mockCategoriesList.removeWhere((c) => c.id == categoryId);
  }

  @override
  Future<void> quickRestockProduct({
    required String productId,
    required int additionalStock,
    String? skuKey,
  }) async {
    // Không làm gì, giả lập thành công
  }
}

void main() {
  group('Kiểm thử Đơn vị (Unit Test) cho ProductProvider & Bộ lọc Nâng cao:', () {
    late ProductProvider productProvider;
    late List<CategoryModel> testCategories;
    late List<ProductModel> testProducts;

    setUp(() async {
      testCategories = [
        const CategoryModel(id: 'cat_aothun', name: 'Áo Thun & Polo', iconUrl: ''),
        const CategoryModel(id: 'cat_aokhoac', name: 'Áo Khoác', iconUrl: ''),
        const CategoryModel(id: 'cat_quanjean', name: 'Quần Jean', iconUrl: ''),
        const CategoryModel(id: 'cat_phukien', name: 'Phụ kiện', iconUrl: ''),
      ];

      testProducts = [
        // Sp 1: 189.000đ (< 200k), size S/M/L/XL, màu Trắng/Đen, soldCount: 150, rating: 4.8
        const ProductModel(
          id: 'prod_001',
          name: 'Áo Thun Cổ Tròn Basic',
          categoryId: 'cat_aothun',
          price: 189000,
          originalPrice: 220000, // Đang giảm giá
          description: 'Áo thun 100% cotton thoáng mát',
          imageUrls: ['https://example.com/1.jpg'],
          sizes: ['S', 'M', 'L', 'XL'],
          colors: ['Trắng', 'Đen'],
          rating: 4.8,
          soldCount: 150,
          stock: 50,
          isActive: true,
        ),
        // Sp 2: 289.000đ (200k - 400k), size L/XL, màu Đen/Xanh navy, soldCount: 300, rating: 4.9
        const ProductModel(
          id: 'prod_002',
          name: 'Áo Polo Pique Nam',
          categoryId: 'cat_aothun',
          price: 289000,
          description: 'Áo polo form regular chỉn chu',
          imageUrls: ['https://example.com/2.jpg'],
          sizes: ['L', 'XL'],
          colors: ['Đen', 'Xanh navy'],
          rating: 4.9,
          soldCount: 300,
          stock: 80,
          isActive: true,
        ),
        // Sp 3: 499.000đ (> 400k), size M/L, màu Be/Xám, soldCount: 80, rating: 4.6
        const ProductModel(
          id: 'prod_003',
          name: 'Áo Khoác Bomber Chống Nước',
          categoryId: 'cat_aokhoac',
          price: 499000,
          originalPrice: 599000, // Đang giảm giá
          description: 'Áo khoác gió cản gió và trượt nước',
          imageUrls: ['https://example.com/3.jpg'],
          sizes: ['M', 'L'],
          colors: ['Be', 'Xám'],
          rating: 4.6,
          soldCount: 80,
          stock: 20,
          isActive: true,
        ),
        // Sp 4: Ngừng kinh doanh (isActive == false)
        const ProductModel(
          id: 'prod_004_inactive',
          name: 'Sản phẩm ngưng bán',
          categoryId: 'cat_quanjean',
          price: 399000,
          description: 'Mẫu cũ',
          imageUrls: ['https://example.com/4.jpg'],
          sizes: ['M'],
          colors: ['Xanh jean'],
          rating: 4.0,
          soldCount: 10,
          stock: 0,
          isActive: false,
        ),
      ];

      final fakeService = FakeFirestoreService(
        mockCategoriesList: List.from(testCategories),
        mockProductsList: List.from(testProducts),
      );

      productProvider = ProductProvider(firestoreService: fakeService);
      // Đợi Future.wait trong loadData hoàn tất
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('1. Ban đầu nạp đầy đủ 4 sản phẩm trên allProducts và 3 sản phẩm active trên filteredProducts', () {
      expect(productProvider.allProducts.length, 4); // Cả active lẫn inactive cho Admin
      expect(productProvider.filteredProducts.length, 3); // Chỉ active cho Khách (Khóa Bẫy 14)
      expect(productProvider.filteredProducts.any((p) => !p.isActive), isFalse);
      expect(productProvider.activeFiltersCount, 0);
    });

    test('2. availableSizes trả về đầy đủ kèm FreeSize (Khóa Bẫy 12)', () {
      expect(productProvider.availableSizes.contains('FreeSize'), isTrue);
      expect(productProvider.availableSizes, ['S', 'M', 'L', 'XL', 'FreeSize']);
    });

    test('3. Lọc theo danh mục: chỉ lấy sản phẩm active thuộc cat_aokhoac', () {
      productProvider.selectCategory('cat_aokhoac');
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.name, contains('Bomber'));
    });

    test('4. Tìm kiếm từ khóa tức thì: tìm "polo" ra đúng 1 sản phẩm', () {
      productProvider.setSearchQuery('polo');
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.id, 'prod_002');
    });

    test('5. Lọc theo khoảng giá dưới 200k (< 200.000đ)', () {
      productProvider.setAdvancedFilters(priceRange: 'under_200k');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.price, 189000);
    });

    test('6. Lọc theo khoảng giá 200k - 400.000đ', () {
      productProvider.setAdvancedFilters(priceRange: '200k_400k');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.price, 289000);
    });

    test('7. Lọc theo khoảng giá trên 400.000đ', () {
      productProvider.setAdvancedFilters(priceRange: 'above_400k');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.price, 499000);
    });

    test('8. Lọc theo Kích cỡ: Size S chỉ có 1 sản phẩm Áo thun', () {
      productProvider.setAdvancedFilters(size: 'S');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.id, 'prod_001');
    });

    test('9. Lọc theo Màu sắc: Màu "Đen" có 2 sản phẩm', () {
      productProvider.setAdvancedFilters(color: 'Đen');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 2);
    });

    test('10. Lọc kết hợp đa điều kiện: Giá 200k_400k + Size XL + Màu Đen', () {
      productProvider.setAdvancedFilters(
        priceRange: '200k_400k',
        size: 'XL',
        color: 'Đen',
      );
      expect(productProvider.activeFiltersCount, 3);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.name, contains('Polo'));
    });

    test('11. Lọc sản phẩm đang giảm giá (on_sale)', () {
      productProvider.setOnSaleOnly(true);
      expect(productProvider.activeFiltersCount, 1);
      // prod_001 (189k < 220k) và prod_003 (499k < 599k)
      expect(productProvider.filteredProducts.length, 2);
      expect(productProvider.filteredProducts.every((p) => p.originalPrice != null && p.originalPrice! > p.price), isTrue);
    });

    test('12. Sắp xếp popular ưu tiên theo soldCount giảm dần kết hợp rating', () {
      productProvider.setSortBy('popular');
      // Thứ tự theo soldCount: prod_002 (300) -> prod_001 (150) -> prod_003 (80)
      final sortedIds = productProvider.filteredProducts.map((p) => p.id).toList();
      expect(sortedIds, ['prod_002', 'prod_001', 'prod_003']);
    });

    test('13. Sắp xếp giá tăng dần (price_asc) & giảm dần (price_desc)', () {
      productProvider.setSortBy('price_asc');
      final ascPrices = productProvider.filteredProducts.map((p) => p.price).toList();
      expect(ascPrices, [189000, 289000, 499000]);

      productProvider.setSortBy('price_desc');
      final descPrices = productProvider.filteredProducts.map((p) => p.price).toList();
      expect(descPrices, [499000, 289000, 189000]);
    });

    test('14. Reset bộ lọc xóa sạch cả từ khóa tìm kiếm và các tiêu chí (Khóa Bẫy 14)', () {
      productProvider.setSearchQuery('polo');
      productProvider.selectCategory('cat_aothun');
      productProvider.setAdvancedFilters(priceRange: '200k_400k', size: 'XL', color: 'Đen', onSaleOnly: true);
      expect(productProvider.filteredProducts.length, 0); // Không có cái nào thỏa mãn tất cả

      productProvider.resetFilters();
      expect(productProvider.searchQuery, isEmpty);
      expect(productProvider.selectedCategoryId, 'all');
      expect(productProvider.selectedPriceRange, 'all');
      expect(productProvider.selectedSize, isNull);
      expect(productProvider.selectedColor, isNull);
      expect(productProvider.isOnSaleOnly, isFalse);
      expect(productProvider.activeFiltersCount, 0);
      expect(productProvider.filteredProducts.length, 3); // Khôi phục lại 3 món active
    });

    test('15. Quản trị Danh mục (CRUD Category Management)', () async {
      // 1. Thêm danh mục mới
      const newCat = CategoryModel(id: 'cat_test_new', name: 'Đồ Thể Thao', iconUrl: '');
      final okAdd = await productProvider.addCategory(newCat);
      expect(okAdd, isTrue);
      expect(productProvider.categories.any((c) => c.id == 'cat_test_new'), isTrue);

      // 2. Sửa danh mục
      const updatedCat = CategoryModel(id: 'cat_test_new', name: 'Đồ Thể Thao Pro', iconUrl: '');
      final okUpdate = await productProvider.updateCategory(updatedCat);
      expect(okUpdate, isTrue);
      expect(productProvider.categories.firstWhere((c) => c.id == 'cat_test_new').name, 'Đồ Thể Thao Pro');

      // 3. Chặn xóa danh mục đang có sản phẩm kinh doanh (cat_aothun)
      final okDeleteFail = await productProvider.deleteCategory('cat_aothun');
      expect(okDeleteFail, isFalse);
      expect(productProvider.errorMessage, contains('Không thể xóa danh mục đang có sản phẩm'));

      // 4. Xóa danh mục rỗng (cat_test_new) thành công
      final okDeleteSuccess = await productProvider.deleteCategory('cat_test_new');
      expect(okDeleteSuccess, isTrue);
      expect(productProvider.categories.any((c) => c.id == 'cat_test_new'), isFalse);
    });

    test('16. Nhập kho nhanh SKU (quickRestockProduct)', () async {
      final okRestock = await productProvider.quickRestockProduct(
        productId: 'prod_001',
        additionalStock: 25,
        skuKey: 'S_Trắng',
      );
      expect(okRestock, isTrue);
      final prod1 = productProvider.allProducts.firstWhere((p) => p.id == 'prod_001');
      expect(prod1.stock, 75); // 50 + 25 = 75
      expect(prod1.variantStock['S_Trắng'], 25);
    });

    test('17. Tra cứu findById & getCategoryName an toàn', () {
      final found = productProvider.findById('prod_001');
      expect(found, isNotNull);
      expect(found!.name, contains('Áo Thun'));

      final notFound = productProvider.findById('prod_khong_ton_tai');
      expect(notFound, isNull);

      expect(productProvider.getCategoryName('cat_aothun'), 'Áo Thun & Polo');
      expect(productProvider.getCategoryName('all'), 'Tất cả sản phẩm');
      expect(productProvider.getCategoryName('cat_la'), 'Thời trang');
    });

    test('18. Chặn nhập kho số lượng <= 0 (quickRestockProduct validation)', () async {
      final fail = await productProvider.quickRestockProduct(
        productId: 'prod_001',
        additionalStock: -5,
      );
      expect(fail, isFalse);
      expect(productProvider.errorMessage, contains('Số lượng nhập kho phải lớn hơn 0'));
    });

    test('19. ProductProvider.availableSizes chứa đầy đủ các size chuẩn bao gồm FreeSize (Khóa Bẫy 12)', () {
      expect(productProvider.availableSizes, containsAll(['S', 'M', 'L', 'XL', 'FreeSize']));
    });

    test('20. Phân bổ tồn kho biến thể SKU khi nhập kho chung (skuKey == null)', () async {
      // Thiết lập sản phẩm có sẵn 2 SKU: S_Đen: 10, M_Đen: 10
      const multiVariantProduct = ProductModel(
        id: 'prod_multi_var',
        name: 'Áo Thun Multi Variant',
        categoryId: 'cat_aothun',
        price: 200000,
        description: 'Mô tả test',
        imageUrls: ['https://example.com/test.jpg'],
        sizes: ['S', 'M'],
        colors: ['Đen'],
        stock: 20,
        variantStock: {'S_Đen': 10, 'M_Đen': 10},
        isActive: true,
      );
      productProvider.setMockProducts([multiVariantProduct]);

      // Nhập thêm 15 cái vào kho chung (skuKey == null)
      // 15 chia cho 2 SKU: mỗi SKU +7, dư 1 chia cho SKU đầu tiên -> S_Đen +8 = 18, M_Đen +7 = 17
      final ok = await productProvider.quickRestockProduct(
        productId: 'prod_multi_var',
        additionalStock: 15,
        skuKey: null,
      );
      expect(ok, isTrue);

      final updated = productProvider.findById('prod_multi_var')!;
      expect(updated.stock, 35); // 20 + 15 = 35
      expect(updated.variantStock['S_Đen'], 18);
      expect(updated.variantStock['M_Đen'], 17);
    });
  });
}
