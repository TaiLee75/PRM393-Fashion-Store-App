import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/branch_model.dart';
import 'package:fashion_store_app/models/category_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/chat_provider.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/screens/admin/admin_branch_management_screen.dart';
import 'package:fashion_store_app/screens/admin/admin_chat_inbox_screen.dart';
import 'package:fashion_store_app/screens/admin/admin_product_form_screen.dart';
import 'package:fashion_store_app/screens/admin/admin_product_list_screen.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

/// Fake FirestoreService phục vụ kiểm thử Task 4.3
class FakeFirestoreServiceForAdminManagement extends FirestoreService {
  final List<CategoryModel> categoriesDb;
  final List<ProductModel> productsDb;
  final List<BranchModel> branchesDb;

  FakeFirestoreServiceForAdminManagement({
    required this.categoriesDb,
    required this.productsDb,
    required this.branchesDb,
  });

  @override
  Future<List<CategoryModel>> getCategories() async => categoriesDb;

  @override
  Stream<List<CategoryModel>> streamCategories() => Stream.value(categoriesDb);

  @override
  Future<List<ProductModel>> getProducts({String? categoryId}) async =>
      productsDb;

  @override
  Stream<List<ProductModel>> streamProducts() => Stream.value(productsDb);

  @override
  Future<String> addCategory(CategoryModel category) async {
    final newId = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    final saved = category.copyWith(id: newId);
    categoriesDb.add(saved);
    return newId;
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    final idx = categoriesDb.indexWhere((c) => c.id == category.id);
    if (idx != -1) {
      categoriesDb[idx] = category;
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    categoriesDb.removeWhere((c) => c.id == categoryId);
  }

  @override
  Future<void> quickRestockProduct({
    required String productId,
    required int additionalStock,
    String? skuKey,
  }) async {
    // Trong Firestore thực tế ghi document, ProductProvider quản lý cập nhật RAM
  }

  @override
  Stream<List<BranchModel>> streamBranches() => Stream.value(branchesDb);

  @override
  Future<void> updateBranch(BranchModel branch) async {
    final idx = branchesDb.indexWhere((b) => b.id == branch.id);
    if (idx != -1) {
      branchesDb[idx] = branch;
    }
  }

  @override
  Future<void> deleteBranch(String branchId) async {
    branchesDb.removeWhere((b) => b.id == branchId);
  }

  @override
  Stream<List<Map<String, dynamic>>> streamAllChats() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestoreServiceForAdminManagement fakeService;
  late ProductProvider productProvider;
  late ChatProvider chatProvider;
  late AuthProvider authProvider;

  setUp(() {
    fakeService = FakeFirestoreServiceForAdminManagement(
      categoriesDb: [
        const CategoryModel(
          id: 'cat_aothun',
          name: 'Áo Thun & Polo',
          iconUrl: 'https://example.com/cat1.jpg',
        ),
        const CategoryModel(
          id: 'cat_aokhoac',
          name: 'Áo Khoác',
          iconUrl: 'https://example.com/cat2.jpg',
        ),
      ],
      productsDb: [
        ProductModel(
          id: 'p_01',
          name: 'Áo Polo Pique Cotton',
          categoryId: 'cat_aothun',
          price: 250000,
          originalPrice: 350000,
          description: 'Áo polo chất liệu cotton thoáng mát',
          imageUrls: const ['https://example.com/polo.jpg'],
          sizes: const ['M', 'L', 'XL'],
          colors: const ['Trắng', 'Đen'],
          stock: 50,
          variantStock: const {'M_Trắng': 20, 'L_Đen': 30},
          soldCount: 12,
          isActive: true,
          rating: 4.8,
          reviews: [
            ReviewModel(
              userName: 'Nam Nguyen',
              rating: 5.0,
              comment: 'Áo đẹp chuẩn form!',
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
        const ProductModel(
          id: 'p_02',
          name: 'Áo Khoác Dù Windbreaker',
          categoryId: 'cat_aokhoac',
          price: 499000,
          description: 'Áo khoác dù cản gió chống nước',
          imageUrls: ['https://example.com/jacket.jpg'],
          sizes: ['L', 'XL', 'FreeSize'],
          colors: ['Xanh Navy'],
          stock: 0,
          variantStock: {},
          soldCount: 5,
          isActive: false, // Ngừng bán
        ),
      ],
      branchesDb: [
        BranchModel(
          id: 'br_01',
          name: 'Lifewear Flagship Store',
          address: '123 Phố Tràng Tiền, Quận Hoàn Kiếm, Hà Nội',
          phone: '1900 1234',
          latitude: 21.0285,
          longitude: 105.8542,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    productProvider = ProductProvider(firestoreService: fakeService);
    productProvider.setMockCategories(fakeService.categoriesDb);
    productProvider.setMockProducts(fakeService.productsDb);

    chatProvider = ChatProvider(firestoreService: fakeService);
    authProvider = AuthProvider(firestoreService: fakeService);
    authProvider.setMockUser(
      UserModel(
        uid: 'admin_01',
        email: 'admin@lifewear.com',
        fullName: 'Shop Admin',
        role: 'admin',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  group('Task 4.3: Quản trị Kho, Danh mục, Chi nhánh & Chat Inbox', () {
    test('1. ProductProvider: Thêm, sửa, xóa danh mục an toàn có ràng buộc sản phẩm', () async {
      // Thêm danh mục mới
      final added = await productProvider.addCategory(
        const CategoryModel(
          id: '',
          name: 'Quần Khaki',
          iconUrl: 'https://example.com/khaki.jpg',
        ),
      );
      expect(added, isTrue);
      expect(productProvider.categories.any((c) => c.name == 'Quần Khaki'), isTrue);

      final khakiCat = productProvider.categories.firstWhere((c) => c.name == 'Quần Khaki');

      // Đổi tên danh mục
      final updated = await productProvider.updateCategory(
        khakiCat.copyWith(name: 'Quần Khaki Co Giãn'),
      );
      expect(updated, isTrue);
      expect(productProvider.categories.any((c) => c.name == 'Quần Khaki Co Giãn'), isTrue);

      // Xóa danh mục không có sản phẩm -> Thành công
      final deleted = await productProvider.deleteCategory(khakiCat.id);
      expect(deleted, isTrue);
      expect(productProvider.categories.any((c) => c.id == khakiCat.id), isFalse);

      // Thử xóa danh mục đang có sản phẩm kinh doanh -> Bị chặn
      final deleteBlocked = await productProvider.deleteCategory('cat_aothun');
      expect(deleteBlocked, isFalse);
      expect(productProvider.errorMessage, contains('Không thể xóa danh mục đang có sản phẩm'));
    });

    test('2. ProductProvider: Nhập kho nhanh SKU và cộng dồn tồn kho', () async {
      final success = await productProvider.quickRestockProduct(
        productId: 'p_01',
        additionalStock: 15,
        skuKey: 'M_Trắng',
      );

      expect(success, isTrue);
      final p = productProvider.allProducts.firstWhere((item) => item.id == 'p_01');
      expect(p.stock, equals(65)); // 50 + 15
      expect(p.variantStock['M_Trắng'], equals(35)); // 20 + 15
    });

    testWidgets('3. AdminProductListScreen: Hiển thị danh mục động, badge trạng thái và nút +Stock', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AdminProductListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề màn hình
      expect(find.text('QUẢN LÝ KHO SẢN PHẨM'), findsOneWidget);

      // Kiểm tra các chip danh mục động
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Áo Thun & Polo'), findsOneWidget);
      expect(find.text('Áo Khoác'), findsOneWidget);

      // Kiểm tra thông số Tồn kho & Đã bán
      expect(find.text('Tồn kho: 50 | Đã bán: 12'), findsOneWidget);
      expect(find.text('Đang bán'), findsOneWidget);
      expect(find.text('Ngừng bán'), findsOneWidget);

      // Kiểm tra nút +Stock
      expect(find.text('+Stock'), findsNWidgets(2));

      // Bấm vào nút +Stock của sản phẩm p_01
      await tester.tap(find.text('+Stock').first);
      await tester.pumpAndSettle();

      // Hộp thoại Nhập kho mở ra
      expect(find.textContaining('Nhập kho: Áo Polo Pique Cotton'), findsOneWidget);
      expect(find.text('Số lượng nhập thêm (+Stock) *'), findsOneWidget);
      expect(find.text('CẬP NHẬT KHO'), findsOneWidget);

      // Đóng dialog
      await tester.tap(find.text('HỦY'));
      await tester.pumpAndSettle();

      // Bấm nút Quản lý Danh mục trên AppBar
      await tester.tap(find.byTooltip('Quản lý Danh mục'));
      await tester.pumpAndSettle();

      // Sheet Quản lý danh mục mở ra
      expect(find.text('QUẢN LÝ DANH MỤC'), findsOneWidget);
      expect(find.text('Thêm danh mục mới:'), findsOneWidget);
    });

    testWidgets('4. AdminProductFormScreen: Khóa Bẫy 12 & Bẫy 17 (Dropdown an toàn & Giữ đánh giá)', (tester) async {
      // Test mở form với sản phẩm có categoryId không nằm trong danh mục (Khóa Bẫy 12)
      final orphanProduct = ProductModel(
        id: 'p_orphan',
        name: 'Sản phẩm thử nghiệm',
        categoryId: 'cat_unknown_deleted', // ID không tồn tại trong categoriesDb
        price: 199000,
        originalPrice: 299000,
        description: 'Mô tả thử nghiệm',
        imageUrls: const ['https://example.com/test.jpg'],
        sizes: const ['FreeSize'],
        colors: const ['Đen'],
        stock: 30,
        rating: 4.9,
        soldCount: 88,
        reviews: [
          ReviewModel(
            userName: 'Khách VIP',
            rating: 5.0,
            comment: 'Sản phẩm giữ lại review tuyệt vời',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
          ],
          child: MaterialApp(
            home: AdminProductFormScreen(product: orphanProduct),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Màn hình không bị văng AssertionError của DropdownButtonFormField (Khóa Bẫy 12)
      expect(find.text('CHỈNH SỬA SẢN PHẨM'), findsOneWidget);
      expect(find.text('Sản phẩm thử nghiệm'), findsOneWidget);

      // Hiển thị nhãn tính giảm giá tự động
      expect(find.textContaining('Đang áp dụng giảm giá'), findsOneWidget);

      // Cuộn xuống để xem Section 3 (Kích cỡ & Màu sắc)
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      // Hiển thị kích cỡ FreeSize
      expect(find.text('FreeSize'), findsOneWidget);
    });

    testWidgets('5. AdminBranchManagementScreen: Hiển thị chi nhánh & Sheet Chỉnh sửa (Khóa Bẫy 19)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminBranchManagementScreen(
            firestoreService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hiển thị tên và thông tin chi nhánh
      expect(find.text('Lifewear Flagship Store'), findsOneWidget);
      expect(find.text('123 Phố Tràng Tiền, Quận Hoàn Kiếm, Hà Nội'), findsOneWidget);

      // Nút Chỉnh sửa chi nhánh
      expect(find.byTooltip('Chỉnh sửa chi nhánh'), findsOneWidget);

      // Bấm vào nút Chỉnh sửa
      await tester.tap(find.byTooltip('Chỉnh sửa chi nhánh'));
      await tester.pumpAndSettle();

      // Sheet Chỉnh sửa chi nhánh mở lên với đầy đủ thông tin cũ
      expect(find.text('CHỈNH SỬA CHI NHÁNH'), findsOneWidget);
      expect(find.text('Lifewear Flagship Store'), findsWidgets);
      expect(find.text('Ghim vị trí trên Bản đồ OpenStreetMap'), findsOneWidget);
      expect(find.text('CẬP NHẬT CHI NHÁNH'), findsOneWidget);
    });

    testWidgets('6. AdminChatInboxScreen: Hiển thị Badge đỏ số tin chưa đọc của khách và tổng trên AppBar', (tester) async {
      // Mock dữ liệu phòng chat có unreadByAdmin
      chatProvider.setMockAdminChatRooms([
        {
          'customerId': 'cust_01',
          'userName': 'Tran Van A',
          'lastMessage': 'Shop ơi tư vấn size áo khoác này giúp em với',
          'unreadByAdmin': 3,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'customerId': 'cust_02',
          'userName': 'Le Thi B',
          'lastMessage': 'Đã nhận được hàng rồi shop nhé!',
          'unreadByAdmin': 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: AdminChatInboxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hiển thị tên khách hàng và tin nhắn
      expect(find.text('Tran Van A'), findsOneWidget);
      expect(find.text('Shop ơi tư vấn size áo khoác này giúp em với'), findsOneWidget);
      expect(find.text('Le Thi B'), findsOneWidget);

      // Badge đỏ số tin chưa đọc của phòng chat (3 tin)
      expect(find.text('3'), findsWidgets);
    });
  });
}
