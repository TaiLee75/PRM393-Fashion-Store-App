import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../orders/order_detail_screen.dart';

/// Màn hình Thông báo người dùng (Thông báo đơn hàng & khuyến mãi)
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId.isNotEmpty) {
        context.read<NotificationProvider>().listenNotifications(auth.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notiProvider = context.watch<NotificationProvider>();
    final notifications = notiProvider.notifications;

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
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 72, color: Colors.grey[350]),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn chưa có thông báo nào',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Thông báo về đơn hàng sẽ tự động xuất hiện tại đây',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final noti = notifications[index];
                return ListTile(
                  tileColor: noti.isRead ? Colors.transparent : AppColors.primaryLight.withValues(alpha: 0.4),
                  leading: CircleAvatar(
                    backgroundColor: noti.isRead ? AppColors.ultraLightGrey : AppColors.primary,
                    child: Icon(
                      Icons.notifications,
                      color: noti.isRead ? AppColors.grey : Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    noti.title,
                    style: TextStyle(
                      fontWeight: noti.isRead ? FontWeight.w600 : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        noti.body,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.formatRelativeTime(noti.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!noti.isRead) {
                      notiProvider.markAsRead(noti.id);
                    }

                    // Tự động tìm đơn hàng tương ứng để mở OrderDetailScreen
                    final orders = context.read<OrderProvider>().userOrders;
                    OrderModel? matchedOrder;
                    for (final o in orders) {
                      final shortId = o.orderId.length > 8 ? o.orderId.substring(0, 8) : o.orderId;
                      if (noti.body.contains(shortId) || noti.title.contains(shortId)) {
                        matchedOrder = o;
                        break;
                      }
                    }

                    if (matchedOrder != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(initialOrder: matchedOrder!),
                        ),
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}
