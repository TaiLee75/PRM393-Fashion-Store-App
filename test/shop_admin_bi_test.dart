import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/core/utils/formatters.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/category_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/providers/product_provider.dart';
import 'package:fashion_store_app/screens/admin/shop_admin_screen.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

/// Fake FirestoreService phục vụ kiểm thử BI Dashboard Admin không cần kết nối Firebase thật
class FakeFirestoreServiceForAdminBI extends FirestoreService {
  final List<OrderModel> ordersDb;
  final List<ProductModel> productsDb;
  final List<CategoryModel> categoriesDb;

  final StreamController<List<OrderModel>> _allOrdersController =
      StreamController<List<OrderModel>>.broadcast();

  FakeFirestoreServiceForAdminBI({
    required this.ordersDb,
    required this.productsDb,
    required this.categoriesDb,
  });

  @override
  Stream<List<OrderModel>> streamAllOrders() {
    return Stream.value(ordersDb);
  }

  @override
  Stream<List<OrderModel>> streamUserOrders(String userId) {
    return Stream.value(ordersDb.where((o) => o.userId == userId).toList());
  }

  @override
  Future<List<CategoryModel>> getCategories() async => categoriesDb;

  @override
  Future<List<ProductModel>> getProducts({String? categoryId}) async => productsDb;

  @override
  Stream<List<CategoryModel>> streamCategories() => Stream.value(categoriesDb);

  @override
  Stream<List<ProductModel>> streamProducts() => Stream.value(productsDb);

  void dispose() {
    _allOrdersController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<CategoryModel> mockCategories = [
    const CategoryModel(id: 'cat_aothun', name: 'Áo Thun', iconUrl: 'https://example.com/aothun.png'),
    const CategoryModel(id: 'cat_quanjean', name: 'Quần Jean', iconUrl: 'https://example.com/quanjean.png'),
  ];

  final now = DateTime.now();

  final List<OrderModel> mockOrders = [
    // 2 đơn Delivered (Một đơn hôm nay, một đơn 3 ngày trước)
    OrderModel(
      orderId: 'ORD_DELIVERED_01',
      userId: 'user_01',
      userName: 'Khách A',
      phone: '0901111111',
      shippingAddress: 'Hà Nội',
      items: const [
        CartItemModel(
          cartItemId: 'item_1',
          productId: 'prod_1',
          productName: 'Áo Basic Cotton',
          imageUrl: '',
          price: 600000,
          size: 'L',
          color: 'Trắng',
          quantity: 1,
        ),
      ],
      subtotal: 600000,
      totalPrice: 600000,
      status: OrderModel.statusDelivered,
      createdAt: now.subtract(const Duration(hours: 2)), // Hôm nay
    ),
    OrderModel(
      orderId: 'ORD_DELIVERED_02',
      userId: 'user_02',
      userName: 'Khách B',
      phone: '0902222222',
      shippingAddress: 'TP.HCM',
      items: const [
        CartItemModel(
          cartItemId: 'item_2',
          productId: 'prod_2',
          productName: 'Quần Jean Slimfit',
          imageUrl: '',
          price: 400000,
          size: '32',
          color: 'Xanh',
          quantity: 1,
        ),
      ],
      subtotal: 400000,
      totalPrice: 400000,
      status: OrderModel.statusDelivered,
      createdAt: now.subtract(const Duration(days: 3)), // 3 ngày trước
    ),
    // 1 đơn Pending
    OrderModel(
      orderId: 'ORD_PENDING_01',
      userId: 'user_03',
      userName: 'Khách C',
      phone: '0903333333',
      shippingAddress: 'Đà Nẵng',
      items: const [],
      subtotal: 500000,
      totalPrice: 500000,
      status: OrderModel.statusPending,
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
    // 1 đơn Delivering
    OrderModel(
      orderId: 'ORD_DELIVERING_01',
      userId: 'user_04',
      userName: 'Khách D',
      phone: '0904444444',
      shippingAddress: 'Cần Thơ',
      items: const [],
      subtotal: 300000,
      totalPrice: 300000,
      status: OrderModel.statusDelivering,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    // 1 đơn Cancelled (Khóa Bẫy 5: Không được cộng vào Doanh thu thực thu)
    OrderModel(
      orderId: 'ORD_CANCELLED_01',
      userId: 'user_05',
      userName: 'Khách E',
      phone: '0905555555',
      shippingAddress: 'Hải Phòng',
      items: const [],
      subtotal: 200000,
      totalPrice: 200000,
      status: OrderModel.statusCancelled,
      createdAt: now.subtract(const Duration(hours: 4)),
    ),
    // 1 đơn ReturnRequested (Khóa Bẫy 5: Không được cộng vào Doanh thu thực thu)
    OrderModel(
      orderId: 'ORD_RETURN_01',
      userId: 'user_06',
      userName: 'Khách F',
      phone: '0906666666',
      shippingAddress: 'Nha Trang',
      items: const [],
      subtotal: 150000,
      totalPrice: 150000,
      status: OrderModel.statusReturnRequested,
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
  ];

  final List<ProductModel> mockProducts = [
    const ProductModel(
      id: 'prod_1',
      name: 'Áo Thun Basic Cotton',
      description: 'Mô tả áo thun',
      price: 200000,
      stock: 2, // Low stock <= 5
      soldCount: 150, // Rank #1 Best Seller
      categoryId: 'cat_aothun',
      imageUrls: [],
      sizes: ['M', 'L'],
      colors: ['Trắng', 'Đen'],
      rating: 4.8,
      variantStock: {'M_Trắng': 1, 'L_Đen': 1},
    ),
    const ProductModel(
      id: 'prod_2',
      name: 'Quần Jean Slimfit Co Giãn',
      description: 'Mô tả quần jean',
      price: 400000,
      stock: 0, // Hết hàng hoàn toàn
      soldCount: 100, // Rank #2 Best Seller
      categoryId: 'cat_quanjean',
      imageUrls: [],
      sizes: ['30', '32'],
      colors: ['Xanh'],
      rating: 4.6,
      variantStock: {'30_Xanh': 0, '32_Xanh': 0},
    ),
    const ProductModel(
      id: 'prod_3',
      name: 'Áo Polo Thể Thao Pro',
      description: 'Mô tả polo',
      price: 350000,
      stock: 15,
      soldCount: 80, // Rank #3 Best Seller
      categoryId: 'cat_aothun',
      imageUrls: [],
      sizes: ['S', 'M', 'L'],
      colors: ['Xanh Navy'],
      rating: 4.5,
      variantStock: {'S_Xanh Navy': 0, 'M_Xanh Navy': 10, 'L_Xanh Navy': 5}, // Có SKU hết hàng
    ),
    const ProductModel(
      id: 'prod_4',
      name: 'Quần Kaki Ống Đứng',
      description: 'Mô tả kaki',
      price: 320000,
      stock: 25, // Tồn kho an toàn
      soldCount: 50, // Rank #4 Best Seller
      categoryId: 'cat_quanjean',
      imageUrls: [],
      sizes: ['31'],
      colors: ['Be'],
      rating: 4.2,
      variantStock: {'31_Be': 25},
    ),
    const ProductModel(
      id: 'prod_5',
      name: 'Nón Lưỡi Trai Classic',
      description: 'Phụ kiện nón',
      price: 150000,
      stock: 30, // Tồn kho an toàn
      soldCount: 30, // Rank #5 Best Seller
      categoryId: 'cat_aothun',
      imageUrls: [],
      sizes: ['FreeSize'],
      colors: ['Đen'],
      rating: 4.0,
      variantStock: {'FreeSize_Đen': 30},
    ),
    const ProductModel(
      id: 'prod_6',
      name: 'Áo Khoác Bomber Gió',
      description: 'Mô tả áo khoác',
      price: 550000,
      stock: 12, // Tồn kho an toàn
      soldCount: 10, // Rank #6 (Không lọt Top 5)
      categoryId: 'cat_aothun',
      imageUrls: [],
      sizes: ['XL'],
      colors: ['Rêu'],
      rating: 4.9,
      variantStock: {'XL_Rêu': 12},
    ),
  ];

  Widget buildTestableWidget({
    required FakeFirestoreServiceForAdminBI firestoreService,
    required OrderProvider orderProvider,
    required ProductProvider productProvider,
    required AuthProvider authProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
        ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
      ],
      child: const MaterialApp(
        home: ShopAdminScreen(),
      ),
    );
  }

  group('Task 4.1: Kiểm thử Toàn diện Admin BI Dashboard (ShopAdminScreen)', () {
    late FakeFirestoreServiceForAdminBI fakeFirestore;
    late OrderProvider orderProvider;
    late ProductProvider productProvider;
    late AuthProvider authProvider;

    setUp(() {
      fakeFirestore = FakeFirestoreServiceForAdminBI(
        ordersDb: mockOrders,
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      );

      orderProvider = OrderProvider(firestoreService: fakeFirestore);
      orderProvider.setMockAllOrders(mockOrders);

      productProvider = ProductProvider(firestoreService: fakeFirestore);
      productProvider.setMockProducts(mockProducts);
      productProvider.setMockCategories(mockCategories);

      authProvider = AuthProvider(firestoreService: fakeFirestore);
      authProvider.setMockUser(
        UserModel(
          uid: 'admin_001',
          email: 'admin@fashionstore.vn',
          fullName: 'Quản Trị Viên',
          role: 'admin',
          createdAt: DateTime.now(),
        ),
      );
    });

    testWidgets('1. Khóa Bẫy 5: Doanh thu thực thu & AOV chỉ tính đơn Delivered (Loại trừ Cancelled/Return)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          firestoreService: fakeFirestore,
          orderProvider: orderProvider,
          productProvider: productProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Kiểm tra tiêu đề màn hình
      expect(find.text('SHOP ADMIN MANAGEMENT PORTAL'), findsOneWidget);

      // Thẻ Doanh Thu Thực Thu
      expect(find.text('DOANH THU THỰC THU (NET REVENUE)'), findsOneWidget);
      expect(find.text('STATUS: DELIVERED'), findsOneWidget);

      // Khóa Bẫy 5: Tổng doanh thu Delivered = 600,000 + 400,000 = 1,000,000đ
      // Cancelled (200k), ReturnRequested (150k), Pending (500k), Delivering (300k) TUYỆT ĐỐI không cộng vào!
      expect(find.text(AppFormatters.formatCurrency(1000000)), findsOneWidget);

      // Đơn hoàn tất: 2 đơn
      expect(find.text('Đơn hoàn tất: 2 đơn'), findsOneWidget);

      // AOV = 1,000,000 / 2 = 500,000đ
      expect(find.text('AOV: ${AppFormatters.formatCurrency(500000)}'), findsOneWidget);

      // Khóa bẫy 5 ghi chú giải thích
      expect(
        find.text('Khóa Bẫy 5: Không tính đơn Hủy hoặc Hoàn trả • Chạm để xem danh sách'),
        findsOneWidget,
      );
    });

    testWidgets('2. Bộ lọc thời gian BI (Hôm nay, 7 ngày qua, 30 ngày qua, Toàn thời gian)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          firestoreService: fakeFirestore,
          orderProvider: orderProvider,
          productProvider: productProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Thanh lọc thời gian hiển thị đủ 4 chip
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('7 ngày qua'), findsOneWidget);
      expect(find.text('30 ngày qua'), findsOneWidget);
      expect(find.text('Toàn thời gian'), findsOneWidget);

      // Chuyển sang bộ lọc 'Hôm nay'
      // Trong mockOrders, chỉ có ORD_DELIVERED_01 (600,000đ) là tạo cách đây 2 tiếng (hôm nay)
      await tester.tap(find.text('Hôm nay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Doanh thu hôm nay = 600,000đ (1 đơn hoàn tất)
      expect(find.text(AppFormatters.formatCurrency(600000)), findsOneWidget);
      expect(find.text('Đơn hoàn tất: 1 đơn'), findsOneWidget);
      expect(find.text('AOV: ${AppFormatters.formatCurrency(600000)}'), findsOneWidget);

      // Chuyển sang '7 ngày qua'
      // Bao gồm cả 2 đơn Delivered (cách đây 2 giờ và 3 ngày) -> 1,000,000đ
      await tester.tap(find.text('7 ngày qua'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(AppFormatters.formatCurrency(1000000)), findsOneWidget);
      expect(find.text('Đơn hoàn tất: 2 đơn'), findsOneWidget);
    });

    testWidgets('3. Widget Cảnh báo tồn kho thấp & Hết hàng SKU',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          firestoreService: fakeFirestore,
          orderProvider: orderProvider,
          productProvider: productProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tiêu đề widget cảnh báo tồn kho
      expect(find.text('CẢNH BÁO TỒN KHO THẤP & HẾT HÀNG'), findsOneWidget);

      // 3 sản phẩm có vấn đề tồn kho (prod_1 stock=2, prod_2 stock=0, prod_3 variantStock có SKU hết)
      expect(find.text('3 MẶT HÀNG'), findsOneWidget);

      // prod_2: Hết hàng hoàn toàn (0)
      expect(find.text('HẾT HÀNG (0)'), findsOneWidget);
      // Quần Jean Slimfit Co Giãn xuất hiện ở cả danh sách Cảnh Báo Tồn Kho và Top Best Sellers
      expect(find.text('Quần Jean Slimfit Co Giãn'), findsNWidgets(2));

      // prod_1: Tồn kho thấp (2)
      expect(find.text('TỒN KHO: 2'), findsOneWidget);
      expect(find.text('Áo Thun Basic Cotton'), findsNWidgets(2));

      // prod_3: Hết SKU S - Xanh Navy
      expect(find.text('Áo Polo Thể Thao Pro'), findsNWidgets(2));
      expect(find.text('Hết SKU: S - Xanh Navy'), findsOneWidget);

      // Nút +Stock hiển thị cho 3 sản phẩm trong cảnh báo
      expect(find.text('+Stock'), findsNWidgets(3));
    });

    testWidgets('4. Bảng xếp hạng Top 5 sản phẩm bán chạy nhất (Best Sellers Ranking)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          firestoreService: fakeFirestore,
          orderProvider: orderProvider,
          productProvider: productProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tiêu đề bảng xếp hạng
      expect(find.text('TOP 5 SẢN PHẨM BÁN CHẠY NHẤT'), findsOneWidget);

      // Huy hiệu thứ hạng #1, #2, #3, #4, #5
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);

      // #1: Áo Thun Basic Cotton (150 đã bán, doanh thu ước tính: 150 * 200k = 30.000.000₫)
      expect(find.text('150 đã bán'), findsOneWidget);
      expect(find.text(AppFormatters.formatCurrency(150 * 200000)), findsOneWidget);

      // #2: Quần Jean Slimfit Co Giãn (100 đã bán, 100 * 400k = 40.000.000₫)
      expect(find.text('100 đã bán'), findsOneWidget);
      expect(find.text(AppFormatters.formatCurrency(100 * 400000)), findsOneWidget);

      // #3: Áo Polo Thể Thao Pro (80 đã bán)
      expect(find.text('80 đã bán'), findsOneWidget);

      // #6: Áo Khoác Bomber Gió (chỉ 10 đã bán, không nằm trong Top 5)
      expect(find.text('10 đã bán'), findsNothing);
    });

    testWidgets('5. Thẻ KPI Metrics & Điều hướng lọc tự động sang Tab 2',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          firestoreService: fakeFirestore,
          orderProvider: orderProvider,
          productProvider: productProvider,
          authProvider: authProvider,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra số liệu trên các thẻ KPI
      expect(find.text('Kho Sản Phẩm'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // 6 sản phẩm

      expect(find.text('Chờ Duyệt Đơn'), findsOneWidget);
      expect(find.text('Giao Hoàn Tất'), findsOneWidget);
      expect(find.text('Yêu Cầu Đổi / Trả'), findsOneWidget);
      expect(find.text('Đơn Đã Hủy'), findsOneWidget);

      // Bấm vào thẻ "Chờ Duyệt Đơn" để kích hoạt điều hướng Tab 2 và tự chọn chip "Chờ xử lý"
      await tester.tap(find.text('Chờ Duyệt Đơn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tab 2: Hiển thị bộ lọc với các chip trạng thái
      expect(find.text('Tất cả'), findsOneWidget);
      // 'Chờ xử lý' xuất hiện ở Chip lọc và ở Badge của đơn hàng ORD_PENDING_01
      expect(find.text('Chờ xử lý'), findsNWidgets(2));
      expect(find.text('Đang giao'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);
      expect(find.text('Đổi / Trả'), findsOneWidget);
      expect(find.text('Đã hủy'), findsOneWidget);

      // Vì đã lọc Pending, chỉ đơn ORD_PENDING_01 được hiển thị
      expect(find.text('Mã đơn: #ORD_PEND'), findsOneWidget);
      expect(find.text('Khách: Khách C - 0903333333'), findsOneWidget);
      expect(find.text('Khách: Khách A - 0901111111'), findsNothing);
    });
  });
}
