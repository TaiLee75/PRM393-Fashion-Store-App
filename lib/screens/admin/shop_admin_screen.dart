import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
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
  String _adminOrderFilter = 'ALL';
  final TextEditingController _adminOrderSearchController = TextEditingController();
  String _adminOrderQuery = '';
  String _selectedTimeRange = 'ALL_TIME'; // 'TODAY', 'LAST_7_DAYS', 'LAST_30_DAYS', 'ALL_TIME'

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
    _adminOrderSearchController.dispose();
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
  // TAB 1: DASHBOARD BI & QUICK ACCESS MENUS
  // ==========================================
  List<OrderModel> _filterOrdersByTime(List<OrderModel> orders) {
    if (_selectedTimeRange == 'ALL_TIME') return orders;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // Tính toán theo ngày trọn vẹn (inclusive calendar days)
    final sevenDaysStart = todayStart.subtract(const Duration(days: 6));
    final thirtyDaysStart = todayStart.subtract(const Duration(days: 29));

    return orders.where((order) {
      final date = order.createdAt;
      switch (_selectedTimeRange) {
        case 'TODAY':
          return !date.isBefore(todayStart);
        case 'LAST_7_DAYS':
          return !date.isBefore(sevenDaysStart);
        case 'LAST_30_DAYS':
          return !date.isBefore(thirtyDaysStart);
        default:
          return true;
      }
    }).toList();
  }

  List<ProductModel> _getLowStockProducts(List<ProductModel> products) {
    final list = products.where((p) {
      if (p.stock <= 5) return true;
      if (p.variantStock.isNotEmpty) {
        return p.variantStock.values.any((q) => q <= 0);
      }
      return false;
    }).toList();

    // Sắp xếp ưu tiên mặt hàng hết sạch hàng (stock == 0) lên đầu
    list.sort((a, b) => a.stock.compareTo(b.stock));
    return list;
  }

  List<String> _getOutOfStockVariants(ProductModel p) {
    if (p.variantStock.isEmpty) return [];
    return p.variantStock.entries
        .where((e) => e.value <= 0)
        .map((e) => e.key.replaceAll('_', ' - '))
        .toList();
  }

  List<ProductModel> _getTopSellingProducts(List<ProductModel> products) {
    // Chỉ xếp hạng các sản phẩm đã phát sinh doanh số bán hàng (soldCount > 0)
    final list = products.where((p) => p.soldCount > 0).toList();
    list.sort((a, b) => b.soldCount.compareTo(a.soldCount));
    return list.take(5).toList();
  }

  String _getCategoryName(String categoryId, ProductProvider productProvider) {
    if (categoryId.isEmpty) return 'Thời trang';
    final match =
        productProvider.categories.where((c) => c.id == categoryId).firstOrNull;
    return match?.name ?? 'Thời trang';
  }

  Widget _buildDashboardTab(
    ProductProvider productProvider,
    OrderProvider orderProvider,
  ) {
    final products = productProvider.allProducts;
    final allOrders = orderProvider.allOrders;

    // Lọc đơn hàng theo mốc thời gian đã chọn
    final timeFilteredOrders = _filterOrdersByTime(allOrders);

    // Tính toán chỉ số BI theo Khóa Bẫy 5
    final deliveredOrders = timeFilteredOrders
        .where((o) => o.status == OrderModel.statusDelivered)
        .toList();

    num netRevenue = 0;
    for (final o in deliveredOrders) {
      netRevenue += o.totalPrice;
    }
    final num aov = deliveredOrders.isNotEmpty
        ? (netRevenue / deliveredOrders.length)
        : 0;

    final pendingCount = timeFilteredOrders
        .where((o) => o.status == OrderModel.statusPending)
        .length;
    final deliveringCount = timeFilteredOrders
        .where((o) => o.status == OrderModel.statusDelivering)
        .length;
    final deliveredCount = deliveredOrders.length;
    final returnCount = timeFilteredOrders
        .where((o) =>
            o.status == OrderModel.statusReturnRequested ||
            o.status == OrderModel.statusReturned)
        .length;
    final cancelledCount = timeFilteredOrders
        .where((o) => o.status == OrderModel.statusCancelled)
        .length;

    // Danh sách sản phẩm tồn kho thấp hoặc hết hàng
    final lowStockProducts = _getLowStockProducts(products);

    // Danh sách Top 5 sản phẩm bán chạy nhất
    final top5Products = _getTopSellingProducts(products);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 1. THANH LỌC THỜI GIAN BI
        _buildTimeFilterBar(),

        const SizedBox(height: 14),

        // 2. KHÓA BẪY 5: THẺ DOANH THU THỰC THU & GIÁ TRỊ ĐƠN TRUNG BÌNH (AOV)
        _buildNetRevenueCard(
          netRevenue: netRevenue,
          aov: aov,
          deliveredCount: deliveredCount,
        ),

        const SizedBox(height: 16),

        // 3. CÁC THẺ CHỈ SỐ KPI VẬN HÀNH (KPI METRICS)
        const Text(
          'CHỈ SỐ VẬN HÀNH & TRẠNG THÁI ĐƠN HÀNG',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        _buildKpiMetricsGrid(
          totalProducts: products.length,
          pendingCount: pendingCount,
          deliveringCount: deliveringCount,
          deliveredCount: deliveredCount,
          returnCount: returnCount,
          cancelledCount: cancelledCount,
        ),

        const SizedBox(height: 20),

        // 4. WIDGET CẢNH BÁO TỒN KHO THẤP / HẾT HÀNG
        _buildLowStockWarningWidget(lowStockProducts, products.length),

        const SizedBox(height: 20),

        // 5. BẢNG XẾP HẠNG TOP 5 SẢN PHẨM BÁN CHẠY NHẤT (BEST SELLERS)
        _buildBestSellersRankingWidget(top5Products, productProvider),

        const SizedBox(height: 24),

        // 6. PHÂN HỆ QUẢN TRỊ TRỰC TIẾP
        const Text(
          'PHÂN HỆ QUẢN TRỊ CỬA HÀNG',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Menu 1: Quản lý Kho sản phẩm
        _buildNavigationCard(
          title: 'Quản Lý Kho Hàng & Sản Phẩm',
          subtitle:
              'Thêm mới, sửa thông tin, bảng size, màu sắc, tồn kho SKU & danh mục Firestore',
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
              'Xử lý trạng thái Pending -> Delivering -> Delivered, đối soát VietQR & Đổi/Trả hàng',
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
              'Thêm chi nhánh mới, cập nhật hotline, địa chỉ và ghim tọa độ OpenStreetMap',
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

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTimeFilterBar() {
    final ranges = [
      {'key': 'TODAY', 'label': 'Hôm nay', 'icon': Icons.today_rounded},
      {'key': 'LAST_7_DAYS', 'label': '7 ngày qua', 'icon': Icons.date_range_rounded},
      {'key': 'LAST_30_DAYS', 'label': '30 ngày qua', 'icon': Icons.calendar_month_rounded},
      {'key': 'ALL_TIME', 'label': 'Toàn thời gian', 'icon': Icons.all_inclusive_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              const Icon(Icons.filter_alt_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'KỲ THỐNG KÊ DOANH THU & KPI:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _selectedTimeRange == 'TODAY'
                    ? 'Hôm nay'
                    : _selectedTimeRange == 'LAST_7_DAYS'
                        ? '7 ngày qua'
                        : _selectedTimeRange == 'LAST_30_DAYS'
                            ? '30 ngày qua'
                            : 'Tất cả đơn',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ranges.map((r) {
                final isSelected = _selectedTimeRange == r['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedTimeRange = r['key'] as String);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.black : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.black : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            r['icon'] as IconData,
                            size: 13,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            r['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetRevenueCard({
    required num netRevenue,
    required num aov,
    required int deliveredCount,
  }) {
    return InkWell(
      onTap: () {
        _tabController.animateTo(1);
        setState(() => _adminOrderFilter = OrderModel.statusDelivered);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'DOANH THU THỰC THU (NET REVENUE)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'STATUS: DELIVERED',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              AppFormatters.formatCurrency(netRevenue),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF34D399)),
                      const SizedBox(width: 6),
                      Text(
                        'Đơn hoàn tất: $deliveredCount đơn',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.pie_chart_outline, size: 15, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'AOV: ${AppFormatters.formatCurrency(aov)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 13, color: Colors.white54),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Khóa Bẫy 5: Không tính đơn Hủy hoặc Hoàn trả • Chạm để xem danh sách',
                    style: TextStyle(fontSize: 10.5, color: Colors.white54),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 11, color: Colors.white54),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiMetricsGrid({
    required int totalProducts,
    required int pendingCount,
    required int deliveringCount,
    required int deliveredCount,
    required int returnCount,
    required int cancelledCount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Kho Sản Phẩm',
                '$totalProducts',
                'mặt hàng đang có (chạm xem)',
                Icons.inventory_2,
                Colors.blue.shade700,
                Colors.blue.shade50,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminProductListScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Chờ Duyệt Đơn',
                '$pendingCount',
                'đơn cần xử lý (lọc ngay)',
                Icons.hourglass_top_rounded,
                Colors.orange.shade800,
                Colors.orange.shade50,
                onTap: () {
                  _tabController.animateTo(1);
                  setState(() => _adminOrderFilter = OrderModel.statusPending);
                },
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
                'đơn trên đường (lọc ngay)',
                Icons.local_shipping_outlined,
                Colors.indigo.shade700,
                Colors.indigo.shade50,
                onTap: () {
                  _tabController.animateTo(1);
                  setState(() => _adminOrderFilter = OrderModel.statusDelivering);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Giao Hoàn Tất',
                '$deliveredCount',
                'giao thành công (lọc ngay)',
                Icons.verified,
                Colors.green.shade800,
                Colors.green.shade50,
                onTap: () {
                  _tabController.animateTo(1);
                  setState(() => _adminOrderFilter = OrderModel.statusDelivered);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Yêu Cầu Đổi / Trả',
                '$returnCount',
                'cần xét duyệt (lọc ngay)',
                Icons.assignment_return_rounded,
                Colors.purple.shade700,
                Colors.purple.shade50,
                onTap: () {
                  _tabController.animateTo(1);
                  setState(() => _adminOrderFilter = OrderModel.statusReturnRequested);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Đơn Đã Hủy',
                '$cancelledCount',
                'đơn bị hủy (lọc ngay)',
                Icons.cancel_outlined,
                Colors.red.shade700,
                Colors.red.shade50,
                onTap: () {
                  _tabController.animateTo(1);
                  setState(() => _adminOrderFilter = OrderModel.statusCancelled);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLowStockWarningWidget(
    List<ProductModel> lowStockProducts,
    int totalProducts,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: lowStockProducts.isNotEmpty
              ? Colors.orange.shade300
              : Colors.green.shade200,
        ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: lowStockProducts.isNotEmpty
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(
                  lowStockProducts.isNotEmpty
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  color: lowStockProducts.isNotEmpty
                      ? Colors.orange.shade900
                      : Colors.green.shade800,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CẢNH BÁO TỒN KHO THẤP & HẾT HÀNG',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: lowStockProducts.isNotEmpty
                          ? Colors.orange.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                ),
                if (lowStockProducts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${lowStockProducts.length} MẶT HÀNG',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (lowStockProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toàn bộ $totalProducts sản phẩm trong kho đang ở mức an toàn (tồn kho > 5).',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: min(4, lowStockProducts.length),
              separatorBuilder: (_, __) => const Divider(height: 16, thickness: 0.8),
              itemBuilder: (context, idx) {
                final product = lowStockProducts[idx];
                final outOfStockVariants = _getOutOfStockVariants(product);
                final isCompletelyOutOfStock = product.stock <= 0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: product.mainImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.mainImage,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 44,
                                height: 44,
                                color: AppColors.ultraLightGrey,
                                child: const Icon(Icons.image, size: 20, color: Colors.grey),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                color: AppColors.ultraLightGrey,
                                child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              color: AppColors.ultraLightGrey,
                              child: const Icon(Icons.checkroom, size: 20, color: Colors.grey),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isCompletelyOutOfStock
                                      ? Colors.red.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isCompletelyOutOfStock
                                      ? 'HẾT HÀNG (0)'
                                      : 'TỒN KHO: ${product.stock}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCompletelyOutOfStock
                                        ? Colors.red.shade800
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppFormatters.formatCurrency(product.price),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (outOfStockVariants.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Hết SKU: ${outOfStockVariants.join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.red.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminProductListScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 32),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text(
                        '+Stock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminProductListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: Text(
                    'Xem và nhập kho toàn bộ kho hàng ($totalProducts mặt hàng)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.black,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBestSellersRankingWidget(
    List<ProductModel> top5Products,
    ProductProvider productProvider,
  ) {
    final hasSales = top5Products.isNotEmpty && top5Products.first.soldCount > 0;
    final maxSold = hasSales ? max(1, top5Products.first.soldCount) : 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOP 5 SẢN PHẨM BÁN CHẠY NHẤT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Xếp hạng tự động theo tổng lượt bán (soldCount)',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasSales)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'Chưa có đơn hàng nào được bán ra trong hệ thống.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: top5Products.length,
              separatorBuilder: (_, __) => const Divider(height: 16, thickness: 0.7),
              itemBuilder: (context, idx) {
                final product = top5Products[idx];
                final rank = idx + 1;
                final ratio = (product.soldCount / maxSold).clamp(0.0, 1.0);
                final categoryName = _getCategoryName(product.categoryId, productProvider);

                // Màu sắc huy hiệu thứ hạng
                Color rankBg;
                Color rankTextColor;
                if (rank == 1) {
                  rankBg = const Color(0xFFFEF3C7);
                  rankTextColor = const Color(0xFFB45309);
                } else if (rank == 2) {
                  rankBg = const Color(0xFFF1F5F9);
                  rankTextColor = const Color(0xFF475569);
                } else if (rank == 3) {
                  rankBg = const Color(0xFFFFEDD5);
                  rankTextColor = const Color(0xFFC2410C);
                } else {
                  rankBg = Colors.grey.shade100;
                  rankTextColor = Colors.grey.shade600;
                }

                return Row(
                  children: [
                    // Huy hiệu thứ hạng
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rankBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: rankTextColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rankTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Ảnh thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: product.mainImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.mainImage,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 38,
                                height: 38,
                                color: AppColors.ultraLightGrey,
                                child: const Icon(Icons.image, size: 18, color: Colors.grey),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 38,
                                height: 38,
                                color: AppColors.ultraLightGrey,
                                child: const Icon(Icons.image_not_supported, size: 18, color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 38,
                              height: 38,
                              color: AppColors.ultraLightGrey,
                              child: const Icon(Icons.checkroom, size: 18, color: Colors.grey),
                            ),
                    ),
                    const SizedBox(width: 10),
                    // Tên & Danh mục
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                categoryName,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${AppFormatters.formatCurrency(product.price)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 4,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rank == 1
                                    ? const Color(0xFFF59E0B)
                                    : (rank == 2
                                        ? const Color(0xFF64748B)
                                        : (rank == 3
                                            ? const Color(0xFFD97706)
                                            : AppColors.primary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Doanh số & Doanh thu
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${product.soldCount} đã bán',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.formatCurrency(product.soldCount * product.price),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String note,
    IconData icon,
    Color color,
    Color bgLight, {
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
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

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: cardContent,
      );
    }
    return cardContent;
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

    // Đếm số lượng đơn theo từng trạng thái
    final totalCount = orders.length;
    final pendingCount =
        orders.where((o) => o.status == OrderModel.statusPending).length;
    final deliveringCount =
        orders.where((o) => o.status == OrderModel.statusDelivering).length;
    final deliveredCount =
        orders.where((o) => o.status == OrderModel.statusDelivered).length;
    final returnCount = orders
        .where((o) =>
            o.status == OrderModel.statusReturnRequested ||
            o.status == OrderModel.statusReturned)
        .length;
    final cancelledCount =
        orders.where((o) => o.status == OrderModel.statusCancelled).length;

    // Lọc theo trạng thái và từ khóa tìm kiếm
    final filteredOrders = orders.where((order) {
      if (_adminOrderFilter != 'ALL') {
        if (_adminOrderFilter == OrderModel.statusReturnRequested) {
          if (order.status != OrderModel.statusReturnRequested &&
              order.status != OrderModel.statusReturned) {
            return false;
          }
        } else if (order.status != _adminOrderFilter) {
          return false;
        }
      }
      if (_adminOrderQuery.isNotEmpty) {
        final q = _adminOrderQuery.toLowerCase();
        final matchId = order.orderId.toLowerCase().contains(q);
        final matchUser = order.userName.toLowerCase().contains(q);
        final matchPhone = order.phone.toLowerCase().contains(q);
        final matchProduct = order.items.any(
          (it) => it.productName.toLowerCase().contains(q),
        );
        if (!matchId && !matchUser && !matchPhone && !matchProduct) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        _buildAdminOrderFilterSection(
          totalCount: totalCount,
          pendingCount: pendingCount,
          deliveringCount: deliveringCount,
          deliveredCount: deliveredCount,
          returnCount: returnCount,
          cancelledCount: cancelledCount,
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        Expanded(
          child: filteredOrders.isEmpty
              ? _buildAdminEmptyFilterState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order, orderProvider);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAdminOrderFilterSection({
    required int totalCount,
    required int pendingCount,
    required int deliveringCount,
    required int deliveredCount,
    required int returnCount,
    required int cancelledCount,
  }) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Ô tìm kiếm nhanh
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _adminOrderSearchController,
              onChanged: (val) {
                setState(() => _adminOrderQuery = val.trim());
              },
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm theo mã đơn, khách hàng, SĐT, sản phẩm...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                suffixIcon: _adminOrderQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                        onPressed: () {
                          _adminOrderSearchController.clear();
                          setState(() => _adminOrderQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 2. Chip bộ lọc trạng thái
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAdminFilterChip(
                  key: 'ALL',
                  label: 'Tất cả',
                  count: totalCount,
                  activeColor: AppColors.black,
                ),
                const SizedBox(width: 8),
                _buildAdminFilterChip(
                  key: OrderModel.statusPending,
                  label: 'Chờ xử lý',
                  count: pendingCount,
                  activeColor: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                _buildAdminFilterChip(
                  key: OrderModel.statusDelivering,
                  label: 'Đang giao',
                  count: deliveringCount,
                  activeColor: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                _buildAdminFilterChip(
                  key: OrderModel.statusDelivered,
                  label: 'Hoàn tất',
                  count: deliveredCount,
                  activeColor: AppColors.success,
                ),
                const SizedBox(width: 8),
                _buildAdminFilterChip(
                  key: OrderModel.statusReturnRequested,
                  label: 'Đổi / Trả',
                  count: returnCount,
                  activeColor: Colors.purple.shade700,
                ),
                const SizedBox(width: 8),
                _buildAdminFilterChip(
                  key: OrderModel.statusCancelled,
                  label: 'Đã hủy',
                  count: cancelledCount,
                  activeColor: Colors.red.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFilterChip({
    required String key,
    required String label,
    required int count,
    required Color activeColor,
  }) {
    final isSelected = _adminOrderFilter == key;

    return InkWell(
      onTap: () {
        setState(() {
          _adminOrderFilter = key;
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

  Widget _buildAdminEmptyFilterState() {
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
              _adminOrderQuery.isNotEmpty
                  ? 'Không có đơn nào khớp với "$_adminOrderQuery" ở trạng thái đã chọn.'
                  : 'Không có đơn hàng nào ở trạng thái này.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _adminOrderFilter = 'ALL';
                  _adminOrderQuery = '';
                  _adminOrderSearchController.clear();
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

  Widget _buildOrderCard(OrderModel order, OrderProvider orderProvider) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case 'Pending':
        statusColor = Colors.orange.shade800;
        statusText = 'Chờ xử lý';
        break;
      case 'Delivering':
        statusColor = Colors.blue.shade700;
        statusText = 'Đang giao hàng';
        break;
      case 'Delivered':
        statusColor = AppColors.success;
        statusText = 'Giao thành công';
        break;
      case 'ReturnRequested':
        statusColor = Colors.purple.shade700;
        statusText = 'Yêu cầu Đổi/Trả';
        break;
      case 'Returned':
        statusColor = Colors.purple.shade900;
        statusText = 'Đã hoàn trả';
        break;
      case 'Cancelled':
        statusColor = Colors.red.shade700;
        statusText = 'Đã hủy';
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
              ] else if (order.status == 'Delivered') ...[
                const Text(
                  '✓ Giao hoàn tất',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else if (order.status == 'Cancelled') ...[
                Text(
                  '✕ Đã hủy đơn',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else if (order.status == 'ReturnRequested' || order.status == 'Returned') ...[
                Text(
                  '⚡ Đổi / Trả hàng',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Text(
                  order.status,
                  style: const TextStyle(
                    color: Colors.grey,
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
