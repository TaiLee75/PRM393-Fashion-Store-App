import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/screens/home/product_detail_screen.dart';
import 'package:fashion_store_app/screens/profile/wishlist_screen.dart';

void main() {
  group('Kiểm thử Giao diện WishlistScreen (Task 3.6)', () {
    testWidgets('Wishlist trống hiển thị thông báo và nút Khám phá sản phẩm',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final productProvider = ProductProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
          ],
          child: const MaterialApp(
            home: WishlistScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DANH SÁCH YÊU THÍCH (0)'), findsOneWidget);
      expect(find.text('Chưa có sản phẩm yêu thích nào'), findsOneWidget);
      expect(find.text('KHÁM PHÁ SẢN PHẨM'), findsOneWidget);
    });

    testWidgets('Wishlist có sản phẩm hiển thị thẻ sản phẩm và nút thả tim',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final productProvider = ProductProvider();
      final cartProvider = CartProvider();

      const testProdId = 'prod_wish_1';
      const testProduct = ProductModel(
        id: testProdId,
        name: 'Áo Thun Trơn Lifewear Premium',
        categoryId: 'cat_aothun',
        price: 249000,
        originalPrice: 299000,
        description: 'Chất liệu 100% cotton cao cấp thoáng mát',
        imageUrls: ['https://example.com/aothun.jpg'],
        sizes: ['S', 'M', 'L', 'XL'],
        colors: ['Trắng', 'Đen'],
        stock: 50,
      );

      productProvider.setMockProducts([testProduct]);

      final user = UserModel(
        uid: 'user_1',
        email: 'customer@example.com',
        fullName: 'Nguyễn Văn A',
        wishlistProductIds: [testProdId],
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
          ],
          child: const MaterialApp(
            home: WishlistScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DANH SÁCH YÊU THÍCH (1)'), findsOneWidget);
      expect(find.text('Áo Thun Trơn Lifewear Premium'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Chạm vào thẻ sản phẩm để mở ProductDetailScreen
      await tester.tap(find.text('Áo Thun Trơn Lifewear Premium'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ProductDetailScreen), findsOneWidget);
    });
  });
}
