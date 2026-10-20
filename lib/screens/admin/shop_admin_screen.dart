import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/firestore_service.dart';
import 'admin_branch_management_screen.dart';
import 'admin_chat_inbox_screen.dart';
import 'admin_product_list_screen.dart';

/// Màn hình Trung tâm Điều hành & Quản trị Shop Admin (Admin Portal & Demo Tool)
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
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().listenAllOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Nạp Seed Data mẫu (4 danh mục, 8 sản phẩm, 2 chi nhánh)
  Future<void> _handleSeedData() async {
    setState(() => _isSeeding = true);

    try {
      final firestoreService = FirestoreService();
      await firestoreService.seedInitialData();

      if (mounted) {
        await context.read<ProductProvider>().loadData();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Khởi tạo dữ liệu mẫu thành công: Danh mục, Sản phẩm & Chi nhánh đã nạp lên Firestore!',
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
    final productProvider = context.watch<ProductProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: const Text(
          'SHOP ADMIN MANAGEMENT PORTAL',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Tổng Quan'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Duyệt Đơn'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Hệ Thống'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: TỔNG QUAN DASHBOARD & CÁC PHÂN HỆ QUẢN TRỊ
          _buildDashboardTab(productProvider, orderProvider),

          // TAB 2: DUYỆT ĐƠN HÀNG (Pending -> Delivering -> Delivered)
          _buildOrdersTab(orderProvider),

          // TAB 3: CÔNG CỤ SEED DATA & ROLE SWITCHER
          _buildDemoToolsTab(authProvider),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: DASHBOARD & QUICK ACCESS MENUS
  // ==========================================
  Widget _buildDashboardTab(
    ProductProvider productProvider,
    OrderProvider orderProvider,
  ) {
    final products = productProvider.allProducts;
    final orders = orderProvider.allOrders;

    final pendingCount = orders.where((o) => o.status == 'Pending').length;
    final deliveringCount =
        orders.where((o) => o.status == 'Delivering').length;
    final deliveredOrders = orders.where((o) => o.status == 'Delivered');

    num totalRevenue = 0;
    for (var o in deliveredOrders) {
      totalRevenue += o.totalPrice;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. THỐNG KÊ NHANH (KPI METRICS)
        const Text(
          'CHỈ SỐ HOẠT ĐỘNG KINH DOANH',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Kho Sản Phẩm',
                '${products.length}',
                'mặt hàng',
                Icons.inventory_2,
                Colors.blue.shade700,
                Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Chờ Duyệt Đơn',
                '$pendingCount',
                'đơn cần xử lý',
                Icons.hourglass_top_rounded,
                Colors.orange.shade800,
                Colors.orange.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Đang Giao Hàng',
                '$deliveringCount',
                'đơn trên đường',
                Icons.local_shipping,
                Colors.purple.shade700,
                Colors.purple.shade50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Doanh Thu Thực',
                AppFormatters.formatVND(totalRevenue),
                'đơn đã giao xong',
                Icons.monetization_on,
                Colors.green.shade800,
                Colors.green.shade50,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 2. PHÂN HỆ QUẢN TRỊ TRỰC TIẾP
        const Text(
          'PHÂN HỆ QUẢN TRỊ CỬA HÀNG',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Menu 1: Quản lý Kho sản phẩm
        _buildNavigationCard(
          title: 'Quản Lý Kho Hàng & Sản Phẩm',
          subtitle:
              'Thêm mới, chỉnh sửa thông tin, bảng size, màu sắc & xóa sản phẩm khỏi Firestore',
          icon: Icons.app_registration,
          iconColor: AppColors.primary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminProductListScreen()),
            );
          },
        ),

        const SizedBox(height: 12),

        // Menu 2: Duyệt đơn hàng
        _buildNavigationCard(
          title: 'Duyệt Đơn Hàng & Vận Chuyển',
          subtitle:
              'Xử lý trạng thái Pending -> Delivering -> Delivered và kích hoạt Real-time Notifications',
          icon: Icons.receipt_long,
          iconColor: Colors.blue.shade800,
          onTap: () {
            _tabController.animateTo(1);
          },
        ),

        const SizedBox(height: 12),

        // Menu 3: Quản lý Chi nhánh
        _buildNavigationCard(
          title: 'Quản Lý Hệ Thống Chi Nhánh',
          subtitle:
              'Thêm chi nhánh mới, cập nhật hotline, địa chỉ và tọa độ OpenStreetMap',
          icon: Icons.store_mall_directory,
          iconColor: Colors.teal.shade800,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminBranchManagementScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Menu 4: Hộp thư CSKH
        _buildNavigationCard(
          title: 'Hộp Thư Tư Vấn & CSKH',
          subtitle:
              'Xem danh sách khách hàng và phản hồi tư vấn kích cỡ theo thời gian thực',
          icon: Icons.support_agent,
          iconColor: Colors.orange.shade800,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminChatInboxScreen()),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String note,
    IconData icon,
    Color color,
    Color bgLight,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: DUYỆT ĐƠN HÀNG
  // ==========================================
  Widget _buildOrdersTab(OrderProvider orderProvider) {
    final orders = orderProvider.allOrders;

    if (orderProvider.isLoading && orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
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
      case 'Pending':
        statusColor = Colors.orange;
        statusText = 'Chờ xử lý';
        break;
      case 'Delivering':
        statusColor = Colors.blue;
        statusText = 'Đang giao hàng';
        break;
      case 'Delivered':
        statusColor = AppColors.success;
        statusText = 'Giao thành công';
        break;
      default:
        statusColor = Colors.grey;
        statusText = order.status;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mã đơn: #${order.orderId.length > 8 ? order.orderId.substring(0, 8) : order.orderId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
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
          Text(
            'Khách: ${order.userName} - ${order.phone}',
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          Text(
            'Địa chỉ: ${order.shippingAddress}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.items.length} sản phẩm | PTTT: ${order.paymentMethod}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    AppFormatters.formatVND(order.totalPrice),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (order.status == 'Pending') ...[
                ElevatedButton.icon(
                  onPressed: () {
                    orderProvider.updateOrderStatus(
                      orderId: order.orderId,
                      newStatus: 'Delivering',
                      userId: order.userId,
                    );
                  },
                  icon: const Icon(Icons.local_shipping_outlined, size: 16),
                  label: const Text('Giao hàng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
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
                  label: const Text('Hoàn tất'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  '✓ Đơn hoàn tất',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: CÔNG CỤ HỆ THỐNG & SEED DATA
  // ==========================================
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
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
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
                  'Nạp tự động 4 danh mục, 8 sản phẩm thời trang và 2 chi nhánh cửa hàng lên Cloud Firestore chỉ với 1 click duy nhất.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
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
                      _isSeeding
                          ? 'Đang nạp dữ liệu lên Firestore...'
                          : 'BẤM NẠP SEED DATA NGAY',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
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
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.black,
                      size: 28,
                    ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
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
