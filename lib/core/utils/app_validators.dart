/// Bộ tiện ích kiểm tra tính hợp lệ dữ liệu (Form Validation) chuẩn nghiệp vụ
class AppValidators {
  AppValidators._();

  // Biểu thức chính quy (Regex) chuẩn RFC cho Email
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Biểu thức chính quy cho Số điện thoại Việt Nam (10 chữ số, bắt đầu bằng 03, 05, 07, 08, 09)
  static final RegExp _phoneRegExp = RegExp(
    r'^(03|05|07|08|09)\d{8}$',
  );

  // Biểu thức chính quy kiểm tra URL hình ảnh hoặc liên kết web
  static final RegExp _urlRegExp = RegExp(
    r'^(http|https):\/\/[^ "]+$',
  );

  /// Kiểm tra Email hợp lệ
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Email không đúng định dạng (VD: name@domain.com)';
    }
    return null;
  }

  /// Kiểm tra Số điện thoại Việt Nam (10 số, đúng đầu số nhà mạng)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    final cleanPhone = value.trim().replaceAll(' ', '');
    if (!_phoneRegExp.hasMatch(cleanPhone)) {
      return 'Số điện thoại phải gồm 10 số (VD: 0901234567)';
    }
    return null;
  }

  /// Kiểm tra Mật khẩu (Tối thiểu 6 ký tự)
  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 6) {
      return 'Mật khẩu phải chứa ít nhất 6 ký tự';
    }
    return null;
  }

  /// Kiểm tra Mật khẩu xác nhận trùng khớp
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập lại mật khẩu xác nhận';
    }
    if (value != password) {
      return 'Mật khẩu xác nhận không trùng khớp';
    }
    return null;
  }

  /// Kiểm tra trường bắt buộc không được để trống
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    return null;
  }

  /// Kiểm tra đơn giá bán sản phẩm (Số dương > 0)
  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập giá sản phẩm';
    }
    final clean = value.trim();
    if (clean.contains('-')) {
      return 'Giá bán phải là số dương lớn hơn 0';
    }
    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9]'), '');
    final num? price = num.tryParse(digitsOnly);
    if (price == null || price <= 0) {
      return 'Giá bán phải là số dương lớn hơn 0';
    }
    final invalidChars = clean.replaceAll(RegExp(r'[0-9.,\sđVNDvnd]'), '');
    if (invalidChars.isNotEmpty) {
      return 'Giá bán không được chứa ký tự không hợp lệ';
    }
    return null;
  }

  /// Kiểm tra đường dẫn URL hình ảnh
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập link hình ảnh';
    }
    if (!_urlRegExp.hasMatch(value.trim())) {
      return 'Đường dẫn phải bắt đầu bằng http:// hoặc https://';
    }
    return null;
  }

  /// Kiểm tra độ dài tối thiểu của chuỗi (như nội dung review, mô tả)
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    if (value.trim().length < minLength) {
      return '$fieldName phải có ít nhất $minLength ký tự';
    }
    return null;
  }
}
