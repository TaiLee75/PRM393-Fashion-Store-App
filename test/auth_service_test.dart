import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/services/auth_service.dart';

void main() {
  group('AuthService Unit Tests (Task 1.4)', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('AuthService initializes cleanly without throwing exceptions', () {
      expect(authService, isNotNull);
      // Khi chưa đăng nhập (môi trường test không có Firebase instance thật)
      expect(authService.currentUser, isNull);
      expect(authService.isPasswordProvider, isFalse);
      expect(authService.isGoogleProvider, isFalse);
    });

    test('changePassword throws when user is not logged in', () async {
      expect(
        () => authService.changePassword(
          currentPassword: 'oldPassword123',
          newPassword: 'newPassword123',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Người dùng chưa đăng nhập'),
          ),
        ),
      );
    });

    test('sendPasswordResetEmail validates email inputs properly', () async {
      // Empty email
      expect(
        () => authService.sendPasswordResetEmail(''),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Vui lòng nhập địa chỉ email'),
          ),
        ),
      );

      // Whitespace only email
      expect(
        () => authService.sendPasswordResetEmail('   '),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Vui lòng nhập địa chỉ email'),
          ),
        ),
      );

      // Invalid email format
      expect(
        () => authService.sendPasswordResetEmail('invalid-email-format'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Địa chỉ email không đúng định dạng'),
          ),
        ),
      );
    });

    test('valid email formats pass regex check', () {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      expect(emailRegex.hasMatch('student@fpt.edu.vn'), isTrue);
      expect(emailRegex.hasMatch('customer@uniqlo.fashion'), isTrue);
      expect(emailRegex.hasMatch('test.user+tag@gmail.com'), isTrue);
      expect(emailRegex.hasMatch('plainaddress'), isFalse);
      expect(emailRegex.hasMatch('@missingusername.com'), isFalse);
    });

    test('signOut executes gracefully without unhandled crashes', () async {
      // Should not throw even if Firebase or GoogleSignIn is not initialized
      await expectLater(authService.signOut(), completes);
    });
  });
}
