import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

/// Fake FirestoreService độc lập phục vụ kiểm thử đơn vị cho OrderProvider Enterprise (Task 2.4)
class FakeFirestoreServiceForOrder extends FirestoreService {
  final Map<String, OrderModel> ordersDb = {};
  final Map<String, ProductModel> productsDb = {};

  final StreamController<List<OrderModel>> _userOrdersController =
      StreamController<List<OrderModel>>.broadcast();
  final StreamController<List<OrderModel>> _allOrdersController =
      StreamController<List<OrderModel>>.broadcast();

  void _notifyStreams(String userId) {
    final allList = ordersDb.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final userList = allList.where((o) => o.userId == userId).toList();

    _allOrdersController.add(allList);
    _userOrdersController.add(userList);
  }

  @override
  Stream<List<OrderModel>> streamUserOrders(String userId) {
    return _userOrdersController.stream;
  }

  @override
  Stream<List<OrderModel>> streamAllOrders() {
    return _allOrdersController.stream;
  }

  @override
  Future<String> createOrder(OrderModel order) async {
    final generatedId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
    final savedOrder = order.copyWith(orderId: generatedId);
    ordersDb[generatedId] = savedOrder;

    // Trừ kho giả lập
    for (final item in order.items) {
      if (productsDb.containsKey(item.productId)) {
        final p = productsDb[item.productId]!;
        final sku = item.color.isNotEmpty ? '${item.size}_${item.color}' : item.size;
        final currentVariantStock = p.variantStock[sku] ?? 10;
        final updatedVariant = Map<String, int>.from(p.variantStock);
        updatedVariant[sku] = (currentVariantStock - item.quantity).clamp(0, 999);

        productsDb[item.productId] = p.copyWith(
          stock: (p.stock - item.quantity).clamp(0, 999),
          soldCount: p.soldCount + item.quantity,
          variantStock: updatedVariant,
        );
      }
    }

    _notifyStreams(order.userId);
    return generatedId;
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    String? userId,
  }) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    String payment = order.paymentStatus;
    DateTime? deliveredTime = order.deliveredAt;

    // Khóa Bẫy 20: Giao COD thành công coi như đã thu tiền mặt -> Paid
    if (status == OrderModel.statusDelivered) {
      payment = OrderModel.paymentPaid;
      deliveredTime = DateTime.now();
    }

    ordersDb[orderId] = order.copyWith(
      status: status,
      paymentStatus: payment,
      deliveredAt: deliveredTime,
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<void> cancelOrder(
    String orderId, {
    String? cancelReason,
    String cancelledBy = 'customer',
  }) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    // Chống hoàn kho kép
    if (order.status == OrderModel.statusCancelled ||
        order.status == OrderModel.statusReturned) {
      throw Exception('Đơn hàng đã được xử lý hủy trước đó.');
    }

    // Hoàn lại tồn kho
    for (final item in order.items) {
      if (productsDb.containsKey(item.productId)) {
        final p = productsDb[item.productId]!;
        final sku = item.color.isNotEmpty ? '${item.size}_${item.color}' : item.size;
        final currentVariantStock = p.variantStock[sku] ?? 0;
        final updatedVariant = Map<String, int>.from(p.variantStock);
        updatedVariant[sku] = currentVariantStock + item.quantity;

        productsDb[item.productId] = p.copyWith(
          stock: p.stock + item.quantity,
          soldCount: (p.soldCount - item.quantity).clamp(0, 999),
          variantStock: updatedVariant,
        );
      }
    }

    // Xác định trạng thái hoàn tiền
    final newPayment = (order.paymentStatus == OrderModel.paymentPaid ||
            order.paymentStatus == OrderModel.paymentSubmitted)
        ? OrderModel.paymentRefunded
        : OrderModel.paymentUnpaid;

    ordersDb[orderId] = order.copyWith(
      status: OrderModel.statusCancelled,
      paymentStatus: newPayment,
      cancelReason: cancelReason ?? 'Khách hủy đơn',
      cancelledBy: cancelledBy,
      cancelledAt: DateTime.now(),
    );

    _notifyStreams(order.userId);
  }

  @override
  Future<void> updateOrderShippingAddress({
    required String orderId,
    required String newAddress,
    required String phone,
    required String recipientName,
  }) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');
    if (order.status != OrderModel.statusPending) {
      throw Exception('Chỉ có thể chỉnh sửa thông tin khi đơn còn Pending.');
    }

    ordersDb[orderId] = order.copyWith(
      shippingAddress: newAddress,
      phone: phone,
      userName: recipientName,
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<void> requestReturnOrder(
    String orderId, {
    required String returnReason,
  }) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    ordersDb[orderId] = order.copyWith(
      status: OrderModel.statusReturnRequested,
      returnReason: returnReason,
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<void> approveReturnOrder(String orderId) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    // Hoàn lại kho
    for (final item in order.items) {
      if (productsDb.containsKey(item.productId)) {
        final p = productsDb[item.productId]!;
        final sku = item.color.isNotEmpty ? '${item.size}_${item.color}' : item.size;
        final currentVariantStock = p.variantStock[sku] ?? 0;
        final updatedVariant = Map<String, int>.from(p.variantStock);
        updatedVariant[sku] = currentVariantStock + item.quantity;

        productsDb[item.productId] = p.copyWith(
          stock: p.stock + item.quantity,
          soldCount: (p.soldCount - item.quantity).clamp(0, 999),
          variantStock: updatedVariant,
        );
      }
    }

    ordersDb[orderId] = order.copyWith(
      status: OrderModel.statusReturned,
      paymentStatus: OrderModel.paymentRefunded,
      returnedAt: DateTime.now(),
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<void> rejectReturnOrder(String orderId, {String? reason}) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    ordersDb[orderId] = order.copyWith(
      status: OrderModel.statusDelivered,
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<void> confirmPaymentSubmitted(
    String orderId, {
    String? transactionRef,
  }) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    ordersDb[orderId] = order.copyWith(
      paymentStatus: OrderModel.paymentSubmitted,
      transactionRef: transactionRef ?? '',
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<void> confirmPaymentPaid(String orderId) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    ordersDb[orderId] = order.copyWith(
      paymentStatus: OrderModel.paymentPaid,
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<void> rejectPaymentSubmitted(String orderId, {String? reason}) async {
    final order = ordersDb[orderId];
    if (order == null) throw Exception('Đơn hàng không tồn tại.');

    ordersDb[orderId] = order.copyWith(
      paymentStatus: OrderModel.paymentUnpaid,
    );
    _notifyStreams(order.userId);
  }

  @override
  Future<OrderModel?> getOrderById(String orderId) async {
    return ordersDb[orderId];
  }

  void dispose() {
    _userOrdersController.close();
    _allOrdersController.close();
  }
}

void main() {
  group('Kiểm thử Đơn vị Toàn diện (Unit Test) cho OrderProvider Enterprise (Task 2.4):', () {
    late FakeFirestoreServiceForOrder fakeService;
    late OrderProvider orderProvider;

    final sampleItems = [
      const CartItemModel(
        cartItemId: 'prod_001_L_Đen',
        productId: 'prod_001',
        productName: 'Áo Polo Classic Lifewear',
        imageUrl: 'https://example.com/polo.jpg',
        price: 200000,
        size: 'L',
        color: 'Đen',
        quantity: 2,
        isSelected: true,
      ),
    ];

    setUp(() {
      fakeService = FakeFirestoreServiceForOrder();
      fakeService.productsDb['prod_001'] = const ProductModel(
        id: 'prod_001',
        name: 'Áo Polo Classic Lifewear',
        categoryId: 'cat_aothun',
        price: 200000,
        description: 'Mô tả',
        imageUrls: [],
        sizes: ['L'],
        colors: ['Đen'],
        stock: 10,
        soldCount: 5,
        variantStock: {'L_Đen': 10},
        isActive: true,
      );

      orderProvider = OrderProvider(firestoreService: fakeService);
    });

    tearDown(() {
      fakeService.dispose();
      orderProvider.dispose();
    });

    test('1. Khởi tạo ban đầu: Danh sách đơn hàng rỗng và trạng thái sạch', () {
      expect(orderProvider.userOrders, isEmpty);
      expect(orderProvider.allOrders, isEmpty);
      expect(orderProvider.isLoading, isFalse);
      expect(orderProvider.errorMessage, isNull);
      expect(orderProvider.activeUserId, isNull);
    });

    test('2. Mock đơn hàng và bộ lọc trạng thái (userOrdersByStatus & countUserOrdersByStatus)', () {
      final sampleOrders = [
        OrderModel(
          orderId: 'ORD_001',
          userId: 'user_A',
          userName: 'Nguyễn Văn A',
          phone: '0901111111',
          shippingAddress: 'Hà Nội',
          items: sampleItems,
          subtotal: 400000,
          totalPrice: 400000,
          status: OrderModel.statusPending,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          orderId: 'ORD_002',
          userId: 'user_A',
          userName: 'Nguyễn Văn A',
          phone: '0901111111',
          shippingAddress: 'Hà Nội',
          items: sampleItems,
          subtotal: 400000,
          totalPrice: 400000,
          status: OrderModel.statusDelivered,
          createdAt: DateTime.now(),
        ),
      ];

      orderProvider.setMockUserOrders(sampleOrders);
      expect(orderProvider.userOrders.length, 2);
      expect(orderProvider.countUserOrdersByStatus('ALL'), 2);
      expect(orderProvider.countUserOrdersByStatus(OrderModel.statusPending), 1);
      expect(orderProvider.countUserOrdersByStatus(OrderModel.statusDelivered), 1);
      expect(orderProvider.userOrdersByStatus(OrderModel.statusPending).first.orderId, 'ORD_001');
    });

    test('3. Tra cứu đơn hàng theo ID (findById)', () {
      final order = OrderModel(
        orderId: 'ORD_FIND_ME',
        userId: 'user_A',
        userName: 'Nguyễn Văn A',
        phone: '0901111111',
        shippingAddress: 'Hà Nội',
        items: sampleItems,
        subtotal: 400000,
        totalPrice: 400000,
        status: OrderModel.statusPending,
        createdAt: DateTime.now(),
      );

      orderProvider.setMockUserOrders([order]);
      expect(orderProvider.findById('ORD_FIND_ME'), isNotNull);
      expect(orderProvider.findById('ORD_NOT_EXIST'), isNull);
    });

    test('4. Bộ lọc Admin: pendingPaymentOrders và returnRequestedOrders', () {
      final adminOrders = [
        OrderModel(
          orderId: 'ORD_QR_SUBMITTED',
          userId: 'user_B',
          userName: 'Trần Văn B',
          phone: '0902222222',
          shippingAddress: 'Đà Nẵng',
          items: sampleItems,
          subtotal: 400000,
          totalPrice: 400000,
          paymentStatus: OrderModel.paymentSubmitted,
          createdAt: DateTime.now(),
        ),
        OrderModel(
          orderId: 'ORD_RETURN_REQ',
          userId: 'user_C',
          userName: 'Lê Văn C',
          phone: '0903333333',
          shippingAddress: 'TP.HCM',
          items: sampleItems,
          subtotal: 400000,
          totalPrice: 400000,
          status: OrderModel.statusReturnRequested,
          createdAt: DateTime.now(),
        ),
      ];

      orderProvider.setMockAllOrders(adminOrders);
      expect(orderProvider.pendingPaymentOrders.length, 1);
      expect(orderProvider.pendingPaymentOrders.first.orderId, 'ORD_QR_SUBMITTED');
      expect(orderProvider.returnRequestedOrders.length, 1);
      expect(orderProvider.returnRequestedOrders.first.orderId, 'ORD_RETURN_REQ');
    });

    test('5. Tạo đơn hàng mới (createOrder) thành công và trừ kho SKU', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_test_01',
        userName: 'Lê Hoàng Dũng',
        phone: '0909999999',
        shippingAddress: 'Số 10 Mai Chí Thọ, Quận 2, TP.HCM',
        items: sampleItems, // mua 2 cái prod_001 (L - Đen)
        subtotal: 400000,
        voucherCode: 'SALE10',
        discountAmount: 40000,
        totalPrice: 360000,
        paymentMethod: 'COD',
        deliveryMethod: 'DELIVERY',
        shippingFee: 0,
        productDiscount: 40000,
      );

      expect(orderId, isNotNull);
      expect(orderId!.startsWith('ORD_'), isTrue);

      // Kiểm tra kho bị trừ: 10 - 2 = 8, soldCount: 5 + 2 = 7
      final updatedProduct = fakeService.productsDb['prod_001']!;
      expect(updatedProduct.stock, 8);
      expect(updatedProduct.variantStock['L_Đen'], 8);
      expect(updatedProduct.soldCount, 7);

      // Kiểm tra dữ liệu đơn hàng đã lưu trong database
      final savedOrder = fakeService.ordersDb[orderId]!;
      expect(savedOrder.status, OrderModel.statusPending);
      expect(savedOrder.paymentStatus, OrderModel.paymentUnpaid);
      expect(savedOrder.totalPrice, 360000);
      expect(savedOrder.productDiscount, 40000);
    });

    test('6. Khóa Bẫy 20: Chuyển trạng thái sang Delivered tự động xác nhận paymentStatus = Paid', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_test_01',
        userName: 'Lê Hoàng Dũng',
        phone: '0909999999',
        shippingAddress: 'TP.HCM',
        items: sampleItems,
        subtotal: 400000,
        voucherCode: '',
        discountAmount: 0,
        totalPrice: 400000,
        paymentMethod: 'COD',
      );

      expect(fakeService.ordersDb[orderId]!.paymentStatus, OrderModel.paymentUnpaid);

      // Cập nhật Delivered
      final success = await orderProvider.updateOrderStatus(
        orderId: orderId!,
        newStatus: OrderModel.statusDelivered,
        userId: 'user_test_01',
      );

      expect(success, isTrue);
      // Khóa Bẫy 20: Tự động thu tiền mặt COD
      expect(fakeService.ordersDb[orderId]!.status, OrderModel.statusDelivered);
      expect(fakeService.ordersDb[orderId]!.paymentStatus, OrderModel.paymentPaid);
      expect(fakeService.ordersDb[orderId]!.deliveredAt, isNotNull);
    });

    test('7. Khóa Bẫy 5 & 21: Hủy đơn hàng an toàn (cancelOrder) và tự động hoàn lại kho SKU', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_test_01',
        userName: 'Lê Hoàng Dũng',
        phone: '0909999999',
        shippingAddress: 'TP.HCM',
        items: sampleItems, // mua 2 cái -> stock còn 8
        subtotal: 400000,
        voucherCode: '',
        discountAmount: 0,
        totalPrice: 400000,
        paymentMethod: 'COD',
      );
      expect(fakeService.productsDb['prod_001']!.stock, 8);

      // Khách hàng hủy đơn
      final cancelSuccess = await orderProvider.cancelOrder(
        orderId!,
        cancelReason: 'Đổi ý không mua nữa',
        cancelledBy: 'customer',
      );

      expect(cancelSuccess, isTrue);
      final cancelledOrder = fakeService.ordersDb[orderId]!;
      expect(cancelledOrder.status, OrderModel.statusCancelled);
      expect(cancelledOrder.cancelReason, 'Đổi ý không mua nữa');
      expect(cancelledOrder.cancelledBy, 'customer');

      // Tồn kho được hoàn lại nguyên vẹn: 8 + 2 = 10
      expect(fakeService.productsDb['prod_001']!.stock, 10);
      expect(fakeService.productsDb['prod_001']!.variantStock['L_Đen'], 10);
    });

    test('8. Hủy đơn đã thanh toán: Tự động chuyển paymentStatus sang Refunded', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_test_01',
        userName: 'Khách VietQR',
        phone: '0909999999',
        shippingAddress: 'TP.HCM',
        items: sampleItems,
        subtotal: 400000,
        voucherCode: '',
        discountAmount: 0,
        totalPrice: 400000,
        paymentMethod: 'VIETQR',
      );

      // Giả lập Admin đã xác nhận Paid
      await orderProvider.confirmPaymentPaid(orderId!);
      expect(fakeService.ordersDb[orderId]!.paymentStatus, OrderModel.paymentPaid);

      // Hủy đơn
      await orderProvider.cancelOrder(orderId, cancelReason: 'Hết hàng hoặc sai mẫu');
      expect(fakeService.ordersDb[orderId]!.paymentStatus, OrderModel.paymentRefunded);
    });

    test('9. Chỉnh sửa thông tin giao hàng khi đơn còn Pending (updateShippingInfo)', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_test_01',
        userName: 'Tên Ban Đầu',
        phone: '0901111111',
        shippingAddress: 'Địa chỉ cũ',
        items: sampleItems,
        subtotal: 400000,
        voucherCode: '',
        discountAmount: 0,
        totalPrice: 400000,
        paymentMethod: 'COD',
      );

      final ok = await orderProvider.updateShippingInfo(
        orderId: orderId!,
        newAddress: 'Số 99 Lê Lợi, Quận 1, TP.HCM',
        phone: '0988888888',
        recipientName: 'Tên Người Nhận Mới',
      );

      expect(ok, isTrue);
      final updated = fakeService.ordersDb[orderId]!;
      expect(updated.shippingAddress, 'Số 99 Lê Lợi, Quận 1, TP.HCM');
      expect(updated.phone, '0988888888');
      expect(updated.userName, 'Tên Người Nhận Mới');
    });

    test('10. Chặn sửa thông tin giao hàng khi đơn không còn Pending', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_test_01',
        userName: 'Tên Ban Đầu',
        phone: '0901111111',
        shippingAddress: 'Địa chỉ cũ',
        items: sampleItems,
        subtotal: 400000,
        voucherCode: '',
        discountAmount: 0,
        totalPrice: 400000,
        paymentMethod: 'COD',
      );

      // Chuyển sang Delivering
      await orderProvider.updateOrderStatus(orderId: orderId!, newStatus: OrderModel.statusDelivering);

      // Thử cập nhật địa chỉ -> Bị từ chối
      final ok = await orderProvider.updateShippingInfo(
        orderId: orderId,
        newAddress: 'Địa chỉ mới',
        phone: '0988888888',
        recipientName: 'Người Nhận',
      );

      expect(ok, isFalse);
      expect(orderProvider.errorMessage, contains('Chỉ có thể chỉnh sửa thông tin khi đơn còn Pending'));
    });

    test('11. Quy trình Đổi/Trả hàng (requestReturn, approveReturn & rejectReturn)', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_test_01',
        userName: 'Khách Trả Hàng',
        phone: '0901111111',
        shippingAddress: 'TP.HCM',
        items: sampleItems, // mua 2 cái -> stock từ 10 xuống 8
        subtotal: 400000,
        voucherCode: '',
        discountAmount: 0,
        totalPrice: 400000,
        paymentMethod: 'COD',
      );
      // Giao hàng thành công
      await orderProvider.updateOrderStatus(orderId: orderId!, newStatus: OrderModel.statusDelivered);
      expect(fakeService.productsDb['prod_001']!.stock, 8);

      // 1. Khách gửi yêu cầu trả hàng
      final reqOk = await orderProvider.requestReturn(orderId, reason: 'Áo bị chật, muốn đổi size');
      expect(reqOk, isTrue);
      expect(fakeService.ordersDb[orderId]!.status, OrderModel.statusReturnRequested);
      expect(fakeService.ordersDb[orderId]!.returnReason, 'Áo bị chật, muốn đổi size');

      // 2. Thử nghiệm Admin từ chối trả hàng (rejectReturn)
      final rejectOk = await orderProvider.rejectReturn(orderId, reason: 'Đã quá 7 ngày theo quy định');
      expect(rejectOk, isTrue);
      expect(fakeService.ordersDb[orderId]!.status, OrderModel.statusDelivered); // Khôi phục Delivered

      // 3. Khách gửi lại yêu cầu và Admin chấp thuận (approveReturn)
      await orderProvider.requestReturn(orderId, reason: 'Áo bị lỗi chỉ');
      final approveOk = await orderProvider.approveReturn(orderId);
      expect(approveOk, isTrue);

      final returnedOrder = fakeService.ordersDb[orderId]!;
      expect(returnedOrder.status, OrderModel.statusReturned);
      expect(returnedOrder.paymentStatus, OrderModel.paymentRefunded);

      // Kho được hoàn lại 8 + 2 = 10
      expect(fakeService.productsDb['prod_001']!.stock, 10);
    });

    test('12. Chu trình đối soát thanh toán VietQR Napas247', () async {
      final orderId = await orderProvider.createOrder(
        userId: 'user_vietqr_01',
        userName: 'Khách VietQR',
        phone: '0901111111',
        shippingAddress: 'Hà Nội',
        items: sampleItems,
        subtotal: 400000,
        voucherCode: '',
        discountAmount: 0,
        totalPrice: 400000,
        paymentMethod: 'VIETQR',
      );

      // 1. Khách bấm "Tôi đã chuyển khoản"
      final submitOk = await orderProvider.confirmPaymentSubmitted(
        orderId!,
        transactionRef: 'FT2410269999',
      );
      expect(submitOk, isTrue);
      expect(fakeService.ordersDb[orderId]!.paymentStatus, OrderModel.paymentSubmitted);
      expect(fakeService.ordersDb[orderId]!.transactionRef, 'FT2410269999');

      // 2. Admin kiểm tra thấy chưa vào tiền -> Từ chối
      final rejectOk = await orderProvider.rejectPaymentSubmitted(orderId, reason: 'Chưa thấy giao dịch trong sao kê');
      expect(rejectOk, isTrue);
      expect(fakeService.ordersDb[orderId]!.paymentStatus, OrderModel.paymentUnpaid);

      // 3. Khách chuyển lại và Admin duyệt thành công
      await orderProvider.confirmPaymentSubmitted(orderId, transactionRef: 'FT2410268888');
      final paidOk = await orderProvider.confirmPaymentPaid(orderId);
      expect(paidOk, isTrue);
      expect(fakeService.ordersDb[orderId]!.paymentStatus, OrderModel.paymentPaid);
    });

    test('13. Khóa Bẫy 13: resetSession dọn sạch toàn bộ RAM khi đăng xuất', () {
      orderProvider.setMockUserOrders([
        OrderModel(
          orderId: 'ORD_TEMP_01',
          userId: 'user_X',
          userName: 'Khách X',
          phone: '0901',
          shippingAddress: 'HN',
          items: sampleItems,
          subtotal: 400000,
          totalPrice: 400000,
          createdAt: DateTime.now(),
        ),
      ]);
      orderProvider.setMockAllOrders([
        OrderModel(
          orderId: 'ORD_TEMP_02',
          userId: 'user_Y',
          userName: 'Khách Y',
          phone: '0902',
          shippingAddress: 'SG',
          items: sampleItems,
          subtotal: 400000,
          totalPrice: 400000,
          createdAt: DateTime.now(),
        ),
      ]);

      expect(orderProvider.userOrders, isNotEmpty);
      expect(orderProvider.allOrders, isNotEmpty);

      // Đăng xuất
      orderProvider.resetSession();

      expect(orderProvider.userOrders, isEmpty);
      expect(orderProvider.allOrders, isEmpty);
      expect(orderProvider.activeUserId, isNull);
      expect(orderProvider.errorMessage, isNull);
      expect(orderProvider.isLoading, isFalse);
    });

    test('14. Optimistic UI: Các thao tác cập nhật trạng thái lập tức phản ánh lên userOrders trong bộ nhớ', () async {
      final initialOrder = OrderModel(
        orderId: 'ORD_OPTIMISTIC_01',
        userId: 'user_test_01',
        userName: 'Nguyễn Văn Test',
        phone: '0901234567',
        shippingAddress: '123 Đường Fashion',
        items: sampleItems,
        subtotal: 400000,
        totalPrice: 400000,
        status: OrderModel.statusPending,
        paymentStatus: OrderModel.paymentUnpaid,
        createdAt: DateTime.now(),
      );

      // Lưu đơn vào mock database và gán vào RAM
      fakeService.ordersDb['ORD_OPTIMISTIC_01'] = initialOrder;
      orderProvider.setMockUserOrders([initialOrder]);

      // 1. Cập nhật thông tin nhận hàng -> Lập tức phản ánh lên RAM
      await orderProvider.updateShippingInfo(
        orderId: 'ORD_OPTIMISTIC_01',
        newAddress: '456 Phố Mới, Cầu Giấy, Hà Nội',
        phone: '0988776655',
        recipientName: 'Người Nhận Mới',
      );
      expect(orderProvider.userOrders.first.shippingAddress, '456 Phố Mới, Cầu Giấy, Hà Nội');
      expect(orderProvider.userOrders.first.phone, '0988776655');
      expect(orderProvider.userOrders.first.userName, 'Người Nhận Mới');

      // 2. Chuyển sang Delivered -> Tự động đổi trạng thái và paymentStatus = Paid
      await orderProvider.updateOrderStatus(
        orderId: 'ORD_OPTIMISTIC_01',
        newStatus: OrderModel.statusDelivered,
        userId: 'user_test_01',
      );
      expect(orderProvider.userOrders.first.status, OrderModel.statusDelivered);
      expect(orderProvider.userOrders.first.paymentStatus, OrderModel.paymentPaid);

      // 3. Khách yêu cầu đổi trả -> Lập tức phản ánh ReturnRequested
      await orderProvider.requestReturn('ORD_OPTIMISTIC_01', reason: 'Không vừa');
      expect(orderProvider.userOrders.first.status, OrderModel.statusReturnRequested);
    });
  });
}
