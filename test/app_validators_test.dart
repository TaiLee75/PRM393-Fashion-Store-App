import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/core/utils/app_validators.dart';

void main() {
  group('AppValidators Unit Tests', () {
    test('validateEmail - Email hợp lệ và không hợp lệ', () {
      expect(AppValidators.validateEmail('user@domain.com'), isNull);
      expect(AppValidators.validateEmail('student123@fpt.edu.vn'), isNull);
      expect(AppValidators.validateEmail(''), isNotNull);
      expect(AppValidators.validateEmail(null), isNotNull);
      expect(AppValidators.validateEmail('invalid-email'), isNotNull);
      expect(AppValidators.validateEmail('user@domain'), isNotNull);
    });

    test('validatePhone - Số điện thoại Việt Nam 10 chữ số', () {
      expect(AppValidators.validatePhone('0901234567'), isNull);
      expect(AppValidators.validatePhone('0389876543'), isNull);
      expect(AppValidators.validatePhone('0771234567'), isNull);
      expect(AppValidators.validatePhone('0551234567'), isNull);
      expect(AppValidators.validatePhone('0881234567'), isNull);

      // Sai định dạng
      expect(AppValidators.validatePhone('123456789'), isNotNull); // 9 số
      expect(AppValidators.validatePhone('0201234567'), isNotNull); // Đầu 02
      expect(AppValidators.validatePhone('090123456789'), isNotNull); // 12 số
      expect(AppValidators.validatePhone(null), isNotNull);
    });

    test('validatePassword - Mật khẩu tối thiểu 6 ký tự', () {
      expect(AppValidators.validatePassword('123456'), isNull);
      expect(AppValidators.validatePassword('secret123'), isNull);
      expect(AppValidators.validatePassword('12345'), isNotNull);
      expect(AppValidators.validatePassword(''), isNotNull);
      expect(AppValidators.validatePassword(null), isNotNull);
    });

    test('validateConfirmPassword - Kiểm tra trùng khớp mật khẩu', () {
      expect(AppValidators.validateConfirmPassword('123456', '123456'), isNull);
      expect(AppValidators.validateConfirmPassword('123456', '654321'), isNotNull);
      expect(AppValidators.validateConfirmPassword('', '123456'), isNotNull);
    });

    test('validatePrice - Giá bán phải là số dương lớn hơn 0', () {
      expect(AppValidators.validatePrice('150000'), isNull);
      expect(AppValidators.validatePrice('299.000đ'), isNull);
      expect(AppValidators.validatePrice('0'), isNotNull);
      expect(AppValidators.validatePrice('-50000'), isNotNull);
      expect(AppValidators.validatePrice('abc'), isNotNull);
      expect(AppValidators.validatePrice(null), isNotNull);
    });

    test('validateRequired - Trường bắt buộc', () {
      expect(AppValidators.validateRequired('Áo thun', 'Tên sản phẩm'), isNull);
      expect(AppValidators.validateRequired('', 'Tên sản phẩm'), isNotNull);
      expect(AppValidators.validateRequired(null, 'Tên sản phẩm'), isNotNull);
    });

    test('validateUrl - Link hình ảnh hợp lệ', () {
      expect(AppValidators.validateUrl('https://images.unsplash.com/photo-1'), isNull);
      expect(AppValidators.validateUrl('http://example.com/image.jpg'), isNull);
      expect(AppValidators.validateUrl('ftp://example.com'), isNotNull);
      expect(AppValidators.validateUrl('not-a-url'), isNotNull);
    });
  });
}
