import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';

/// Hộp thoại thanh toán qua Cổng VietQR Napas247 động
class VietQrPaymentDialog extends StatelessWidget {
  final String orderId;
  final num totalPrice;
  final VoidCallback? onFinished;

  const VietQrPaymentDialog({
    super.key,
    required this.orderId,
    required this.totalPrice,
    this.onFinished,
  });

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Đã sao chép $label: $text'),
        backgroundColor: AppColors.black,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortOrderId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
    final transferContent = 'DH $shortOrderId';
    final qrUrl = AppConstants.generateVietQrUrl(
      amount: totalPrice,
      orderId: orderId,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ĐẶT HÀNG THÀNH CÔNG!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Mã đơn hàng: #$shortOrderId',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Banner Napas VietQR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.ultraLightGrey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'CỔNG THANH TOÁN VIETQR • NAPAS 24/7',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Ảnh QR Code động
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: qrUrl,
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox(
                    width: 220,
                    height: 220,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 54, color: Colors.grey),
                        SizedBox(height: 6),
                        Text(
                          'Không thể tải mã QR',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Quét mã bằng ứng dụng Ngân hàng bất kỳ để tự động điền STK & Số tiền',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            // Card chi tiết thông tin chuyển khoản kèm nút Copy
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ultraLightGrey,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    label: 'Ngân hàng:',
                    value: AppConstants.bankName,
                    onCopy: null,
                  ),
                  const Divider(height: 12),
                  _buildInfoRow(
                    label: 'Chủ tài khoản:',
                    value: AppConstants.bankAccountName,
                    onCopy: null,
                  ),
                  const Divider(height: 12),
                  _buildInfoRow(
                    label: 'Số tài khoản:',
                    value: AppConstants.bankAccountNo,
                    onCopy: () => _copy(
                      context,
                      AppConstants.bankAccountNo,
                      'Số tài khoản',
                    ),
                    highlightValue: true,
                  ),
                  const Divider(height: 12),
                  _buildInfoRow(
                    label: 'Số tiền:',
                    value: AppFormatters.formatCurrency(totalPrice),
                    onCopy: () => _copy(
                      context,
                      '${totalPrice.toInt()}',
                      'Số tiền',
                    ),
                    highlightValue: true,
                    valueColor: AppColors.priceHighlight,
                  ),
                  const Divider(height: 12),
                  _buildInfoRow(
                    label: 'Nội dung CK:',
                    value: transferContent,
                    onCopy: () => _copy(
                      context,
                      transferContent,
                      'Nội dung chuyển khoản',
                    ),
                    highlightValue: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Nút Xem đơn hàng
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onFinished?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'XEM ĐƠN HÀNG CỦA TÔI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    VoidCallback? onCopy,
    bool highlightValue = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlightValue ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, size: 14, color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}
