import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/screens/cart/checkout_screen.dart';

void main() {
  group('Kiểm thử Giao diện (Widget Test) CheckoutScreen Đa kênh (Task 4.4):', () {
    late AuthProvider authProvider;
    late CartProvider cartProvider;
    late OrderProvider orderProvider;
    late ProductProvider productProvider;

    final sampleCartItems = [
      const CartItemModel(
        cartItemId: 'item_1_L_Den',
        productId: 'prod_1',
        productName: 'Áo Polo Nam Classic',
        imageUrl: 'https://example.com/polo.jpg',
        price: 350000,
        size: 'L',
        color: 'Đen',
        quantity: 1,
        isSelected: true,
      ),
    ];

    setUp(() {
      authProvider = AuthProvider();
      authProvider.setMockUser(UserModel(
        uid: 'user_test_01',
        email: 'test@example.com',
        fullName: 'Nguyễn Văn Test',
        phone: '0901234567',
        defaultAddress: '123 Đường Thời Trang, Hà Nội',
        createdAt: DateTime.now(),
      ));

      cartProvider = CartProvider();
      cartProvider.addItem(sampleCartItems.first);

      orderProvider = OrderProvider();
      productProvider = ProductProvider();
    });

    Widget buildTestableWidget({List<CartItemModel>? directBuyItems}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
          ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
        ],
        child: MaterialApp(
          home: CheckoutScreen(directBuyItems: directBuyItems),
        ),
      );
    }

    testWidgets('1. Hiển thị 2 Tab hình thức nhận hàng (GIAO TẬN NƠI vs NHẬN TẠI CỬA HÀNG)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tiêu đề thanh toán
      expect(find.text('THANH TOÁN ĐƠN HÀNG'), findsOneWidget);

      // 2 Tab nhận hàng
      expect(find.text('GIAO TẬN NƠI'), findsOneWidget);
      expect(find.text('NHẬN TẠI CỬA HÀNG'), findsOneWidget);

      // Mặc định là Giao tận nơi: Có ô nhập địa chỉ chi tiết
      expect(find.textContaining('Địa chỉ nhận hàng chi tiết'), findsOneWidget);
      expect(find.byTooltip('Chọn vị trí trên Bản đồ'), findsOneWidget);

      // Phí ship mặc định dưới 500k là 30.000đ
      expect(find.text('Phí ship 30.000đ'), findsOneWidget);
    });

    testWidgets('2. Chuyển sang Tab "NHẬN TẠI CỬA HÀNG" phí ship về 0đ và chọn Chi nhánh',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Bấm chuyển sang Tab "NHẬN TẠI CỬA HÀNG"
      final pickupTab = find.text('NHẬN TẠI CỬA HÀNG');
      await tester.tap(pickupTab);
      await tester.pumpAndSettle();

      // Hiển thị miễn phí 100%
      expect(find.text('Miễn phí 100%'), findsOneWidget);

      // Hiển thị chọn cửa hàng nhận hàng
      expect(find.text('Chọn cửa hàng nhận hàng:'), findsOneWidget);

      // Không còn hiển thị ô nhập địa chỉ nhận hàng chi tiết
      expect(find.textContaining('Địa chỉ nhận hàng chi tiết'), findsNothing);
    });

    testWidgets('3. Chế độ MUA NGAY (directBuyItems) tính tiền độc lập không phụ thuộc giỏ hàng',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Món mua ngay giá 450.000đ
      const directItem = CartItemModel(
        cartItemId: 'direct_01',
        productId: 'prod_direct',
        productName: 'Áo Khoác Bomber Mua Ngay',
        imageUrl: 'https://example.com/bomber.jpg',
        price: 450000,
        size: 'XL',
        color: 'Rêu',
        quantity: 1,
        isSelected: true,
      );

      await tester.pumpWidget(buildTestableWidget(directBuyItems: [directItem]));
      await tester.pumpAndSettle();

      // Cuộn xuống để xem tóm tắt đơn hàng
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Kiểm tra món hiển thị là Áo Khoác Bomber Mua Ngay kèm phân loại và số lượng
      expect(find.textContaining('Áo Khoác Bomber Mua Ngay (XL, Rêu) x1'), findsOneWidget);

      // Kê khai tài chính hiển thị 450.000đ
      expect(find.textContaining('450.000'), findsWidgets);
    });

    testWidgets('4. Áp dụng mã Voucher SALE10 giảm giá thành công trên kê khai tài chính',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Cuộn xuống để thấy ô voucher
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();

      // Nhập mã SALE10 vào ô voucher
      final voucherInput = find.widgetWithText(TextField, 'Nhập mã (SALE10 / FREESHIP)');
      expect(voucherInput, findsOneWidget);
      await tester.enterText(voucherInput, 'SALE10');

      // Bấm nút Áp dụng
      final applyBtn = find.widgetWithText(ElevatedButton, 'Áp dụng');
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      // Hiển thị thông báo thành công
      expect(find.text('Áp dụng mã SALE10 thành công!'), findsOneWidget);

      // Kê khai dòng Giảm giá sản phẩm hiển thị giảm 35.000đ (10% của 350.000đ)
      expect(find.textContaining('35.000'), findsWidgets);
    });
  });
}
