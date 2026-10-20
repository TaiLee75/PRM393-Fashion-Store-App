import 'package:intl/intl.dart';

/// Các tiện ích định dạng tiền tệ và thời gian chuẩn Việt Nam
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormatter = DateFormat('HH:mm');

  /// Định dạng số tiền sang chuẩn VNĐ (VD: 250000 -> "250.000 ₫")
  static String formatCurrency(num? amount) {
    if (amount == null) return '0 ₫';
    return _currencyFormatter.format(amount);
  }

  /// Định dạng ngày giờ đầy đủ (VD: "20/10/2026 14:30")
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateTimeFormatter.format(dateTime.toLocal());
  }

  /// Định dạng chỉ ngày (VD: "20/10/2026")
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateFormatter.format(dateTime.toLocal());
  }

  /// Định dạng chỉ giờ (VD: "14:30")
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _timeFormatter.format(dateTime.toLocal());
  }

  /// Định dạng thời gian tương đối cho tin nhắn / thông báo
  static String formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return formatDate(dateTime);
    }
  }
}
