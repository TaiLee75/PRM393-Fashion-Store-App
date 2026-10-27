import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/screens/auth/login_screen.dart';
import 'package:fashion_store_app/services/auth_service.dart';

class FakeAuthServiceForLogin extends AuthService {
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();
  bool sendResetSuccess = true;
  String? lastResetEmail;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastResetEmail = email;
    if (!sendResetSuccess) {
      throw Exception('Email không tồn tại trong hệ thống.');
    }
  }
}

void main() {
  group('Kiểm thử Giao diện (Widget Test) LoginScreen & Quên mật khẩu (Task 4.4):', () {
    late FakeAuthServiceForLogin fakeAuthService;
    late AuthProvider authProvider;

    setUp(() {
      fakeAuthService = FakeAuthServiceForLogin();
      authProvider = AuthProvider(authService: fakeAuthService);
    });

    testWidgets('1. LoginScreen hiển thị đầy đủ các thành phần giao diện Uniqlo Style',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Logo và tiêu đề
      expect(find.text('PRM'), findsOneWidget);
      expect(find.text('STORE'), findsOneWidget);
      expect(find.text('ĐĂNG NHẬP'), findsOneWidget);

      // Các trường nhập liệu Email và Mật khẩu
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);

      // Nút Quên mật khẩu
      expect(find.text('Quên mật khẩu?'), findsOneWidget);

      // Nút Đăng nhập và Đăng nhập Google
      expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);
      expect(find.textContaining('Google'), findsOneWidget);

      // Liên kết Đăng ký
      expect(find.text('Đăng ký ngay'), findsOneWidget);
    });

    testWidgets('2. Validation báo lỗi khi để trống Email hoặc Mật khẩu trên màn hình đăng nhập',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Bấm nút Đăng nhập khi chưa điền gì
      final loginBtn = find.widgetWithText(ElevatedButton, 'Đăng nhập');
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Kiểm tra thông báo lỗi validation
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    });

    testWidgets('3. Bấm "Quên mật khẩu?" mở ModalBottomSheet đầy đủ tiêu đề, mô tả và ô nhập email',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Bấm vào "Quên mật khẩu?"
      final forgotBtn = find.text('Quên mật khẩu?');
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề ModalBottomSheet
      expect(find.text('QUÊN MẬT KHẨU'), findsOneWidget);
      expect(
        find.text('Nhập email tài khoản của bạn để nhận liên kết đặt lại mật khẩu từ hệ thống.'),
        findsOneWidget,
      );

      // Kiểm tra có ô nhập email và nút gửi liên kết
      expect(find.widgetWithText(TextFormField, 'Email của bạn *'), findsOneWidget);
      expect(find.text('GỬI LIÊN KẾT ĐẶT LẠI MẬT KHẨU'), findsOneWidget);
    });

    testWidgets('4. Validation báo lỗi khi để trống email trong Sheet Quên mật khẩu',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Mở BottomSheet
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();

      // Bấm nút gửi ngay mà không nhập email
      final submitBtn = find.text('GỬI LIÊN KẾT ĐẶT LẠI MẬT KHẨU');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Hiển thị lỗi validation
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
    });

    testWidgets('5. Bấm nút đóng (close icon) đóng ModalBottomSheet thành công',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Mở BottomSheet
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      expect(find.text('QUÊN MẬT KHẨU'), findsOneWidget);

      // Bấm nút đóng
      final closeBtn = find.byIcon(Icons.close);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Sheet đã đóng, quay lại màn hình Login
      expect(find.text('QUÊN MẬT KHẨU'), findsNothing);
      expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
    });

    testWidgets('6. Nhập email hợp lệ và gửi liên kết đặt lại mật khẩu thành công đóng sheet và hiển thị SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Mở BottomSheet
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();

      // Nhập email
      final emailInput = find.widgetWithText(TextFormField, 'Email của bạn *');
      await tester.enterText(emailInput, 'user@example.com');

      // Bấm nút gửi
      final submitBtn = find.text('GỬI LIÊN KẾT ĐẶT LẠI MẬT KHẨU');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Sheet đã đóng
      expect(find.text('QUÊN MẬT KHẨU'), findsNothing);

      // Hiển thị SnackBar thành công
      expect(find.textContaining('Đã gửi liên kết khôi phục tới user@example.com'), findsOneWidget);
      expect(fakeAuthService.lastResetEmail, 'user@example.com');
    });
  });
}
