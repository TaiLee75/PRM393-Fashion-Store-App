import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../cart/widgets/vietqr_dialog.dart';
import '../main_nav_screen.dart';
import 'order_detail_screen.dart';

/// Màn hình Lịch sử đơn hàng của khách hàng (Task 3.5: Khóa Bẫy 8, 16, 20)
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _selectedStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider?>(context, listen: false);
      if (auth != null && auth.userId.isNotEmpty) {
        context.read<OrderProvider>().listenUserOrders(auth.userId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Xử lý Mua lại đơn này: Kiểm tra tồn kho và thêm vào Giỏ hàng
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
          if (!product.isActive) continue; // Bỏ qua sản phẩm ngừng kinh doanh
          maxStock = product.getStockForVariant(item.size, item.color);
          if (maxStock <= 0) continue; // Hết hàng phân loại này
        }
      }

      cartProvider.addItem(item.copyWith(isSelected: true), maxStock);
      addedCount++;
    }

    if (!mounted) return;

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $addedCount sản phẩm từ đơn hàng vào giỏ!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Các sản phẩm trong đơn hiện đã hết hàng hoặc ngừng kinh doanh!'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final rawOrders = orderProvider.userOrders;

    if (orderProvider.isLoading && rawOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (rawOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[350]),
            const SizedBox(height: 16),
            const Text(
              'Bạn chưa có đơn hàng nào',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các đơn hàng bạn đã mua sẽ xuất hiện tại đây',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Đếm số lượng đơn theo 6 trạng thái nghiệp vụ chuẩn
    final pendingCount = rawOrders.where((o) => o.status == OrderModel.statusPending).length;
    final deliveringCount = rawOrders.where((o) => o.status == OrderModel.statusDelivering).length;
    final deliveredCount = rawOrders.where((o) => o.status == OrderModel.statusDelivered).length;
    final returnRequestedCount = rawOrders.where((o) => o.status == OrderModel.statusReturnRequested).length;
    final returnedCount = rawOrders.where((o) => o.status == OrderModel.statusReturned).length;
    final cancelledCount = rawOrders.where((o) => o.status == OrderModel.statusCancelled).length;

    // Lọc danh sách theo chip trạng thái & từ khóa tìm kiếm
    final filteredOrders = rawOrders.where((order) {
      if (_selectedStatus != 'ALL' && order.status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = order.orderId.toLowerCase().contains(q);
        final matchProduct = order.items.any(
          (it) => it.productName.toLowerCase().contains(q),
        );
        if (!matchId && !matchProduct) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        _buildFilterBar(
          totalCount: rawOrders.length,
          pendingCount: pendingCount,
          deliveringCount: deliveringCount,
          deliveredCount: deliveredCount,
          returnRequestedCount: returnRequestedCount,
          returnedCount: returnedCount,
          cancelledCount: cancelledCount,
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        Expanded(
          child: filteredOrders.isEmpty
              ? _buildEmptyFilterState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    final auth = Provider.of<AuthProvider?>(context, listen: false);
                    if (auth != null && auth.userId.isNotEmpty) {
                      context.read<OrderProvider>().listenUserOrders(auth.userId, forceReload: true);
                    }
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar({
    required int totalCount,
    required int pendingCount,
    required int deliveringCount,
    required int deliveredCount,
    required int returnRequestedCount,
    required int returnedCount,
    required int cancelledCount,
  }) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Ô tìm kiếm đơn hàng
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm theo mã đơn hoặc tên sản phẩm...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 2. Hàng Chip lọc 6 trạng thái + Tất cả
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(
                  key: 'ALL',
                  label: 'Tất cả',
                  count: totalCount,
                  activeColor: AppColors.black,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  key: OrderModel.statusPending,
                  label: 'Chờ xác nhận',
                  count: pendingCount,
                  activeColor: AppColors.warning,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  key: OrderModel.statusDelivering,
                  label: 'Đang giao',
                  count: deliveringCount,
                  activeColor: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  key: OrderModel.statusDelivered,
                  label: 'Đã giao',
                  count: deliveredCount,
                  activeColor: AppColors.success,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  key: OrderModel.statusReturnRequested,
                  label: 'Yêu cầu đổi/trả',
                  count: returnRequestedCount,
                  activeColor: Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  key: OrderModel.statusReturned,
                  label: 'Đã hoàn trả',
                  count: returnedCount,
                  activeColor: Colors.purple.shade700,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  key: OrderModel.statusCancelled,
                  label: 'Đã hủy',
                  count: cancelledCount,
                  activeColor: AppColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String key,
    required String label,
    required int count,
    required Color activeColor,
  }) {
    final isSelected = _selectedStatus == key;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Không tìm thấy đơn hàng phù hợp',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Không có đơn nào khớp với "$_searchQuery" ở trạng thái đã chọn.'
                  : 'Không có đơn hàng nào ở trạng thái này.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedStatus = 'ALL';
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              label: const Text(
                'Đặt lại bộ lọc',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    Color statusColor;
    String statusText;
    switch (order.status) {
      case OrderModel.statusDelivering:
        statusColor = Colors.blue;
        statusText = 'Đang giao hàng';
        break;
      case OrderModel.statusDelivered:
        statusColor = AppColors.success;
        statusText = 'Đã giao thành công';
        break;
      case OrderModel.statusReturnRequested:
        statusColor = Colors.amber.shade800;
        statusText = 'Yêu cầu đổi/trả';
        break;
      case OrderModel.statusReturned:
        statusColor = Colors.purple.shade700;
        statusText = 'Đã hoàn trả';
        break;
      case OrderModel.statusCancelled:
        statusColor = AppColors.error;
        statusText = 'Đã hủy đơn';
        break;
      case OrderModel.statusPending:
      default:
        statusColor = AppColors.warning;
        statusText = 'Chờ xác nhận';
        break;
    }

    // Khóa Bẫy 8 & 16: Điều kiện hiển thị nút mở VietQR
    final canShowVietQrButton = order.isVietQr &&
        (order.status == OrderModel.statusPending || order.status == OrderModel.statusDelivering) &&
        order.paymentStatus == OrderModel.paymentUnpaid;

    // Điều kiện hiển thị nút "Mua lại đơn này"
    final canReorder = order.status == OrderModel.statusDelivered ||
        order.status == OrderModel.statusCancelled ||
        order.status == OrderModel.statusReturned;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(initialOrder: order),
          ),
        );
        if (mounted) {
          final auth = Provider.of<AuthProvider?>(context, listen: false);
          if (auth != null && auth.userId.isNotEmpty) {
            context.read<OrderProvider>().listenUserOrders(auth.userId, forceReload: true);
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề: Mã đơn & Trạng thái vận hành
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mã đơn: #${order.orderId.length > 8 ? order.orderId.substring(0, 8) : order.orderId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Thời gian đặt & Badge trạng thái thanh toán (Khóa Bẫy 16)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thời gian: ${AppFormatters.formatDateTime(order.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                _buildPaymentBadge(order),
              ],
            ),
            const Divider(height: 18),

            // Danh sách các món trong đơn
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.productName} (${item.size}, ${item.color}) x${item.quantity}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        AppFormatters.formatCurrency(item.itemTotal),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 18),

            // Phương thức thanh toán & Tổng giá trị đơn hàng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Phương thức: ${order.paymentMethod}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  AppFormatters.formatCurrency(order.totalPrice),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.priceHighlight,
                  ),
                ),
              ],
            ),

            // NÚT MỞ MÃ QR THANH TOÁN (Khóa Bẫy 8 & 16: Chỉ hiện khi thỏa mãn điều kiện)
            if (canShowVietQrButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => VietQrPaymentDialog(
                        orderId: order.orderId,
                        totalPrice: order.totalPrice,
                        isFromCheckout: false,
                        createdAt: order.createdAt,
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2, size: 18, color: AppColors.primary),
                  label: const Text(
                    'Xem mã QR thanh toán (Napas247)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ],

            // NÚT MUA LẠI ĐƠN NÀY (Dành cho đơn Delivered, Cancelled, Returned)
            if (canReorder) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleReorder(order),
                  icon: const Icon(Icons.replay, size: 18, color: AppColors.black),
                  label: const Text(
                    'Mua lại đơn này',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.black),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Xem chi tiết & tiến trình giao hàng',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Badge hiển thị trạng thái dòng tiền minh bạch (Khóa Bẫy 16)
  Widget _buildPaymentBadge(OrderModel order) {
    if (order.isRefundPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_bottom, size: 12, color: Colors.orange.shade900),
            const SizedBox(width: 3),
            Text(
              'Chờ hoàn tiền',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ),
      );
    }

    if (order.isRefunded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.purple.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.currency_exchange, size: 12, color: Colors.purple.shade800),
            const SizedBox(width: 3),
            Text(
              'Đã hoàn tiền',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade800,
              ),
            ),
          ],
        ),
      );
    }

    if (order.isPaymentSubmitted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: 12, color: Colors.orange.shade800),
            const SizedBox(width: 3),
            Text(
              'Chờ duyệt CK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
      );
    }

    if (order.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Colors.green.shade800),
            const SizedBox(width: 3),
            Text(
              'Đã thanh toán',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      );
    }

    if (order.isVietQr && order.paymentStatus == OrderModel.paymentUnpaid) {
      // Nếu đơn đã hủy thì không hiển thị badge Chưa thanh toán gây hiểu nhầm
      if (order.status == OrderModel.statusCancelled) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment, size: 12, color: Colors.red.shade700),
            const SizedBox(width: 3),
            Text(
              'Chưa thanh toán',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
