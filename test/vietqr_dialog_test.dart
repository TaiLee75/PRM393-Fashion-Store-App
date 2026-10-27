import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/core/constants/app_constants.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/order_model.dart';
import 'package:fashion_store_app/providers/order_provider.dart';
import 'package:fashion_store_app/screens/cart/widgets/vietqr_dialog.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

class FakeFirestoreServiceForVietQr extends FirestoreService {
  final Map<String, OrderModel> ordersDb = {};

  @override
  Stream<OrderModel?> streamOrder(String orderId) {
    return Stream.value(ordersDb[orderId]);
  }

  @override
  Future<void> confirmPaymentPaid(String orderId) async {
    final current = ordersDb[orderId];
    if (current != null) {
      ordersDb[orderId] = current.copyWith(paymentStatus: OrderModel.paymentPaid);
    }
  }

  @override
  Future<void> confirmPaymentSubmitted(String orderId, {String? transactionRef}) async {
    final current = ordersDb[orderId];
    if (current != null) {
      ordersDb[orderId] = current.copyWith(
        paymentStatus: OrderModel.paymentSubmitted,
      );
    }
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

    testWidgets('4. Bấm "TÔI ĐÃ CHUYỂN KHOẢN" mở Popup nhập mã giao dịch và cập nhật PaymentSubmitted',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableDialog());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Nút TÔI ĐÃ CHUYỂN KHOẢN
      final transferBtn = find.text('TÔI ĐÃ CHUYỂN KHOẢN');
      expect(transferBtn, findsOneWidget);
      await tester.tap(transferBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Popup xác nhận mở lên
      expect(find.text('Xác nhận đã chuyển khoản'), findsOneWidget);

      // Nhập mã giao dịch ngân hàng
      final refInput = find.widgetWithText(TextField, 'Mã giao dịch ngân hàng');
      expect(refInput, findsOneWidget);
      await tester.enterText(refInput, 'FT260999888');

      // Bấm Xác nhận gửi
      final confirmBtn = find.text('Xác nhận gửi');
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trạng thái đã gửi thông báo thành công
      expect(
        find.textContaining('Đã gửi thông báo chuyển khoản thành công'),
        findsOneWidget,
      );

      // Hiển thị badge chờ shop duyệt
      expect(
        find.textContaining('Đã gửi xác nhận chuyển khoản. Hệ thống sẽ tự động đóng khi Shop duyệt!'),
        findsOneWidget,
      );
    });

    testWidgets('5. Hiển thị Nút Sandbox Demo Mode phục vụ Hội đồng Chấm điểm',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableDialog());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Nút Giả lập Webhook Ngân hàng (Demo)
      expect(find.textContaining('Giả lập Webhook Ngân hàng (Demo)'), findsOneWidget);
    });
  });
}
