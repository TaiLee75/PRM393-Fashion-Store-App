import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/screens/home/product_list_screen.dart';
import 'package:fashion_store_app/screens/home/product_detail_screen.dart';
import 'package:fashion_store_app/screens/cart/checkout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 1);

  final sampleProducts = [
    ProductModel(
      id: 'prod_1',
      name: 'Áo Thun Cotton Compact',
      categoryId: 'cat_aothun',
      price: 199000,
      originalPrice: 249000,
      description: 'Chất liệu 100% cotton chải kỹ mềm mịn.',
      imageUrls: const ['https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800'],
      sizes: const ['S', 'M', 'L'],
      colors: const ['Trắng', 'Đen'],
      stock: 25,
      variantStock: const {
        'S_Trắng': 10,
        'S_Đen': 0, // Hết hàng phân loại này
        'M_Trắng': 8,
        'M_Đen': 7,
      },
      soldCount: 150,
      rating: 4.8,
      reviews: [
        ReviewModel(
          userId: 'user_1',
          userName: 'Nguyễn Văn A',
          rating: 5.0,
          comment: 'Vải mềm mịn, chuẩn form!',
          createdAt: testDate,
          variantInfo: 'Phân loại: Size M, Màu Trắng',
          isVerifiedPurchase: true,
        ),
      ],
    ),
    const ProductModel(
      id: 'prod_2',
      name: 'Áo Khoác Gió Chống Nước',
      categoryId: 'cat_aokhoac',
      price: 349000,
      originalPrice: 499000,
      description: 'Chống thấm nước nhẹ và cản gió.',
      imageUrls: ['https://images.unsplash.com/photo-1548883354-7622d03aca27?w=800'],
      sizes: ['M', 'L', 'XL'],
      colors: ['Xanh Navy'],
      stock: 12,
      variantStock: {'M_Xanh Navy': 5, 'L_Xanh Navy': 7},
      soldCount: 80,
      rating: 4.6,
    ),
  ];

  Widget createTestWidget({
    required Widget child,
    required AuthProvider authProvider,
    required ProductProvider productProvider,
    required CartProvider cartProvider,
    OrderProvider? orderProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
        ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
        if (orderProvider != null)
          ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Kiểm thử Giao diện & Luồng Sản phẩm Khách hàng (Task 3.2)', () {
    late AuthProvider authProvider;
    late ProductProvider productProvider;
    late CartProvider cartProvider;

    setUp(() {
      authProvider = AuthProvider();
      productProvider = ProductProvider();
      cartProvider = CartProvider();
    });

    testWidgets('1. Khóa Bẫy 14: Khi allProducts rỗng và là Customer, KHÔNG hiển thị nút Seed Data', (tester) async {
      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        createdAt: testDate,
      ));
      productProvider.setMockProducts([]);

      await tester.pumpWidget(createTestWidget(
        child: const ProductListScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Phải hiện thông báo cho khách
      expect(find.text('Cửa hàng đang chuẩn bị sản phẩm mới'), findsOneWidget);
      expect(find.text('Tải lại trang'), findsOneWidget);
      // Tuyệt đối KHÔNG hiện nút nạp Seed Data mở Admin Tool
      expect(find.text('Mở Admin Tool & Nạp Seed Data'), findsNothing);
    });

    testWidgets('2. Khóa Bẫy 14: Khi allProducts rỗng và là Admin, hiển thị nút Nạp Seed Data', (tester) async {
      authProvider.setMockUser(UserModel(
        uid: 'admin_1',
        email: 'admin@test.com',
        fullName: 'Quản Trị Viên',
        role: 'admin',
        createdAt: testDate,
      ));
      productProvider.setMockProducts([]);

      await tester.pumpWidget(createTestWidget(
        child: const ProductListScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Chưa có dữ liệu sản phẩm trên Firestore'), findsOneWidget);
      expect(find.text('Mở Admin Tool & Nạp Seed Data'), findsOneWidget);
    });

    testWidgets('3. Khóa Bẫy 14: Khi tìm kiếm không có kết quả, hiện nút Xóa bộ lọc & Tìm lại', (tester) async {
      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        createdAt: testDate,
      ));
      productProvider.setMockProducts(sampleProducts);

      await tester.pumpWidget(createTestWidget(
        child: const ProductListScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Nhập từ khóa không tồn tại
      await tester.enterText(find.byType(TextField), 'từ khóa không có');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Không tìm thấy sản phẩm phù hợp'), findsOneWidget);
      expect(find.text('Xóa bộ lọc & Tìm lại'), findsOneWidget);
      expect(find.text('Mở Admin Tool & Nạp Seed Data'), findsNothing);

      // Bấm Xóa bộ lọc & Tìm lại
      await tester.tap(find.text('Xóa bộ lọc & Tìm lại'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(productProvider.searchQuery, isEmpty);
      expect(find.text('Áo Thun Cotton Compact'), findsOneWidget);
    });

    testWidgets('4. Chạm vào Banner Lifewear mở Modal Kho Voucher', (tester) async {
      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        createdAt: testDate,
      ));
      productProvider.setMockProducts(sampleProducts);

      await tester.pumpWidget(createTestWidget(
        child: const ProductListScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Nhấn vào Banner
      await tester.tap(find.textContaining('LIFEWEAR 2026'));
      await tester.pump(const Duration(milliseconds: 300));

      // Modal Voucher mở ra
      expect(find.text('KHO VOUCHER KHUYẾN MÃI'), findsOneWidget);
      expect(find.text('SALE10'), findsOneWidget);
      expect(find.text('FREESHIP'), findsOneWidget);
    });

    testWidgets('5. Thẻ sản phẩm hiển thị Badge % giảm giá, lượt bán và nút Wishlist', (tester) async {
      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        wishlistProductIds: ['prod_1'],
        createdAt: testDate,
      ));
      productProvider.setMockProducts(sampleProducts);

      await tester.pumpWidget(createTestWidget(
        child: const ProductListScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Badge giảm giá (-20% cho prod_1, -30% cho prod_2)
      expect(find.text('-20%'), findsOneWidget);
      expect(find.text('-30%'), findsOneWidget);
      // Lượt bán
      expect(find.text('Đã bán 150'), findsOneWidget);
      // Nút tim (prod_1 đang yêu thích nên có icon Icons.favorite)
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('6. Khóa Bẫy 9: Chi tiết sản phẩm hiển thị tồn kho SKU & kẹp số lượng khi đổi màu/size', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        createdAt: testDate,
      ));
      productProvider.setMockProducts(sampleProducts);

      await tester.pumpWidget(createTestWidget(
        child: const ProductDetailScreen(productId: 'prod_1'),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Mặc định chọn Size S, Màu Trắng (kho còn 10 sp)
      expect(find.textContaining('Kho còn: 10 sản phẩm (S - Trắng)'), findsOneWidget);
      expect(find.text('THÊM VÀO GIỎ'), findsOneWidget);
      expect(find.text('MUA NGAY'), findsOneWidget);

      // Chuyển sang Màu Đen (S - Đen có kho = 0)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đen'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Hết hàng phân loại này (S - Đen)'), findsOneWidget);
      expect(find.text('HẾT HÀNG PHÂN LOẠI NÀY'), findsOneWidget);
      expect(find.text('MUA NGAY'), findsNothing);
    });

    testWidgets('7. Khóa Bẫy 1: Nút MUA NGAY chuyển thẳng CheckoutScreen mà không thêm vào giỏ hàng', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        createdAt: testDate,
      ));
      productProvider.setMockProducts(sampleProducts);
      final orderProvider = OrderProvider();

      await tester.pumpWidget(createTestWidget(
        child: const ProductDetailScreen(productId: 'prod_1'),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
        orderProvider: orderProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Giỏ hàng ban đầu trống
      expect(cartProvider.items, isEmpty);

      // Bấm nút MUA NGAY
      await tester.tap(find.text('MUA NGAY'));
      await tester.pumpAndSettle();

      // Phải chuyển sang CheckoutScreen
      expect(find.byType(CheckoutScreen), findsOneWidget);
      // Giỏ hàng của người dùng trên CartProvider vẫn phải hoàn toàn TRỐNG (Khóa Bẫy 1)
      expect(cartProvider.items, isEmpty);
    });

    testWidgets('8. Trợ lý chọn size thông minh tính toán và cập nhật Size đề xuất', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        createdAt: testDate,
      ));
      productProvider.setMockProducts(sampleProducts);

      await tester.pumpWidget(createTestWidget(
        child: const ProductDetailScreen(productId: 'prod_1'),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Bấm vào Trợ lý chọn size thông minh
      await tester.tap(find.text('Trợ lý chọn size thông minh'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('TRỢ LÝ CHỌN SIZE THÔNG MINH'), findsOneWidget);
      expect(find.text('SIZE M'), findsOneWidget);

      // Bấm nút Chọn Size M & Lưu số đo
      final confirmBtn = find.textContaining('CHỌN SIZE M & LƯU SỐ ĐO');
      await tester.ensureVisible(confirmBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Modal đóng lại và sản phẩm hiện tại đã được chọn Size M
      expect(find.text('TRỢ LÝ CHỌN SIZE THÔNG MINH'), findsNothing);
      expect(find.textContaining('(M - Trắng)'), findsOneWidget);
    });

    testWidgets('9. Đánh giá sản phẩm hiển thị Badge Đã mua hàng', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      authProvider.setMockUser(UserModel(
        uid: 'cust_1',
        email: 'customer@test.com',
        fullName: 'Khách Hàng',
        role: 'customer',
        createdAt: testDate,
      ));
      productProvider.setMockProducts(sampleProducts);

      await tester.pumpWidget(createTestWidget(
        child: const ProductDetailScreen(productId: 'prod_1'),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra review của người mua
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Đã mua hàng'), findsOneWidget);
      expect(find.text('Phân loại: Size M, Màu Trắng'), findsOneWidget);
    });
  });
}
