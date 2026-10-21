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
      ];

      testProducts = [
        // Sp 1: 189.000đ (< 200k), size S/M/L/XL, màu Trắng/Đen
        const ProductModel(
          id: 'prod_001',
          name: 'Áo Thun Cổ Tròn Basic',
          categoryId: 'cat_aothun',
          price: 189000,
          description: 'Áo thun 100% cotton thoáng mát',
          imageUrls: ['https://example.com/1.jpg'],
          sizes: ['S', 'M', 'L', 'XL'],
          colors: ['Trắng', 'Đen'],
          rating: 4.8,
        ),
        // Sp 2: 289.000đ (200k - 400k), size L/XL, màu Đen/Xanh navy
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
        ),
        // Sp 3: 499.000đ (> 400k), size M/L, màu Be/Xám
        const ProductModel(
          id: 'prod_003',
          name: 'Áo Khoác Bomber Chống Nước',
          categoryId: 'cat_aokhoac',
          price: 499000,
          description: 'Áo khoác gió cản gió và trượt nước',
          imageUrls: ['https://example.com/3.jpg'],
          sizes: ['M', 'L'],
          colors: ['Be', 'Xám'],
          rating: 4.6,
        ),
      ];

      final fakeService = FakeFirestoreService(
        mockCategoriesList: testCategories,
        mockProductsList: testProducts,
      );

      productProvider = ProductProvider(firestoreService: fakeService);
      // Đợi Future.wait trong loadData hoàn tất
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('Ban đầu nạp đầy đủ danh sách 3 sản phẩm và 0 bộ lọc', () {
      expect(productProvider.allProducts.length, 3);
      expect(productProvider.filteredProducts.length, 3);
      expect(productProvider.activeFiltersCount, 0);
    });

    test('Lọc theo danh mục: chỉ lấy sản phẩm thuộc cat_aokhoac', () {
      productProvider.selectCategory('cat_aokhoac');
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.name, contains('Bomber'));
    });

    test('Tìm kiếm từ khóa tức thì: tìm "polo" ra đúng 1 sản phẩm', () {
      productProvider.setSearchQuery('polo');
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.id, 'prod_002');
    });

    test('Lọc theo khoảng giá dưới 200k (< 200.000đ)', () {
      productProvider.setAdvancedFilters(priceRange: 'under_200k');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.price, 189000);
    });

    test('Lọc theo khoảng giá 200k - 400.000đ', () {
      productProvider.setAdvancedFilters(priceRange: '200k_400k');
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.price, 289000);
    });

    test('Lọc theo khoảng giá trên 400.000đ', () {
      productProvider.setAdvancedFilters(priceRange: 'above_400k');
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.price, 499000);
    });

    test('Lọc theo Kích cỡ: Size S chỉ có 1 sản phẩm Áo thun', () {
      productProvider.setAdvancedFilters(size: 'S');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.id, 'prod_001');
    });

    test('Lọc theo Màu sắc: Màu "Đen" có 2 sản phẩm', () {
      productProvider.setAdvancedFilters(color: 'Đen');
      expect(productProvider.activeFiltersCount, 1);
      expect(productProvider.filteredProducts.length, 2);
    });

    test('Lọc kết hợp đa điều kiện: Giá 200k_400k + Size XL + Màu Đen', () {
      productProvider.setAdvancedFilters(
        priceRange: '200k_400k',
        size: 'XL',
        color: 'Đen',
      );
      expect(productProvider.activeFiltersCount, 3);
      expect(productProvider.filteredProducts.length, 1);
      expect(productProvider.filteredProducts.first.name, contains('Polo'));
    });

    test('Reset bộ lọc khôi phục lại đủ 3 sản phẩm', () {
      productProvider.setAdvancedFilters(priceRange: 'under_200k', size: 'S');
      expect(productProvider.filteredProducts.length, 1);

      productProvider.resetFilters();
      expect(productProvider.activeFiltersCount, 0);
      expect(productProvider.filteredProducts.length, 3);
    });

    test('Sắp xếp giá tăng dần (price_asc)', () {
      productProvider.setSortBy('price_asc');
      final prices = productProvider.filteredProducts.map((p) => p.price).toList();
      expect(prices, [189000, 289000, 499000]);
    });

    test('Sắp xếp giá giảm dần (price_desc)', () {
      productProvider.setSortBy('price_desc');
      final prices = productProvider.filteredProducts.map((p) => p.price).toList();
      expect(prices, [499000, 289000, 189000]);
    });
  });
}
