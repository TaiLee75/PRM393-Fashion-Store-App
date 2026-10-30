import 'dart:convert';
import 'dart:io';
import '../core/constants/app_constants.dart';

/// Kết quả kiểm tra đối soát giao dịch từ SePay
class SepayCheckResult {
  final bool isSuccess;
  final String message;
  final Map<String, dynamic>? transaction;

  const SepayCheckResult({
    required this.isSuccess,
    required this.message,
    this.transaction,
  });
}

/// Dịch vụ đối soát biến động số dư ngân hàng tự động thời gian thực qua Cổng SePay Open Banking
class SepayService {
  static const String _endpoint = 'https://my.sepay.vn/userapi/transactions/list?limit=20';

  // Mock function phục vụ unit/widget test môi trường không có internet
  static Future<SepayCheckResult>? Function(String orderId, num expectedAmount)? mockCheckHandler;

  /// Kiểm tra xem tài khoản ngân hàng đã nhận được tiền cho đơn hàng hay chưa:
  /// - [orderId]: Mã đơn hàng (ví dụ: 'FRAUANTE' hoặc 'DH FRAUANTE')
  /// - [expectedAmount]: Số tiền cần thanh toán
  static Future<SepayCheckResult> checkOrderPaid({
    required String orderId,
    required num expectedAmount,
  }) async {
    // Nếu có mock handler (khi chạy unit/widget test)
    if (mockCheckHandler != null) {
      final mockRes = await mockCheckHandler!(orderId, expectedAmount);
      if (mockRes != null) return mockRes;
    }

    final token = AppConstants.sepayApiToken.trim();
    if (token.isEmpty) {
      return const SepayCheckResult(
        isSuccess: false,
        message: 'Chưa cấu hình SePay API Token trong hệ thống.',
      );
    }

    final cleanOrderId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await client.getUrl(Uri.parse(_endpoint));
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Content-Type', 'application/json');

      final response = await request.close();
      if (response.statusCode != 200) {
        return SepayCheckResult(
          isSuccess: false,
          message: 'Lỗi máy chủ SePay (HTTP ${response.statusCode}). Vui lòng thử lại sau giây lát.',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data['transactions'] is List) {
        final transactions = data['transactions'] as List;
        bool foundOrderWithLowerAmount = false;
        num receivedAmount = 0;

        for (final item in transactions) {
          if (item is Map) {
            final content = (item['transaction_content'] ?? '').toString().toUpperCase();
            final amountIn = num.tryParse((item['amount_in'] ?? '0').toString()) ?? 0;

            // Kiểm tra nội dung chuyển khoản chứa mã đơn hàng
            if (content.contains(cleanOrderId)) {
              if (amountIn >= expectedAmount) {
                return SepayCheckResult(
                  isSuccess: true,
                  message: 'Đã xác nhận nhận tiền thành công từ MBBank!',
                  transaction: Map<String, dynamic>.from(item),
                );
              } else {
                foundOrderWithLowerAmount = true;
                receivedAmount = amountIn;
              }
            }
          }
        }

        if (foundOrderWithLowerAmount) {
          return SepayCheckResult(
            isSuccess: false,
            message: 'MBBank đã nhận được ${receivedAmount.toInt()}đ nhưng chưa đủ số tiền đơn hàng (${expectedAmount.toInt()}đ).',
          );
        }
      }

      return const SepayCheckResult(
        isSuccess: false,
        message: 'Tài khoản MBBank chưa ghi nhận giao dịch cho đơn hàng này. Vui lòng hoàn tất chuyển khoản trên App Ngân hàng trước.',
      );
    } catch (e) {
      return SepayCheckResult(
        isSuccess: false,
        message: 'Không thể kết nối đến cổng SePay: ${e.toString()}',
      );
    } finally {
      client.close();
    }
  }
}
