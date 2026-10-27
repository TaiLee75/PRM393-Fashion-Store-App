import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../admin/admin_chat_inbox_screen.dart';
import '../cart/widgets/vietqr_dialog.dart';
import '../chat/chat_screen.dart';
import '../main_nav_screen.dart';

/// Màn hình Chi tiết Đơn hàng toàn diện (Task 3.5: Khóa Bẫy 8, 16, 18, 20)
/// Hỗ trợ: Stepper Timeline đa mốc, Hủy đơn (hoàn kho), Đổi/Trả hàng, Đánh giá sản phẩm, Mua lại & Đối soát VietQR
class OrderDetailScreen extends StatefulWidget {
  final OrderModel initialOrder;

  const OrderDetailScreen({
    super.key,
    required this.initialOrder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isProcessing = false;

  // ==========================================
  // CÁC THAO TÁC NGHIỆP VỤ (VÒNG ĐỜI ĐƠN HÀNG)
  // ==========================================

  /// 1. Sửa thông tin nhận hàng (Khi đơn còn ở trạng thái Pending)
  Future<void> _showEditAddressDialog(OrderModel order) async {
    final nameCtrl = TextEditingController(text: order.userName);
    final phoneCtrl = TextEditingController(text: order.phone);
    final addressCtrl = TextEditingController(text: order.shippingAddress);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Sửa thông tin nhận hàng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên người nhận *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 9) ? 'Số điện thoại không hợp lệ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ nhận hàng *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('CẬP NHẬT'),
          ),
        ],
      ),
    );

    final newName = nameCtrl.text.trim();
    final newPhone = phoneCtrl.text.trim();
    final newAddress = addressCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();

    if (updated == true && mounted) {
      setState(() => _isProcessing = true);
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.updateShippingInfo(
        orderId: order.orderId,
        recipientName: newName,
        phone: newPhone,
        newAddress: newAddress,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✅ Cập nhật thông tin nhận hàng thành công!' : '❌ Cập nhật thất bại. Vui lòng thử lại!',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  /// 2. Hủy đơn hàng kèm lý do (Khóa Bẫy 5, 20: Hoàn kho SKU & Tự động Refunded nếu đã thanh toán)
  Future<void> _showCancelOrderDialog(OrderModel order) async {
    String selectedReason = 'Tôi muốn đổi kích cỡ / màu sắc khác';
    final customReasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Xác nhận hủy đơn hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vui lòng chọn lý do bạn muốn hủy đơn hàng này:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                ...[
                  'Tôi muốn đổi kích cỡ / màu sắc khác',
                  'Tôi nhập sai địa chỉ hoặc số điện thoại',
                  'Tôi tìm được sản phẩm khác phù hợp hơn',
                  'Thời gian giao hàng dự kiến quá lâu',
                  'Lý do khác',
                ].map((reason) {
                  final isSelected = selectedReason == reason;
                  return InkWell(
                    onTap: () => setDlgState(() => selectedReason = reason),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.error : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (selectedReason == 'Lý do khác') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customReasonCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Nhập lý do chi tiết của bạn...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('QUAY LẠI', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('HỦY ĐƠN HÀNG'),
            ),
          ],
        ),
      ),
    );

    final customReason = customReasonCtrl.text.trim();
    customReasonCtrl.dispose();

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final finalReason = selectedReason == 'Lý do khác' && customReason.isNotEmpty
          ? customReason
          : selectedReason;

      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.cancelOrder(
        order.orderId,
        cancelReason: finalReason,
        cancelledBy: 'customer',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✅ Đơn hàng đã được hủy thành công!' : '❌ Hủy đơn thất bại. Vui lòng thử lại!',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  /// 3. Khách hàng xác nhận "Đã nhận được hàng" (Chuyển Delivered & auto Paid)
  Future<void> _confirmDelivered(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Đã nhận được hàng?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn đã nhận được toàn bộ kiện hàng và hài lòng với các sản phẩm?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CHƯA NHẬN', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('ĐÃ NHẬN HÀNG'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.updateOrderStatus(
        orderId: order.orderId,
        newStatus: OrderModel.statusDelivered,
        userId: order.userId,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '🎉 Cảm ơn bạn đã mua sắm tại Lifewear!' : '❌ Thao tác thất bại. Vui lòng thử lại!',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  /// 4. Yêu cầu Đổi / Trả hàng (Khi đơn đã Delivered)
  Future<void> _showReturnDialog(OrderModel order) async {
    String selectedReason = 'Mặc không vừa (cần hỗ trợ đổi size)';
    final customReasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text(
            'Yêu cầu Đổi / Trả hàng',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shop hỗ trợ đổi trả trong vòng 7 ngày kể từ khi nhận hàng đối với sản phẩm còn nguyên tem mác:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                ...[
                  'Mặc không vừa (cần hỗ trợ đổi size)',
                  'Sản phẩm bị lỗi, rách hoặc sứt chỉ',
                  'Giao sai mẫu, sai kích thước hoặc màu sắc',
                  'Sản phẩm khác với mô tả trên hình',
                  'Lý do khác',
                ].map((reason) {
                  final isSelected = selectedReason == reason;
                  return InkWell(
                    onTap: () => setDlgState(() => selectedReason = reason),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? Colors.amber.shade800 : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (selectedReason == 'Lý do khác') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customReasonCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Mô tả chi tiết lý do đổi trả...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('QUAY LẠI', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('GỬI YÊU CẦU'),
            ),
          ],
        ),
      ),
    );

    final customReason = customReasonCtrl.text.trim();
    customReasonCtrl.dispose();

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final finalReason = selectedReason == 'Lý do khác' && customReason.isNotEmpty
          ? customReason
          : selectedReason;

      final orderProvider = context.read<OrderProvider>();
      final success = await orderProvider.requestReturn(order.orderId, reason: finalReason);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Đã gửi yêu cầu đổi/trả! Shop sẽ liên hệ với bạn trong vòng 24h.'
                : '❌ Gửi yêu cầu thất bại. Vui lòng thử lại!',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  /// 5. Đánh giá sản phẩm đã mua (Verified Purchase Review)
  Future<void> _showReviewDialog(OrderModel order) async {
    final productProvider = Provider.of<ProductProvider?>(context, listen: false);
    if (productProvider == null || order.items.isEmpty) return;

    for (final item in order.items) {
      if (!mounted) return;
      double selectedRating = 5.0;
      final commentCtrl = TextEditingController();

      final submitted = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: Text(
              'Đánh giá: ${item.productName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Phân loại: ${item.size}, ${item.color}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (starIdx) {
                      final starVal = starIdx + 1.0;
                      return IconButton(
                        icon: Icon(
                          starVal <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () => setDlgState(() => selectedRating = starVal),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Chia sẻ cảm nhận về chất vải, độ vừa vặn và đóng gói...',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('BỎ QUA', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('GỬI ĐÁNH GIÁ'),
              ),
            ],
          ),
        ),
      );

      final commentText = commentCtrl.text.trim();
      commentCtrl.dispose();

      if (submitted == true && mounted) {
        final auth = Provider.of<AuthProvider?>(context, listen: false);
        final authorName = auth?.userFullName.isNotEmpty == true ? auth!.userFullName : order.userName;
        final authorId = auth?.userId.isNotEmpty == true ? auth!.userId : order.userId;

        await productProvider.addReview(
          productId: item.productId,
          userName: authorName,
          rating: selectedRating,
          comment: commentText.isNotEmpty
              ? commentText
              : 'Sản phẩm rất tốt, giao hàng nhanh!',
          userId: authorId,
          orderId: order.orderId,
          variantInfo: '${item.size}, ${item.color}',
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⭐ Cảm ơn bạn đã đánh giá sản phẩm!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// 6. Mua lại đơn này: Kiểm tra tồn kho và thêm vào giỏ hàng
  Future<void> _handleReorder(OrderModel order) async {
    final cartProvider = Provider.of<CartProvider?>(context, listen: false);
    final productProvider = Provider.of<ProductProvider?>(context, listen: false);
    if (cartProvider == null) return;

    int addedCount = 0;
    for (final item in order.items) {
      int? maxStock;
      if (productProvider != null) {
        final product = productProvider.allProducts.where((p) => p.id == item.productId).firstOrNull;
        if (product != null) {
          if (!product.isActive) continue;
          maxStock = product.getStockForVariant(item.size, item.color);
          if (maxStock <= 0) continue;
        }
      }

      cartProvider.addItem(item.copyWith(isSelected: true), maxStock);
      addedCount++;
    }

    if (!mounted) return;

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $addedCount sản phẩm từ đơn hàng vào giỏ!'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'XEM GIỎ HÀNG',
            textColor: Colors.white,
            onPressed: () {
              MainNavScreen.switchToTab(context, 1); // Tab 1: Giỏ hàng
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Các sản phẩm trong đơn hiện đã hết hàng hoặc ngừng kinh doanh!'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Khóa Bẫy 18: Tra cứu live trong cả allOrders (Admin) và userOrders (Khách)
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.allOrders.firstWhere(
      (o) => o.orderId == widget.initialOrder.orderId,
      orElse: () => orderProvider.userOrders.firstWhere(
        (o) => o.orderId == widget.initialOrder.orderId,
        orElse: () => widget.initialOrder,
      ),
    );

    final shortOrderId = order.orderId.length > 8
        ? order.orderId.substring(0, 8).toUpperCase()
        : order.orderId.toUpperCase();

    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final isCurrentAdmin = auth?.isAdmin == true && (auth?.userId != order.userId);

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
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TIẾN TRÌNH ĐƠN HÀNG (TIMELINE STEPPER HOẶC BANNER TRẠNG THÁI)
                  _buildTimelineCard(order),
                  const SizedBox(height: 14),

                  // 2. BỘ NÚT HÀNH ĐỘNG VÒNG ĐỜI ĐƠN HÀNG (HỦY / ĐỔI TRẢ / MUA LẠI / NHẬN HÀNG)
                  _buildOrderActionsCard(order),
                  const SizedBox(height: 14),

                  // 3. THÔNG TIN GIAO HÀNG
                  _buildDeliveryInfoCard(order),
                  const SizedBox(height: 14),

                  // 4. DANH SÁCH MÓN HÀNG
                  _buildItemsListCard(order),
                  const SizedBox(height: 14),

                  // 5. TÓM TẮT THANH TOÁN & VIETQR
                  _buildPaymentSummaryCard(context, order),
                  const SizedBox(height: 20),

                  // 6. NÚT LIÊN HỆ TƯ VẤN (KHÓA BẪY 18: PHÂN BIỆT ADMIN VS KHÁCH HÀNG)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (isCurrentAdmin) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminChatDetailScreen(
                                customerId: order.userId,
                                customerName: order.userName,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatScreen(isStandalone: true),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        isCurrentAdmin ? Icons.support_agent : Icons.chat_bubble_outline,
                        size: 18,
                      ),
                      label: Text(
                        isCurrentAdmin ? 'CHAT VỚI KHÁCH HÀNG NÀY' : 'LIÊN HỆ SHOP VỀ ĐƠN HÀNG NÀY',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  /// Card Timeline Stepper hoặc Banner thông báo cho trạng thái Cancelled / Return
  Widget _buildTimelineCard(OrderModel order) {
    if (order.status == OrderModel.statusCancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cancel, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ĐƠN HÀNG ĐÃ HỦY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: ${order.cancelReason.isNotEmpty ? order.cancelReason : "Khách hàng yêu cầu hủy đơn"}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                  if (order.cancelledAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Thời gian hủy: ${AppFormatters.formatDateTime(order.cancelledAt!)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                  if (order.isRefunded) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '💸 Tiền đã được xử lý hoàn trả cho bạn.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (order.status == OrderModel.statusReturnRequested) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top, color: Colors.amber.shade900, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YÊU CẦU ĐỔI / TRẢ HÀNG',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: ${order.returnReason}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Shop đã tiếp nhận và đang tiến hành thẩm định yêu cầu đổi/trả của bạn.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (order.status == OrderModel.statusReturned) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_return, color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ĐƠN HÀNG ĐÃ HOÀN TRẢ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: ${order.returnReason}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                  if (order.returnedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Thời gian duyệt hoàn: ${AppFormatters.formatDateTime(order.returnedAt!)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                  if (order.isRefunded) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '💸 Tiền đã được xử lý hoàn trả thành công.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Stepper 3 bước mặc định (Pending -> Delivering -> Delivered)
    int currentStep = 1;
    Color statusColor = AppColors.warning;
    String statusTitle = 'Đang chờ shop xác nhận';

    if (order.status == OrderModel.statusDelivering) {
      currentStep = 2;
      statusColor = Colors.blue;
      statusTitle = 'Đơn hàng đang trên đường giao';
    } else if (order.status == OrderModel.statusDelivered) {
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

          // Thanh Stepper ngang (Bảo toàn nguyên vẹn selectors test)
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

  /// Thẻ các nút hành động theo vòng đời đơn hàng
  Widget _buildOrderActionsCard(OrderModel order) {
    // 1. Đơn Pending: Nút Sửa thông tin & Nút Hủy đơn
    if (order.status == OrderModel.statusPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showEditAddressDialog(order),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
              label: const Text('Sửa địa chỉ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCancelOrderDialog(order),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Hủy đơn hàng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
              ),
            ),
          ),
        ],
      );
    }

    // 2. Đơn Delivering: Nút "Đã nhận được hàng"
    if (order.status == OrderModel.statusDelivering) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _confirmDelivered(order),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text(
            'TÔI ĐÃ NHẬN ĐƯỢC HÀNG',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      );
    }

    // 3. Đơn Delivered: Nút Đánh giá sản phẩm, Đổi/Trả & Mua lại
    if (order.status == OrderModel.statusDelivered) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showReviewDialog(order),
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Đánh giá sản phẩm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showReturnDialog(order),
                  icon: const Icon(Icons.assignment_return_outlined, size: 16),
                  label: const Text('Yêu cầu Đổi/Trả', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: Colors.amber.shade800),
                    foregroundColor: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleReorder(order),
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Mua lại đơn này', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppColors.black),
                foregroundColor: AppColors.black,
              ),
            ),
          ),
        ],
      );
    }

    // 4. Đơn Cancelled / Returned: Nút Mua lại đơn này
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleReorder(order),
        icon: const Icon(Icons.replay, size: 16),
        label: const Text('Mua lại các sản phẩm này', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: const BorderSide(color: AppColors.black),
          foregroundColor: AppColors.black,
        ),
      ),
    );
  }

  /// Thông tin người nhận & Hình thức giao hàng
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
          _buildInfoRow(
            'Hình thức nhận:',
            order.deliveryMethod == OrderModel.deliveryMethodPickup
                ? 'Nhận tại cửa hàng (${order.pickupBranchName})'
                : 'Giao hàng tận nơi',
          ),
          const SizedBox(height: 6),
          _buildInfoRow('Địa chỉ nhận hàng:', order.shippingAddress),
          if (order.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Ghi chú của khách:', order.note),
          ],
          const SizedBox(height: 6),
          _buildInfoRow(
            'Thời gian đặt hàng:',
            AppFormatters.formatDateTime(order.createdAt),
          ),
          if (order.deliveringAt != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Bắt đầu giao:', AppFormatters.formatDateTime(order.deliveringAt!)),
          ],
          if (order.deliveredAt != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Giao thành công:', AppFormatters.formatDateTime(order.deliveredAt!)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
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

  /// Tóm tắt chi phí thanh toán & Khóa Bẫy 8, 16 VietQR
  Widget _buildPaymentSummaryCard(BuildContext context, OrderModel order) {
    // Khóa Bẫy 8 & 16: Chỉ hiện nút mở VietQR khi thỏa mãn điều kiện
    final canShowVietQrButton = order.isVietQr &&
        (order.status == OrderModel.statusPending || order.status == OrderModel.statusDelivering) &&
        order.paymentStatus == OrderModel.paymentUnpaid;

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
          if (order.shippingFee > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Phí vận chuyển:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(AppFormatters.formatCurrency(order.shippingFee), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trạng thái thanh toán:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              _buildPaymentStatusBadge(order),
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

          // NÚT MỞ LẠI MÃ VIETQR (Khóa Bẫy 8 & 16)
          if (canShowVietQrButton) ...[
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
                      isFromCheckout: false,
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

  /// Badge trạng thái thanh toán minh bạch
  Widget _buildPaymentStatusBadge(OrderModel order) {
    if (order.isPaymentSubmitted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text(
          '⏳ Chờ Shop duyệt CK',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
        ),
      );
    }

    if (order.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Text(
          '✅ Đã thanh toán',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
        ),
      );
    }

    if (order.isRefunded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.purple.shade300),
        ),
        child: Text(
          '💸 Đã hoàn tiền',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Text(
        'Chưa thanh toán',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
      ),
    );
  }
}
