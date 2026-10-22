import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/core/constants/app_constants.dart';
import 'package:fashion_store_app/screens/cart/widgets/vietqr_dialog.dart';

void main() {
  group('Kiểm thử VietQR & VietQrPaymentDialog (PRM393 - Member 4)', () {
    test('Hàm generateVietQrUrl sinh đúng chuẩn VietQR Napas247 URL', () {
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

    testWidgets('VietQrPaymentDialog hiển thị đúng thông tin ngân hàng & mã đơn hàng',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool isFinished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VietQrPaymentDialog(
              orderId: 'ORD_TEST_9999',
              totalPrice: 450000,
              onFinished: () {
                isFinished = true;
              },
            ),
          ),
        ),
      );

      // Kiểm tra tiêu đề ĐẶT HÀNG THÀNH CÔNG!
      expect(find.text('ĐẶT HÀNG THÀNH CÔNG!'), findsOneWidget);

      // Kiểm tra hiển thị cổng VietQR Napas247
      expect(find.text('CỔNG THANH TOÁN VIETQR • NAPAS 24/7'), findsOneWidget);

      // Kiểm tra hiển thị STK ngân hàng
      expect(find.text(AppConstants.bankAccountNo), findsOneWidget);

      // Kiểm tra hiển thị tên ngân hàng
      expect(find.text(AppConstants.bankName), findsOneWidget);

      // Kiểm tra nút XEM ĐƠN HÀNG CỦA TÔI
      final finishBtn = find.text('XEM ĐƠN HÀNG CỦA TÔI');
      expect(finishBtn, findsOneWidget);

      // Bấm nút XEM ĐƠN HÀNG CỦA TÔI
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();

      expect(isFinished, true);
    });
  });
}
