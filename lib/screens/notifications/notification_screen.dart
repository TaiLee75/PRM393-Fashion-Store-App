import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/notification_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../orders/order_detail_screen.dart';

/// Màn hình Trung tâm Thông báo (Thông báo đơn hàng & Khuyến mãi) chuẩn Enterprise
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Bộ lọc danh mục thông báo: 0: Tất cả, 1: Đơn hàng, 2: Khuyến mãi
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.userId.isNotEmpty) {
        context.read<NotificationProvider>().listenNotifications(auth.userId);
      }
    });
  }

  Future<void> _handleNotificationTap(
    NotificationModel noti,
    NotificationProvider notiProvider,
  ) async {
    if (!noti.isRead) {
      notiProvider.markAsRead(noti.id);
    }

    final orderProvider = context.read<OrderProvider>();
    OrderModel? matchedOrder;

    // 1. Tra cứu theo orderId trực tiếp
    if (noti.orderId != null && noti.orderId!.isNotEmpty) {
      for (final o in orderProvider.allOrders) {
        if (o.orderId == noti.orderId) {
          matchedOrder = o;
          break;
        }
      }
      if (matchedOrder == null) {
        for (final o in orderProvider.userOrders) {
          if (o.orderId == noti.orderId) {
            matchedOrder = o;
            break;
          }
        }
      }
      matchedOrder ??= await orderProvider.fetchOrderById(noti.orderId!);
    }

    // 2. Tra cứu dự phòng theo chuỗi ID trong body/title
    if (matchedOrder == null) {
      final combinedOrders = [
        ...orderProvider.userOrders,
        ...orderProvider.allOrders,
      ];
      for (final o in combinedOrders) {
        final shortId =
            o.orderId.length > 8 ? o.orderId.substring(0, 8) : o.orderId;
        if (noti.body.contains(shortId) || noti.title.contains(shortId)) {
          matchedOrder = o;
          break;
        }
      }
    }

    if (matchedOrder != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(initialOrder: matchedOrder!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notiProvider = context.watch<NotificationProvider>();
    final allNotifications = notiProvider.notifications;
    final orderNotis = notiProvider.orderNotifications;
    final promoNotis = notiProvider.promoNotifications;
    final unreadCount = notiProvider.unreadCount;

    // Lọc danh sách theo filter chip
    List<NotificationModel> displayedList;
    switch (_selectedFilterIndex) {
      case 1:
        displayedList = orderNotis;
        break;
      case 2:
        displayedList = promoNotis;
        break;
      default:
        displayedList = allNotifications;
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'THÔNG BÁO',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                await notiProvider.markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Đã đánh dấu đọc toàn bộ thông báo!'),
                      backgroundColor: AppColors.black,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.done_all,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Đọc tất cả',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. THANH BỘ LỌC DANH MỤC THÔNG BÁO (FILTER CHIPS)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.ultraLightGrey,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Tất cả (${allNotifications.length})',
                  index: 0,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Đơn hàng (${orderNotis.length})',
                  index: 1,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Khuyến mãi (${promoNotis.length})',
                  index: 2,
                ),
              ],
            ),
          ),

          // 2. DANH SÁCH THÔNG BÁO
          Expanded(
            child: displayedList.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 68,
                            color: Colors.grey[350],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFilterIndex == 1
                                ? 'Chưa có thông báo đơn hàng nào'
                                : _selectedFilterIndex == 2
                                    ? 'Chưa có khuyến mãi nào'
                                    : 'Bạn chưa có thông báo nào',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Thông báo về trạng thái giao nhận và ưu đãi độc quyền sẽ tự động xuất hiện tại đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayedList.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final noti = displayedList[index];
                      final isOrder = noti.isOrderNotification;
                      final isPromo = noti.type == NotificationModel.typePromotion;

                      return ListTile(
                        tileColor: noti.isRead
                            ? Colors.transparent
                            : AppColors.primaryLight.withValues(alpha: 0.35),
                        leading: CircleAvatar(
                          backgroundColor: noti.isRead
                              ? AppColors.ultraLightGrey
                              : (isOrder
                                  ? AppColors.primary
                                  : isPromo
                                      ? Colors.amber.shade700
                                      : AppColors.black),
                          child: Icon(
                            isOrder
                                ? Icons.local_shipping_outlined
                                : isPromo
                                    ? Icons.discount_outlined
                                    : Icons.notifications_outlined,
                            color: noti.isRead
                                ? AppColors.grey
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                noti.title,
                                style: TextStyle(
                                  fontWeight: noti.isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (!noti.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              noti.body,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppFormatters.formatRelativeTime(
                                    noti.createdAt,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                if (noti.orderId != null &&
                                    noti.orderId!.isNotEmpty)
                                  const Row(
                                    children: [
                                      Text(
                                        'Xem đơn hàng',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 10,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _handleNotificationTap(noti, notiProvider),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required int index}) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.black : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
