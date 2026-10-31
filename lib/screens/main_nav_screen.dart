import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/chat_provider.dart';
import 'home/product_list_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/order_history_screen.dart';
import 'chat/chat_screen.dart';
import 'profile/profile_screen.dart';
import 'map/store_map_screen.dart';
import 'notifications/notification_screen.dart';
import 'admin/shop_admin_screen.dart';

/// Khung điều hướng chính của App (Bottom Navigation Bar phong cách Uniqlo)
/// Khóa Bẫy 11: Quản trị điều hướng bền vững qua switchToTab & ValueKey(auth.userId)
class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  static _MainNavScreenState? _currentState;

  /// Điều hướng an toàn về tab chỉ định trên MainNavScreen:
  /// - Pop toàn bộ các route đã push về lại root route (bảo toàn Consumer<AuthProvider> gốc).
  /// - Chuyển sang tab `tabIndex`.
  static void switchToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _currentState?.changeTab(tabIndex);
  }

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    ProductListScreen(),
    CartScreen(),
    OrderHistoryScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    MainNavScreen._currentState = this;
    _currentIndex = widget.initialIndex;

    // Lắng nghe dữ liệu realtime khi có user đăng nhập (an toàn môi trường test)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider?>(context, listen: false);
      if (auth != null && auth.userId.isNotEmpty) {
        Provider.of<NotificationProvider?>(context, listen: false)
            ?.listenNotifications(auth.userId);
        Provider.of<CartProvider?>(context, listen: false)
            ?.loadUserCart(auth.userId);
        Provider.of<OrderProvider?>(context, listen: false)
            ?.listenUserOrders(auth.userId);
        Provider.of<ChatProvider?>(context, listen: false)
            ?.listenMessages(auth.userId);
      }
    });
  }

  @override
  void dispose() {
    if (MainNavScreen._currentState == this) {
      MainNavScreen._currentState = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(MainNavScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      changeTab(widget.initialIndex);
    }
  }

  void changeTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    if (mounted) {
      setState(() => _currentIndex = index);
      if (index == 3) {
        final auth = Provider.of<AuthProvider?>(context, listen: false);
        if (auth != null && auth.userId.isNotEmpty) {
          Provider.of<ChatProvider?>(context, listen: false)
              ?.markChatAsReadByCustomer(auth.userId);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider?>();
    final notiProvider = context.watch<NotificationProvider?>();
    final authProvider = context.watch<AuthProvider?>();
    final chatProvider = context.watch<ChatProvider?>();

    final totalCartQuantity = cartProvider?.totalQuantity ?? 0;
    final unreadNotiCount = notiProvider?.unreadCount ?? 0;
    final unreadChatCount = chatProvider?.unreadCustomerCount ?? 0;
    final isAdmin = authProvider?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            // Uniqlo-style Brand Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'UNI-PRM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'FASHION STORE',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          // 1. Nút mở Bản đồ OpenStreetMap Chi nhánh
          IconButton(
            icon: const Icon(Icons.location_on_outlined, color: AppColors.black),
            tooltip: 'Chi nhánh cửa hàng (Bản đồ)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreMapScreen()),
              );
            },
          ),

          // 2. Nút Thông báo có Badge số lượng chưa đọc
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.black),
                tooltip: 'Thông báo',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen()),
                  );
                },
              ),
              if (unreadNotiCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadNotiCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 3. Nút mở Shop Admin (Chỉ hiển thị khi tài khoản là Admin)
          if (isAdmin)
            IconButton(
              icon: const Icon(
                Icons.admin_panel_settings,
                color: AppColors.primary,
              ),
              tooltip: 'Shop Admin Tool (Dành cho Quản trị viên)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopAdminScreen()),
                );
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => changeTab(index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkGrey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        elevation: 8,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: totalCartQuantity > 0,
              label: Text(
                '$totalCartQuantity',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: totalCartQuantity > 0,
              label: Text(
                '$totalCartQuantity',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shopping_bag),
            ),
            label: 'Giỏ hàng',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadChatCount > 0,
              label: Text(
                '$unreadChatCount',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadChatCount > 0,
              label: Text(
                '$unreadChatCount',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Tư vấn',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
