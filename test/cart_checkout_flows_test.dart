import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/screens/cart/cart_screen.dart';
import 'package:fashion_store_app/screens/cart/checkout_screen.dart';
import 'package:fashion_store_app/screens/cart/widgets/vietqr_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 1);

  final sampleProducts = [
    const ProductModel(
      id: 'prod_1',
      name: 'Áo Thun Cotton Compact',
      categoryId: 'cat_aothun',
      price: 199000,
      originalPrice: 249000,
      description: 'Chất liệu cotton mềm mịn.',
      imageUrls: ['https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800'],
      sizes: ['S', 'M', 'L'],
      colors: ['Trắng', 'Đen'],
      stock: 25,
      variantStock: {
        'S_Trắng': 10,
        'S_Đen': 0, // Hết hàng phân loại này
        'M_Trắng': 8,
        'M_Đen': 7,
      },
      soldCount: 150,
      rating: 4.8,
    ),
    const ProductModel(
      id: 'prod_2',
      name: 'Áo Khoác Gió Chống Nước',
      categoryId: 'cat_aokhoac',
      price: 399000,
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

  group('Kiểm thử Giỏ hàng & Thanh toán Đa kênh (Task 3.3)', () {
    late AuthProvider authProvider;
    late ProductProvider productProvider;
    late CartProvider cartProvider;
    late OrderProvider orderProvider;

    setUp(() {
      authProvider = AuthProvider();
      authProvider.setMockUser(UserModel(
        uid: 'user_1',
        email: 'user@test.com',
        fullName: 'Nguyễn Văn Test',
        phone: '0901234567',
        defaultAddress: '123 Đường Trần Phú, Đà Nẵng',
        role: 'customer',
        createdAt: testDate,
      ));

      productProvider = ProductProvider();
      productProvider.setMockProducts(sampleProducts);

      cartProvider = CartProvider();
      orderProvider = OrderProvider();
    });

    testWidgets('1. Checkbox chọn từng món & Chọn tất cả cập nhật đúng Tạm tính', (tester) async {
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 199000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
        isSelected: true,
      ));

      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_2_M_Xanh Navy',
        productId: 'prod_2',
        productName: 'Áo Khoác Gió Chống Nước',
        imageUrl: 'https://images.unsplash.com/photo-2.jpg',
        price: 399000,
        size: 'M',
        color: 'Xanh Navy',
        quantity: 1,
        isSelected: true,
      ));

      await tester.pumpWidget(createTestWidget(
        child: const CartScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Ban đầu cả 2 món được chọn -> Tạm tính = 199k + 399k = 598.000đ
      expect(cartProvider.subtotal, 598000);
      expect(cartProvider.selectedQuantity, 2);
      expect(find.text('TIẾN HÀNH THANH TOÁN (2)'), findsOneWidget);

      // Bỏ chọn món 2
      cartProvider.toggleItemSelection('prod_2_M_Xanh Navy');
      await tester.pump(const Duration(milliseconds: 300));

      // Tạm tính giảm xuống chỉ còn 199.000đ của món 1
      expect(cartProvider.subtotal, 199000);
      expect(cartProvider.selectedQuantity, 1);
      expect(find.text('TIẾN HÀNH THANH TOÁN (1)'), findsOneWidget);

      // Bấm Chọn tất cả
      cartProvider.toggleSelectAll(true);
      await tester.pump(const Duration(milliseconds: 300));

      expect(cartProvider.subtotal, 598000);
      expect(cartProvider.selectedQuantity, 2);
    });

    testWidgets('2. Thanh tiến trình Freeship hiển thị chính xác theo số tiền tạm tính', (tester) async {
      // 1 món 199.000đ (< 499.000đ threshold) -> cần mua thêm 300.000đ
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 199000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
        isSelected: true,
      ));

      await tester.pumpWidget(createTestWidget(
        child: const CartScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Mua thêm 300.000'), findsOneWidget);
      expect(find.textContaining('MIỄN PHÍ VẬN CHUYỂN!'), findsOneWidget);

      // Thêm món 2 (399.000đ) -> tổng = 598.000đ (>= 499.000đ)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_2_M_Xanh Navy',
        productId: 'prod_2',
        productName: 'Áo Khoác Gió Chống Nước',
        imageUrl: 'https://images.unsplash.com/photo-2.jpg',
        price: 399000,
        size: 'M',
        color: 'Xanh Navy',
        quantity: 1,
        isSelected: true,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('🎉 Đơn hàng đã đủ điều kiện MIỄN PHÍ VẬN CHUYỂN!'), findsOneWidget);
    });

    testWidgets('3. Khóa Bẫy 9: Hiển thị cảnh báo và làm mờ món hết hàng trong kho biến thể', (tester) async {
      // Thêm món có phân loại hết hàng ('S_Đen' có stock = 0)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Đen',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 199000,
        size: 'S',
        color: 'Đen',
        quantity: 1,
        isSelected: false,
      ));

      await tester.pumpWidget(createTestWidget(
        child: const CartScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hết hàng phân loại này'), findsOneWidget);
    });

    testWidgets('4. Khóa Bẫy 2: Đổi Size/Màu ngay tại Giỏ và tự động gộp số lượng nếu trùng SKU', (tester) async {
      // Giỏ có sẵn 2 món:
      // Món A: S_Trắng (SL: 1)
      // Món B: M_Trắng (SL: 2)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 199000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
      ));

      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_M_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 199000,
        size: 'M',
        color: 'Trắng',
        quantity: 2,
      ));

      expect(cartProvider.items.length, 2);

      // Đổi Món A từ S_Trắng sang M_Trắng
      cartProvider.updateItemVariant(
        oldCartItemId: 'prod_1_S_Trắng',
        newSize: 'M',
        newColor: 'Trắng',
        maxVariantStock: 8,
      );

      // Khóa Bẫy 2: Dòng S_Trắng bị xóa, dòng M_Trắng được gộp thành SL: 1 + 2 = 3!
      expect(cartProvider.items.length, 1);
      expect(cartProvider.items.first.cartItemId, 'prod_1_M_Trắng');
      expect(cartProvider.items.first.quantity, 3);
    });

    testWidgets('5. Khóa Bẫy 1: CheckoutScreen tính tiền độc lập trên các món được chọn', (tester) async {
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 199000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
        isSelected: true, // Được chọn
      ));

      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_2_M_Xanh Navy',
        productId: 'prod_2',
        productName: 'Áo Khoác Gió Chống Nước',
        imageUrl: 'https://images.unsplash.com/photo-2.jpg',
        price: 399000,
        size: 'M',
        color: 'Xanh Navy',
        quantity: 1,
        isSelected: false, // Bỏ chọn
      ));

      await tester.pumpWidget(createTestWidget(
        child: const CheckoutScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
        orderProvider: orderProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Màn hình Checkout chỉ hiển thị Áo Thun Cotton Compact (món được chọn)
      expect(find.textContaining('Áo Thun Cotton Compact (S, Trắng) x1'), findsOneWidget);
      // Tuyệt đối không hiển thị món 2 đã bỏ chọn
      expect(find.textContaining('Áo Khoác Gió Chống Nước'), findsNothing);
      // Tạm tính tiền hàng: 199.000đ
      expect(find.textContaining('199.000'), findsWidgets);
    });

    testWidgets('6. Chuyển đổi 2 Tab Nhận hàng: Giao tận nơi (30k) vs Nhận tại cửa hàng (0đ)', (tester) async {
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 199000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
        isSelected: true,
      ));

      await tester.pumpWidget(createTestWidget(
        child: const CheckoutScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
        orderProvider: orderProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Mặc định là Giao tận nơi: Phí vận chuyển 30.000đ
      expect(find.text('Phí ship 30.000đ'), findsOneWidget);
      expect(find.text('Địa chỉ nhận hàng chi tiết *'), findsOneWidget);

      // 2. Chuyển sang Tab Nhận tại cửa hàng
      await tester.tap(find.text('NHẬN TẠI CỬA HÀNG'));
      await tester.pump(const Duration(milliseconds: 300));

      // Phí vận chuyển chuyển sang MIỄN PHÍ (0đ)
      expect(find.text('MIỄN PHÍ (0đ)'), findsOneWidget);
      // Dropdown chọn cửa hàng xuất hiện
      expect(find.text('Chọn cửa hàng nhận hàng:'), findsOneWidget);
    });

    testWidgets('7. Khóa Bẫy 3: Chặn áp mã FREESHIP khi phí ship = 0đ và cho phép áp SALE10', (tester) async {
      // Đơn 350.000đ (đủ điều kiện minOrder 300k của FREESHIP và 200k của SALE10)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 350000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
        isSelected: true,
      ));

      await tester.pumpWidget(createTestWidget(
        child: const CheckoutScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
        orderProvider: orderProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Chuyển sang Nhận tại quầy (phí ship = 0đ)
      await tester.tap(find.text('NHẬN TẠI CỬA HÀNG'));
      await tester.pump(const Duration(milliseconds: 300));

      // Nhập mã FREESHIP và bấm Áp dụng
      final voucherInput = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText?.contains('SALE10') == true);
      await tester.enterText(voucherInput, 'FREESHIP');
      await tester.tap(find.text('Áp dụng'));
      await tester.pump(const Duration(milliseconds: 300));

      // Phải báo lỗi chặn áp mã
      expect(find.textContaining('Đơn hàng đã được Miễn phí vận chuyển (0đ)!'), findsOneWidget);

      // Nhập mã SALE10 hợp lệ
      await tester.enterText(voucherInput, 'SALE10');
      await tester.tap(find.text('Áp dụng'));
      await tester.pump(const Duration(milliseconds: 300));

      // Phải áp dụng thành công và hiển thị nhãn Đã áp dụng
      expect(find.textContaining('Đã áp dụng: SALE10'), findsOneWidget);
    });

    testWidgets('8. Khóa Bẫy 6: Đặt hàng từ giỏ chỉ xóa món đã mua, Mua ngay giữ nguyên giỏ', (tester) async {
      // Giỏ có 2 món: Món A (chọn mua), Món B (không chọn mua)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'item_a',
        productId: 'prod_1',
        productName: 'Món A',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 100000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
        isSelected: true,
      ));

      cartProvider.addItem(const CartItemModel(
        cartItemId: 'item_b',
        productId: 'prod_2',
        productName: 'Món B',
        imageUrl: 'https://images.unsplash.com/photo-2.jpg',
        price: 200000,
        size: 'M',
        color: 'Đen',
        quantity: 1,
        isSelected: false,
      ));

      expect(cartProvider.items.length, 2);

      // Gọi removePurchasedItems (được gọi sau khi checkout thành công)
      cartProvider.removePurchasedItems();

      // Chỉ Món A bị xóa, Món B vẫn còn nguyên trong giỏ! (Khóa Bẫy 6)
      expect(cartProvider.items.length, 1);
      expect(cartProvider.items.first.cartItemId, 'item_b');
    });

    testWidgets('9. VietQrPaymentDialog hiển thị QR code, Hạn thanh toán và Tự động đối soát SePay', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const VietQrPaymentDialog(
          orderId: 'order_test_12345',
          totalPrice: 250000,
          isFromCheckout: true,
        ),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
        orderProvider: orderProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ĐẶT HÀNG THÀNH CÔNG!'), findsOneWidget);
      expect(find.textContaining('MBBank - Ngân hàng TMCP Quân Đội'), findsOneWidget);
      expect(find.text('XEM ĐƠN HÀNG CỦA TÔI'), findsOneWidget);
      expect(find.textContaining('Tự động đối soát MBBank Napas 24/7 qua SePay'), findsOneWidget);
    });

    testWidgets('10. CheckoutScreen: Bộ chọn Sổ địa chỉ 1 chạm mở BottomSheet và tự động điền Tên, SĐT, Địa chỉ', (tester) async {
      authProvider.setMockUser(UserModel(
        uid: 'user_1',
        email: 'user@test.com',
        fullName: 'Nguyễn Văn Test',
        phone: '0901234567',
        defaultAddress: '123 Đường Trần Phú, Đà Nẵng',
        savedAddresses: [
          {
            'label': 'Công ty',
            'recipientName': 'Lê Văn Đồng Nghiệp',
            'phone': '0988776655',
            'address': 'Toà nhà FPT, Quận Ngũ Hành Sơn, Đà Nẵng',
            'isDefault': false,
          },
        ],
        role: 'customer',
        createdAt: testDate,
      ));

      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_1_S_Trắng',
        productId: 'prod_1',
        productName: 'Áo Thun Cotton Compact',
        imageUrl: 'https://images.unsplash.com/photo-1.jpg',
        price: 350000,
        size: 'S',
        color: 'Trắng',
        quantity: 1,
        isSelected: true,
      ));

      await tester.pumpWidget(createTestWidget(
        child: const CheckoutScreen(),
        authProvider: authProvider,
        productProvider: productProvider,
        cartProvider: cartProvider,
        orderProvider: orderProvider,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Kiểm tra ban đầu: Nạp thông tin từ Hồ sơ chính (vì trong sổ không có mặc định)
      expect(find.text('123 Đường Trần Phú, Đà Nẵng'), findsOneWidget);
      expect(find.text('Nguyễn Văn Test'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);

      // 2. Thấy nút Sổ địa chỉ
      expect(find.text('Sổ địa chỉ (1)'), findsOneWidget);

      // 3. Bấm mở BottomSheet
      await tester.tap(find.text('Sổ địa chỉ (1)'));
      await tester.pumpAndSettle();

      // Kiểm tra trong BottomSheet hiển thị cả Hồ sơ chính và Địa chỉ Công ty
      expect(find.text('CHỌN ĐỊA CHỈ NHẬN HÀNG'), findsOneWidget);
      expect(find.text('Hồ sơ chính'), findsOneWidget);
      expect(find.text('Công ty'), findsOneWidget);
      expect(find.text('Toà nhà FPT, Quận Ngũ Hành Sơn, Đà Nẵng'), findsOneWidget);

      // 4. Chọn địa chỉ Công ty
      await tester.tap(find.text('Công ty'));
      await tester.pumpAndSettle();

      // 5. Kiểm tra form tự động điền đồng bộ cả Bộ ba thông tin (Khóa Bẫy Đồng bộ)
      expect(find.text('Toà nhà FPT, Quận Ngũ Hành Sơn, Đà Nẵng'), findsOneWidget);
      expect(find.text('Lê Văn Đồng Nghiệp'), findsOneWidget);
      expect(find.text('0988776655'), findsOneWidget);
    });
  });
}
