import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/screens/profile/edit_profile_screen.dart';

void main() {
  testWidgets('Kiểm thử Giao diện (Widget Test) màn hình EditProfileScreen',
      (WidgetTester tester) async {
    // Đặt viewport kích thước chuẩn điện thoại dài để thấy trọn vẹn cả Form và nút Lưu
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: EditProfileScreen(),
        ),
      ),
    );

    // Kiểm tra có ít nhất 4 ô nhập liệu (Họ tên, SĐT, Địa chỉ, Avatar URL)
    expect(find.byType(TextFormField), findsNWidgets(4));

    // Kiểm tra có nhãn trường Họ tên, SĐT và Địa chỉ
    expect(find.textContaining('Họ và tên'), findsOneWidget);
    expect(find.textContaining('Số điện thoại'), findsOneWidget);
    expect(find.textContaining('Địa chỉ nhận hàng'), findsOneWidget);

    // Kiểm tra có nút Lưu thay đổi hồ sơ
    expect(find.textContaining('LƯU THAY ĐỔI'), findsOneWidget);
  });
}
