import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/screens/auth/login_screen.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';

void main() {
  testWidgets('Kiểm thử Giao diện (Widget Test) màn hình LoginScreen thật',
      (WidgetTester tester) async {
    // Render màn hình LoginScreen bọc trong AuthProvider
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Kiểm tra có ô nhập Email và Mật khẩu hay không
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Kiểm tra có nút Đăng nhập thông thường hay không
    expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);

    // Kiểm tra có nút Đăng nhập với Google hay không
    expect(find.textContaining('Google'), findsOneWidget);
  });
}
