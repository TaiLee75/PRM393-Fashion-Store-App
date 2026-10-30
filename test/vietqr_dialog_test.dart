import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/core/constants/app_constants.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/cart/widgets/vietqr_dialog.dart';
import 'package:fashion_store_app/services/firestore_service.dart';
import 'package:fashion_store_app/services/sepay_service.dart';

import 'dart:async';

class FakeFirestoreServiceForVietQr extends FirestoreService {
  final Map<String, OrderModel> ordersDb = {};
  final Map<String, StreamController<OrderModel?>> controllers = {};

  StreamController<OrderModel?> _getController(String orderId) {
    return controllers.putIfAbsent(
      orderId,
      () => StreamController<OrderModel?>.broadcast(),
    );
  }

  @override
  Stream<OrderModel?> streamOrder(String orderId) {
    final controller = _getController(orderId);
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.add(ordersDb[orderId]);
      }
    });
    return controller.stream;
  }

  @override
  Future<void> confirmPaymentPaid(String orderId) async {
    final current = ordersDb[orderId];
    if (current != null) {
      final updated = current.copyWith(paymentStatus: OrderModel.paymentPaid);
      ordersDb[orderId] = updated;
      final controller = _getController(orderId);
      if (!controller.isClosed) {
        controller.add(updated);
      }
    }
  }

  @override
  Future<void> confirmPaymentSubmitted(String orderId, {String? transactionRef}) async {
    final current = ordersDb[orderId];
    if (current != null) {
      final updated = current.copyWith(
        paymentStatus: OrderModel.paymentSubmitted,
      );
      ordersDb[orderId] = updated;
      final controller = _getController(orderId);
      if (!controller.isClosed) {
        controller.add(updated);
      }
    }
  }

  void dispose() {
    for (final c in controllers.values) {
      c.close();
    }
    controllers.clear();
  }
}

void main() {
  group('Kiểm thử Toàn diện VietQR Napas247 & VietQrPaymentDialog (Task 4.4):', () {
    late FakeFirestoreServiceForVietQr fakeFirestoreService;
    late OrderProvider orderProvider;

    final sampleOrder = OrderModel(
      orderId: 'ORD_TEST_9999',
      userId: 'user_001',
      userName: 'Khách hàng Test',
      phone: '0901234567',
      shippingAddress: '123 Đường Thời Trang, Hà Nội',
      items: const [
        CartItemModel(
          cartItemId: 'item_1',
          productId: 'prod_1',
          productName: 'Áo Thun Lifewear',
          imageUrl: 'https://example.com/tee.jpg',
          price: 450000,
          size: 'L',
          color: 'Trắng',
          quantity: 1,
        ),
      ],
      subtotal: 450000,
      totalPrice: 450000,
      status: 'Pending',
      paymentMethod: 'VIETQR',
      paymentStatus: 'Unpaid',
      createdAt: DateTime.now(),
    );

    setUp(() {
      fakeFirestoreService = FakeFirestoreServiceForVietQr();
      fakeFirestoreService.ordersDb[sampleOrder.orderId] = sampleOrder;
      orderProvider = OrderProvider(firestoreService: fakeFirestoreService);
    });

    Widget buildTestableDialog({
      bool isFromCheckout = true,
      VoidCallback? onFinished,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VietQrPaymentDialog(
              orderId: sampleOrder.orderId,
              totalPrice: sampleOrder.totalPrice,
              isFromCheckout: isFromCheckout,
              onFinished: onFinished,
            ),
          ),
        ),
      );
    }

    test('1. Hàm generateVietQrUrl sinh đúng chuẩn VietQR Napas247 URL', () {
      final url = AppConstants.generateVietQrUrl(
        amount: 350000,
        orderId: 'ORDER12345678',
      );

      expect(url.contains('https://img.vietqr.io/image/'), true);
      expect(url.contains(AppConstants.bankId), true);
      expect(url.contains(AppConstants.bankAccountNo), true);
      expect(url.contains('amount=350000'), true);
      expect(url.contains('addInfo=DH%20ORDER123'), true);
    });

    testWidgets('2. VietQrPaymentDialog (isFromCheckout = true) hiển thị ĐẶT HÀNG THÀNH CÔNG và thông tin STK',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool isFinished = false;

      await tester.pumpWidget(
        buildTestableDialog(
          isFromCheckout: true,
          onFinished: () => isFinished = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tiêu đề khi đặt hàng từ Checkout
      expect(find.text('ĐẶT HÀNG THÀNH CÔNG!'), findsOneWidget);

      // Cổng Napas 24/7
      expect(find.text('CỔNG THANH TOÁN VIETQR • NAPAS 24/7'), findsOneWidget);

      // Số tài khoản và Tên ngân hàng
      expect(find.text(AppConstants.bankAccountNo), findsOneWidget);
      expect(find.text(AppConstants.bankName), findsOneWidget);

      // Nút XEM ĐƠN HÀNG CỦA TÔI
      final finishBtn = find.text('XEM ĐƠN HÀNG CỦA TÔI');
      expect(finishBtn, findsOneWidget);
      await tester.tap(finishBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(isFinished, true);
    });

    testWidgets('3. VietQrPaymentDialog (isFromCheckout = false) hiển thị tiêu đề THANH TOÁN ĐƠN HÀNG',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableDialog(isFromCheckout: false),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tiêu đề khi mở từ chi tiết đơn hàng
      expect(find.text('THANH TOÁN ĐƠN HÀNG'), findsOneWidget);
      expect(find.text('ĐẶT HÀNG THÀNH CÔNG!'), findsNothing);
    });

    tearDown(() {
      SepayService.mockCheckHandler = null;
      fakeFirestoreService.dispose();
    });

    testWidgets('4. Khi đơn hàng chuyển sang Paid (Live Stream / SePay), hiển thị THANH TOÁN THÀNH CÔNG',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool isFinished = false;

      await tester.pumpWidget(
        buildTestableDialog(
          onFinished: () => isFinished = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ban đầu hiển thị dialog với nút XEM ĐƠN HÀNG CỦA TÔI
      expect(find.text('XEM ĐƠN HÀNG CỦA TÔI'), findsOneWidget);

      // Kích hoạt thanh toán thành công
      await orderProvider.confirmPaymentPaid(sampleOrder.orderId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra chuyển sang màn hình THANH TOÁN THÀNH CÔNG!
      expect(find.text('THANH TOÁN THÀNH CÔNG!'), findsOneWidget);

      // Đợi hoàn tất bộ đếm 1.5s tự động đóng dialog
      await tester.pump(const Duration(milliseconds: 1600));
      expect(isFinished, true);
    });

    testWidgets('5. Hiển thị Đồng hồ đếm ngược và Màn hình Hết hạn khi đơn quá thời gian 2 phút',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 5a. Đơn hàng còn trong hạn thanh toán (vừa tạo)
      await tester.pumpWidget(
        buildTestableDialog(
          isFromCheckout: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Hiển thị thanh đếm ngược thời gian thanh toán
      expect(find.textContaining('Hạn thanh toán:'), findsOneWidget);

      // 5b. Đơn hàng đã quá hạn thanh toán (tạo từ 3 phút trước)
      final expiredOrder = sampleOrder.copyWith(
        orderId: 'ORD_EXPIRED_001',
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      fakeFirestoreService.ordersDb[expiredOrder.orderId] = expiredOrder;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VietQrPaymentDialog(
                orderId: expiredOrder.orderId,
                totalPrice: expiredOrder.totalPrice,
                isFromCheckout: false,
                createdAt: expiredOrder.createdAt,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Hiển thị màn hình ĐƠN HÀNG ĐÃ HẾT HẠN
      expect(find.text('ĐƠN HÀNG ĐÃ HẾT HẠN'), findsOneWidget);
      expect(find.textContaining('đã quá thời hạn thanh toán (2 phút)'), findsOneWidget);
    });
  });
}
