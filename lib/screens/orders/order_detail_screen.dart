import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../cart/widgets/vietqr_dialog.dart';
import '../chat/chat_screen.dart';

/// Màn hình Chi tiết Đơn hàng: Xem hóa đơn chi tiết, tiến trình giao hàng (Stepper) và thanh toán VietQR
class OrderDetailScreen extends StatelessWidget {
  final OrderModel initialOrder;

  const OrderDetailScreen({
    super.key,
    required this.initialOrder,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.userOrders.firstWhere(
      (o) => o.orderId == initialOrder.orderId,
      orElse: () => initialOrder,
    );

    final shortOrderId = order.orderId.length > 8
        ? order.orderId.substring(0, 8).toUpperCase()
        : order.orderId.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.ultraLightGrey,
      appBar: AppBar(
        title: Text(
          'ĐƠN HÀNG #$shortOrderId',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TIẾN TRÌNH ĐƠN HÀNG (TIMELINE STEPPER)
            _buildTimelineCard(order.status),
            const SizedBox(height: 14),

            // 2. THÔNG TIN GIAO HÀNG
            _buildDeliveryInfoCard(order),
            const SizedBox(height: 14),

            // 3. DANH SÁCH MÓN HÀNG
            _buildItemsListCard(order),
            const SizedBox(height: 14),

            // 4. TÓM TẮT THANH TOÁN & VIETQR
            _buildPaymentSummaryCard(context, order),
            const SizedBox(height: 20),

            // 5. NÚT LIÊN HỆ TƯ VẤN SHOP
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatScreen(isStandalone: true),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text(
                  'LIÊN HỆ SHOP VỀ ĐƠN HÀNG NÀY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Card Timeline Stepper 3 bước (Pending -> Delivering -> Delivered)
  Widget _buildTimelineCard(String status) {
    int currentStep = 1;
    Color statusColor = AppColors.warning;
    String statusTitle = 'Đang chờ shop xác nhận';

    if (status == 'Delivering') {
      currentStep = 2;
      statusColor = Colors.blue;
      statusTitle = 'Đơn hàng đang trên đường giao';
    } else if (status == 'Delivered') {
      currentStep = 3;
      statusColor = AppColors.success;
      statusTitle = 'Đã giao hàng thành công';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Thanh Stepper ngang
          Row(
            children: [
              _buildStepItem(
                stepIndex: 1,
                label: 'Đặt hàng',
                icon: Icons.receipt_long,
                isActive: currentStep >= 1,
                isCompleted: currentStep > 1,
              ),
              _buildStepLine(isActive: currentStep >= 2),
              _buildStepItem(
                stepIndex: 2,
                label: 'Đang giao',
                icon: Icons.local_shipping,
                isActive: currentStep >= 2,
                isCompleted: currentStep > 2,
              ),
              _buildStepLine(isActive: currentStep >= 3),
              _buildStepItem(
                stepIndex: 3,
                label: 'Đã nhận',
                icon: Icons.check_circle,
                isActive: currentStep >= 3,
                isCompleted: currentStep >= 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int stepIndex,
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isCompleted,
  }) {
    final color = isActive ? AppColors.primary : Colors.grey.shade400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            size: 20,
            color: isActive ? Colors.white : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? AppColors.primary : Colors.grey.shade300,
      ),
    );
  }

  /// Thông tin người nhận
  Widget _buildDeliveryInfoCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'THÔNG TIN GIAO HÀNG',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('Người nhận:', order.userName),
          const SizedBox(height: 6),
          _buildInfoRow('Số điện thoại:', order.phone),
          const SizedBox(height: 6),
          _buildInfoRow('Địa chỉ nhận hàng:', order.shippingAddress),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Thời gian đặt hàng:',
            AppFormatters.formatDateTime(order.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Danh sách sản phẩm trong hóa đơn
  Widget _buildItemsListCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DANH SÁCH MÓN HÀNG',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${order.items.length} sản phẩm',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Divider(height: 20),
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.ultraLightGrey),
                      errorWidget: (_, __, ___) => const Icon(Icons.image, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Size: ${item.size}  |  Màu: ${item.color}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppFormatters.formatCurrency(item.price)} x ${item.quantity}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppFormatters.formatCurrency(item.itemTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Tóm tắt chi phí thanh toán
  Widget _buildPaymentSummaryCard(BuildContext context, OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHI TIẾT THANH TOÁN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tạm tính tiền hàng:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(AppFormatters.formatCurrency(order.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chiết khấu Voucher (${order.voucherCode}):',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary),
                ),
                Text(
                  '-${AppFormatters.formatCurrency(order.discountAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hình thức thanh toán:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                order.paymentMethod == 'VIETQR' ? 'Chuyển khoản VietQR' : 'Tiền mặt (COD)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng cộng thanh toán:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                AppFormatters.formatCurrency(order.totalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.priceHighlight,
                ),
              ),
            ],
          ),

          // Nút mở lại mã VietQR
          if (order.paymentMethod == 'VIETQR') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => VietQrPaymentDialog(
                      orderId: order.orderId,
                      totalPrice: order.totalPrice,
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_2, size: 20),
                label: const Text(
                  'MỞ MÃ QR THANH TOÁN (NAPAS 24/7)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
