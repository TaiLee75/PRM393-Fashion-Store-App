import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/firestore_service.dart';

/// Màn hình quản trị Shop (Công cụ Demo bảo vệ đồ án trước Hội đồng / Giảng viên)
class ShopAdminScreen extends StatefulWidget {
  const ShopAdminScreen({super.key});

  @override
  State<ShopAdminScreen> createState() => _ShopAdminScreenState();
}

class _ShopAdminScreenState extends State<ShopAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().listenAllOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Nút bấm vàng: Khởi tạo Seed Data mẫu trong 2 giây
  Future<void> _handleSeedData() async {
    setState(() => _isSeeding = true);

    try {
      final firestoreService = FirestoreService();
      await firestoreService.seedInitialData();

      if (mounted) {
        // Làm mới dữ liệu trong ProductProvider
        await context.read<ProductProvider>().loadData();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Khởi tạo dữ liệu mẫu thành công: 4 Danh mục & 8 Sản phẩm thời trang đã được nạp lên Firestore!',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nạp dữ liệu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final orderProvider = context.watch<OrderProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: const Text(
          'SHOP ADMIN & DEMO TOOL',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Duyệt Đơn Hàng'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Công Cụ Demo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: DUYỆT ĐƠN HÀNG (Pending -> Delivering -> Delivered)
          _buildOrdersTab(orderProvider),

          // TAB 2: CÔNG CỤ SEED DATA & ROLE SWITCHER
          _buildDemoToolsTab(authProvider),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(OrderProvider orderProvider) {
    final orders = orderProvider.allOrders;

    if (orderProvider.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Chưa có đơn hàng nào trong hệ thống',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order, orderProvider);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, OrderProvider orderProvider) {
    Color statusColor;
    String statusText;
    switch (order.status) {
      case 'Delivering':
        statusColor = Colors.blue;
        statusText = 'Đang giao hàng';
        break;
      case 'Delivered':
        statusColor = AppColors.success;
        statusText = 'Đã giao thành công';
        break;
      case 'Pending':
      default:
        statusColor = AppColors.warning;
        statusText = 'Chờ xác nhận';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Đơn hàng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đơn #${order.orderId.isNotEmpty ? order.orderId.substring(0, 8) : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
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
          const SizedBox(height: 8),

          // Thông tin người nhận
          Text('Khách: ${order.userName} - ${order.phone}'),
          Text(
            'Địa chỉ: ${order.shippingAddress}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            'Tổng thanh toán: ${AppFormatters.formatCurrency(order.totalPrice)} (${order.paymentMethod})',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Divider(height: 20),

          // Nút bấm chuyển trạng thái đơn (Demo trigger notification sang máy khách)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (order.status == 'Pending') ...[
                ElevatedButton.icon(
                  onPressed: () {
                    orderProvider.updateOrderStatus(
                      orderId: order.orderId,
                      newStatus: 'Delivering',
                      userId: order.userId,
                    );
                  },
                  icon: const Icon(Icons.local_shipping, size: 16),
                  label: const Text('Giao hàng (Delivering)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ] else if (order.status == 'Delivering') ...[
                ElevatedButton.icon(
                  onPressed: () {
                    orderProvider.updateOrderStatus(
                      orderId: order.orderId,
                      newStatus: 'Delivered',
                      userId: order.userId,
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Hoàn tất (Delivered)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ] else ...[
                const Text(
                  '✓ Đơn hoàn tất',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoToolsTab(AuthProvider authProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Khởi tạo dữ liệu mẫu
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ultraLightGrey,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Khởi tạo Dữ liệu mẫu (Seed Data)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nạp tự động 4 danh mục và 8 sản phẩm thời trang chất lượng cao từ `mock_data.dart` lên Cloud Firestore chỉ với 1 click duy nhất.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSeeding ? null : _handleSeedData,
                    icon: _isSeeding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.flash_on, color: Colors.white),
                    label: Text(
                      _isSeeding ? 'Đang nạp dữ liệu lên Firestore...' : 'BẤM NẠP SEED DATA NGAY',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Switch Role Demo Tool
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.ultraLightGrey,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, color: AppColors.black, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Chuyển đổi Vai trò (Role Switcher)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Vai trò hiện tại: ${authProvider.userRole.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => authProvider.toggleAdminRoleForDemo(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.black,
                    side: const BorderSide(color: AppColors.black),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(
                    authProvider.isAdmin
                        ? 'Chuyển về Khách Hàng (Customer)'
                        : 'Chuyển sang Quản Trị Viên (Admin)',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
