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
import 'package:fashion_store_app/screens/orders/order_detail_screen.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

/// Fake FirestoreService phục vụ kiểm thử Task 4.2: Tab Duyệt Đơn Admin
class FakeFirestoreServiceForOrderApproval extends FirestoreService {
  final List<OrderModel> ordersDb;
  final List<ProductModel> productsDb;
  final List<CategoryModel> categoriesDb;

  FakeFirestoreServiceForOrderApproval({
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

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    String? userId,
  }) async {
    final idx = ordersDb.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      ordersDb[idx] = ordersDb[idx].copyWith(
        status: status,
        paymentStatus: status == OrderModel.statusDelivered ? OrderModel.paymentPaid : ordersDb[idx].paymentStatus,
      );
    }
  }

  @override
  Future<void> cancelOrder(
    String orderId, {
    String? cancelReason,
    String cancelledBy = 'customer',
  }) async {
    final idx = ordersDb.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      ordersDb[idx] = ordersDb[idx].copyWith(
        status: OrderModel.statusCancelled,
        cancelReason: cancelReason ?? '',
        cancelledBy: cancelledBy,
        paymentStatus: ordersDb[idx].paymentStatus == OrderModel.paymentPaid ? OrderModel.paymentRefunded : OrderModel.paymentUnpaid,
      );
    }
  }

  @override
  Future<void> approveReturnOrder(String orderId) async {
    final idx = ordersDb.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      ordersDb[idx] = ordersDb[idx].copyWith(
        status: OrderModel.statusReturned,
        paymentStatus: OrderModel.paymentRefundPending,
      );
    }
  }

  @override
  Future<void> confirmPaymentRefunded(String orderId) async {
    final idx = ordersDb.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      ordersDb[idx] = ordersDb[idx].copyWith(
        paymentStatus: OrderModel.paymentRefunded,
      );
    }
  }

  @override
  Future<void> rejectReturnOrder(String orderId, {String? reason}) async {
    final idx = ordersDb.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      ordersDb[idx] = ordersDb[idx].copyWith(
        status: OrderModel.statusDelivered,
      );
    }
  }

  @override
  Future<void> confirmPaymentPaid(String orderId) async {
    final idx = ordersDb.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      ordersDb[idx] = ordersDb[idx].copyWith(
        paymentStatus: OrderModel.paymentPaid,
      );
    }
  }

  @override
  Future<void> rejectPaymentSubmitted(String orderId, {String? reason}) async {
    final idx = ordersDb.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      ordersDb[idx] = ordersDb[idx].copyWith(
        paymentStatus: OrderModel.paymentUnpaid,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();

  final List<CategoryModel> mockCategories = [
    const CategoryModel(id: 'cat_aothun', name: 'Áo Thun', iconUrl: ''),
  ];

  final List<ProductModel> mockProducts = [
    const ProductModel(
      id: 'prod_01',
      name: 'Áo Thun Cotton Compact',
      description: 'Mô tả áo',
      price: 250000,
      stock: 50,
      soldCount: 10,
      categoryId: 'cat_aothun',
      imageUrls: [],
      sizes: ['L', 'XL'],
      colors: ['Trắng'],
      rating: 4.8,
    ),
  ];

  Widget buildTestableWidget({
    required FakeFirestoreServiceForOrderApproval firestoreService,
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

  group('Task 4.2: Nâng cấp Tab Duyệt Đơn hàng Admin (ShopAdminScreen - Tab 2)', () {
    late FakeFirestoreServiceForOrderApproval fakeFirestore;
    late OrderProvider orderProvider;
    late ProductProvider productProvider;
    late AuthProvider authProvider;

    setUp(() {
      authProvider = AuthProvider(firestoreService: FakeFirestoreServiceForOrderApproval(
        ordersDb: [],
        productsDb: [],
        categoriesDb: [],
      ));
      authProvider.setMockUser(
        UserModel(
          uid: 'admin_test',
          email: 'admin@lifewear.vn',
          fullName: 'Shop Manager',
          role: 'admin',
          createdAt: DateTime.now(),
        ),
      );

      productProvider = ProductProvider(firestoreService: FakeFirestoreServiceForOrderApproval(
        ordersDb: [],
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      ));
      productProvider.setMockProducts(mockProducts);
      productProvider.setMockCategories(mockCategories);
    });

    testWidgets('1. Xem trước sản phẩm, Huy hiệu Nhận tại quầy & Ghi chú khách hàng',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pickupOrder = OrderModel(
        orderId: 'ORD_PICKUP_01',
        userId: 'user_01',
        userName: 'Nguyễn Văn A',
        phone: '0988777666',
        shippingAddress: '',
        deliveryMethod: OrderModel.deliveryMethodPickup,
        pickupBranchName: 'Lifewear Vincom Bà Triệu',
        note: 'Khách nhận sau 18h tối nay',
        items: const [
          CartItemModel(
            cartItemId: 'item_01',
            productId: 'prod_01',
            productName: 'Áo Thun Cotton Compact',
            imageUrl: '',
            price: 250000,
            size: 'L',
            color: 'Trắng',
            quantity: 2,
          ),
        ],
        subtotal: 500000,
        totalPrice: 500000,
        status: OrderModel.statusPending,
        createdAt: now,
      );

      fakeFirestore = FakeFirestoreServiceForOrderApproval(
        ordersDb: [pickupOrder],
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      );
      orderProvider = OrderProvider(firestoreService: fakeFirestore);
      orderProvider.setMockAllOrders([pickupOrder]);

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

      // Chuyển sang Tab 2: "Đơn Hàng"
      await tester.tap(find.text('Duyệt Đơn'));
      await tester.pumpAndSettle();

      // Kiểm tra Huy hiệu hình thức nhận hàng: Nhận tại quầy & tên chi nhánh
      expect(find.text('Nhận tại quầy'), findsOneWidget);
      expect(find.text('Chi nhánh: Lifewear Vincom Bà Triệu'), findsOneWidget);

      // Kiểm tra Ghi chú của khách hàng
      expect(find.text('Ghi chú: "Khách nhận sau 18h tối nay"'), findsOneWidget);

      // Kiểm tra Xem trước thông tin sản phẩm (Item Details Preview)
      expect(find.text('Áo Thun Cotton Compact'), findsOneWidget);
      expect(find.text('Size: L | Màu: Trắng'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(find.text(AppFormatters.formatVND(500000)), findsNWidgets(2)); // Item subtotal + Order total
    });

    testWidgets('2. Banner Đối soát VietQR (Level 2) & Thao tác Xác nhận (+Paid) / Từ chối',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final vietQrOrder = OrderModel(
        orderId: 'ORD_VIETQR_01',
        userId: 'user_02',
        userName: 'Trần Thị B',
        phone: '0912345678',
        shippingAddress: 'Tòa Landmark 81, TP.HCM',
        items: const [],
        subtotal: 750000,
        totalPrice: 750000,
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentSubmitted,
        transactionRef: 'VQR888999',
        status: OrderModel.statusPending,
        createdAt: now,
      );

      fakeFirestore = FakeFirestoreServiceForOrderApproval(
        ordersDb: [vietQrOrder],
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      );
      orderProvider = OrderProvider(firestoreService: fakeFirestore);
      orderProvider.setMockAllOrders([vietQrOrder]);

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

      // Chuyển sang Tab 2
      await tester.tap(find.text('Duyệt Đơn'));
      await tester.pumpAndSettle();

      // Kiểm tra Banner VietQR xuất hiện với mã giao dịch
      expect(find.text('Khách báo đã chuyển khoản VietQR • Mã GD: VQR888999'), findsOneWidget);
      expect(find.text('Chờ đối soát'), findsOneWidget);

      // Kiểm tra có 2 nút hành động: "Từ chối VietQR" và "Xác nhận đã thu (+Paid)"
      expect(find.text('Từ chối VietQR'), findsOneWidget);
      expect(find.text('Xác nhận đã thu (+Paid)'), findsOneWidget);

      // Bấm nút "Xác nhận đã thu (+Paid)"
      await tester.tap(find.text('Xác nhận đã thu (+Paid)'));
      await tester.pumpAndSettle();

      // Sau khi xác nhận thành công, trạng thái thanh toán chuyển sang Paid (Đã TT), banner biến mất
      expect(find.text('Đã TT'), findsOneWidget);
      expect(find.text('Khách báo đã chuyển khoản VietQR • Mã GD: VQR888999'), findsNothing);
    });

    testWidgets('3. Điều khiển đơn Chờ xử lý (Pending): Duyệt giao hàng & Hủy đơn ACID',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pendingOrder = OrderModel(
        orderId: 'ORD_PENDING_FLOW',
        userId: 'user_03',
        userName: 'Lê Văn C',
        phone: '0933333333',
        shippingAddress: 'Cầu Giấy, Hà Nội',
        items: const [],
        subtotal: 300000,
        totalPrice: 300000,
        paymentMethod: 'COD',
        paymentStatus: OrderModel.paymentUnpaid,
        status: OrderModel.statusPending,
        createdAt: now,
      );

      fakeFirestore = FakeFirestoreServiceForOrderApproval(
        ordersDb: [pendingOrder],
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      );
      orderProvider = OrderProvider(firestoreService: fakeFirestore);
      orderProvider.setMockAllOrders([pendingOrder]);

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

      await tester.tap(find.text('Duyệt Đơn'));
      await tester.pumpAndSettle();

      // Kiểm tra 2 nút: "Hủy đơn" và "Duyệt giao hàng"
      expect(find.text('Hủy đơn'), findsOneWidget);
      expect(find.text('Duyệt giao hàng'), findsOneWidget);

      // 1. Thao tác Duyệt giao hàng
      await tester.tap(find.text('Duyệt giao hàng'));
      await tester.pumpAndSettle();

      // Trạng thái đơn chuyển sang Đang giao hàng
      expect(orderProvider.allOrders.first.status, OrderModel.statusDelivering);
      expect(find.text('Đang giao hàng'), findsOneWidget);
      expect(find.text('Xác nhận đã giao'), findsOneWidget);
    });

    testWidgets('4. Điều khiển đơn Đang giao (Delivering): Xác nhận giao hoàn tất',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deliveringOrder = OrderModel(
        orderId: 'ORD_DELIVERING_FLOW',
        userId: 'user_04',
        userName: 'Phạm Thị D',
        phone: '0944444444',
        shippingAddress: 'Đà Nẵng',
        items: const [],
        subtotal: 450000,
        totalPrice: 450000,
        paymentMethod: 'COD',
        paymentStatus: OrderModel.paymentUnpaid,
        status: OrderModel.statusDelivering,
        createdAt: now,
      );

      fakeFirestore = FakeFirestoreServiceForOrderApproval(
        ordersDb: [deliveringOrder],
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      );
      orderProvider = OrderProvider(firestoreService: fakeFirestore);
      orderProvider.setMockAllOrders([deliveringOrder]);

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

      await tester.tap(find.text('Duyệt Đơn'));
      await tester.pumpAndSettle();

      // Bấm nút "Xác nhận đã giao"
      expect(find.text('Xác nhận đã giao'), findsOneWidget);
      await tester.tap(find.text('Xác nhận đã giao'));
      await tester.pumpAndSettle();

      // Dialog xác nhận xuất hiện
      expect(find.text('Xác nhận giao hàng'), findsOneWidget);
      // Bấm xác nhận trong dialog (nút thứ hai)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận đã giao').last);
      await tester.pumpAndSettle();

      // Trạng thái đơn chuyển sang Delivered (Giao thành công) và tự động Paid
      expect(orderProvider.allOrders.first.status, OrderModel.statusDelivered);
      expect(orderProvider.allOrders.first.paymentStatus, OrderModel.paymentPaid);
      expect(find.text('Giao thành công'), findsOneWidget);
      expect(find.text('Chi tiết đơn →'), findsOneWidget);
    });

    testWidgets('5. Điều khiển Yêu cầu Đổi / Trả (ReturnRequested): Duyệt đổi trả hoàn kho & Refunded',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final returnOrder = OrderModel(
        orderId: 'ORD_RETURN_FLOW',
        userId: 'user_05',
        userName: 'Vũ Văn E',
        phone: '0955555555',
        shippingAddress: 'Hải Phòng',
        items: const [],
        subtotal: 620000,
        totalPrice: 620000,
        paymentMethod: 'VIETQR',
        paymentStatus: OrderModel.paymentPaid,
        returnReason: 'Sản phẩm không vừa form, muốn đổi size lớn hơn',
        status: OrderModel.statusReturnRequested,
        createdAt: now,
      );

      fakeFirestore = FakeFirestoreServiceForOrderApproval(
        ordersDb: [returnOrder],
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      );
      orderProvider = OrderProvider(firestoreService: fakeFirestore);
      orderProvider.setMockAllOrders([returnOrder]);

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

      await tester.tap(find.text('Duyệt Đơn'));
      await tester.pumpAndSettle();

      // Kiểm tra hiển thị banner lý do đổi trả
      expect(find.text('Lý do đổi/trả: "Sản phẩm không vừa form, muốn đổi size lớn hơn"'), findsOneWidget);

      // Kiểm tra 2 nút: "Từ chối Đổi/Trả" và "Duyệt Đổi / Trả"
      expect(find.text('Từ chối Đổi/Trả'), findsOneWidget);
      expect(find.text('Duyệt Đổi / Trả'), findsOneWidget);

      // Bấm nút "Duyệt Đổi / Trả"
      await tester.tap(find.text('Duyệt Đổi / Trả'));
      await tester.pumpAndSettle();

      // Dialog xác nhận duyệt xuất hiện
      expect(find.text('Duyệt Đổi / Trả hàng'), findsOneWidget);
      await tester.tap(find.text('Xác nhận duyệt'));
      await tester.pumpAndSettle();

      // Trạng thái đơn chuyển sang Returned và RefundPending (Bước 1: Chờ hoàn tiền)
      expect(orderProvider.allOrders.first.status, OrderModel.statusReturned);
      expect(orderProvider.allOrders.first.paymentStatus, OrderModel.paymentRefundPending);
      expect(find.text('Đã hoàn trả'), findsOneWidget);
      expect(find.text('Chờ hoàn tiền'), findsOneWidget);
      expect(find.text('Xác nhận đã chuyển tiền hoàn'), findsOneWidget);

      // Admin bấm nút "Xác nhận đã chuyển tiền hoàn" (Bước 2: Hoàn tiền hoàn tất)
      await tester.tap(find.text('Xác nhận đã chuyển tiền hoàn'));
      await tester.pumpAndSettle();

      // Dialog xác nhận hoàn tiền
      expect(find.text('Xác nhận hoàn tiền'), findsOneWidget);
      await tester.tap(find.text('Đã chuyển hoàn'));
      await tester.pumpAndSettle();

      // Trạng thái đơn cập nhật sang Refunded
      expect(orderProvider.allOrders.first.paymentStatus, OrderModel.paymentRefunded);
      expect(find.text('Đã hoàn tiền'), findsOneWidget);
    });

    testWidgets('6. Nhấn vào thẻ đơn hàng điều hướng sang màn hình OrderDetailScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testOrder = OrderModel(
        orderId: 'ORD_NAV_01',
        userId: 'user_06',
        userName: 'Hoàng Thị G',
        phone: '0966666666',
        shippingAddress: 'Nha Trang, Khánh Hòa',
        items: const [],
        subtotal: 350000,
        totalPrice: 350000,
        status: OrderModel.statusPending,
        createdAt: now,
      );

      fakeFirestore = FakeFirestoreServiceForOrderApproval(
        ordersDb: [testOrder],
        productsDb: mockProducts,
        categoriesDb: mockCategories,
      );
      orderProvider = OrderProvider(firestoreService: fakeFirestore);
      orderProvider.setMockAllOrders([testOrder]);

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

      await tester.tap(find.text('Duyệt Đơn'));
      await tester.pumpAndSettle();

      // Nhấn vào thẻ đơn hàng
      await tester.tap(find.text('Mã đơn: #ORD_NAV_'));
      await tester.pumpAndSettle();

      // Xác nhận OrderDetailScreen được mở
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    });
  });
}
