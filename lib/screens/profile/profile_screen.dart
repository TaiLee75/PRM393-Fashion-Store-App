import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../auth/login_screen.dart';
import '../admin/shop_admin_screen.dart';
import '../map/store_map_screen.dart';
import '../notifications/notification_screen.dart';
import 'edit_profile_screen.dart';

/// Màn hình Thông tin cá nhân & Phân quyền vai trò (Profile & Authorization)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final userModel = authProvider.userModel;
    final isAdmin = authProvider.isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. HEADER AVATAR & TÊN
          Center(
            child: Column(
              children: [
                ClipOval(
                  child: Container(
                    width: 84,
                    height: 84,
                    color: isAdmin ? AppColors.primary : AppColors.black,
                    child: userModel?.avatarUrl.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: userModel!.avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Text(
                                authProvider.userFullName.isNotEmpty
                                    ? authProvider.userFullName
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              authProvider.userFullName.isNotEmpty
                                  ? authProvider.userFullName
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  authProvider.userFullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.userEmail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // BADGE VAI TRÒ CHUYÊN NGHIỆP (BẤM VÀO ĐỂ ĐỔI VAI TRÒ DEMO)
                InkWell(
                  onTap: () async {
                    await authProvider.toggleAdminRoleForDemo();
                    if (context.mounted) {
                      final newRoleText = authProvider.isAdmin
                          ? 'QUẢN TRỊ VIÊN (ADMIN)'
                          : 'KHÁCH HÀNG (CUSTOMER)';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '🔄 Đã chuyển đổi vai trò Demo sang: $newRoleText',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppColors.black,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isAdmin ? AppColors.primary : AppColors.black,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isAdmin ? AppColors.primary : Colors.black)
                              .withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdmin
                              ? Icons.verified_user
                              : Icons.shopping_bag_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAdmin
                              ? 'QUẢN TRỊ VIÊN (ADMIN)'
                              : 'KHÁCH HÀNG (CUSTOMER)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. THẺ TÓM TẮT THÔNG TIN GIAO HÀNG
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.contact_phone_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userModel?.phone.isNotEmpty == true
                              ? 'SĐT: ${userModel!.phone}'
                              : 'Chưa cập nhật số điện thoại',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: userModel?.phone.isNotEmpty == true
                                ? AppColors.textPrimary
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userModel?.defaultAddress.isNotEmpty == true
                              ? 'Địa chỉ: ${userModel!.defaultAddress}'
                              : 'Chạm để thiết lập địa chỉ nhận hàng mặc định',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. MENU DÀNH CHO SHOP ADMIN (ROUTE GUARD - CHỈ ADMIN MỚI THẤY)
          if (isAdmin) ...[
            _buildMenuSection(
              title: 'KHU VỰC QUẢN TRỊ (DÀNH CHO SHOP ADMIN)',
              items: [
                _MenuItem(
                  icon: Icons.admin_panel_settings_outlined,
                  iconColor: AppColors.primary,
                  title: 'Shop Admin Management Portal',
                  subtitle:
                      'Quản lý kho sản phẩm, duyệt đơn, chi nhánh & CSKH',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ShopAdminScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // 4. DANH SÁCH MENU TIỆN ÍCH CHUNG
          _buildMenuSection(
            title: 'TÀI KHOẢN & TIỆN ÍCH',
            items: [
              _MenuItem(
                icon: Icons.person_outline,
                title: 'Chỉnh sửa hồ sơ cá nhân',
                subtitle: 'Cập nhật họ tên, SĐT, địa chỉ & ảnh đại diện',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'Thông báo đơn hàng & khuyến mãi',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.store_mall_directory_outlined,
                title: 'Hệ thống chi nhánh (Bản đồ OpenStreetMap)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoreMapScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 5. CÔNG CỤ DEMO PHÂN QUYỀN (DÀNH CHO BUỔI BẢO VỆ / GIẢNG VIÊN TEST)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ultraLightGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded,
                        color: AppColors.black, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Công cụ chuyển đổi vai trò (Demo Role Switcher)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Đang ở vai trò: ${isAdmin ? "ADMIN (Xem được cổng quản trị)" : "CUSTOMER (Khách thường - Ẩn mục Admin)"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isAdmin ? AppColors.primary : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => authProvider.toggleAdminRoleForDemo(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.black,
                      side: const BorderSide(color: AppColors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      isAdmin
                          ? 'Chuyển về Khách Hàng (Customer)'
                          : 'Chuyển sang Quản Trị Viên (Admin)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 6. THÔNG TIN HỌC PHẦN
          _buildMenuSection(
            title: 'THÔNG TIN HỌC PHẦN',
            items: [
              _MenuItem(
                icon: Icons.info_outline,
                title: 'Đồ án PRM393 - Đại học FPT',
                subtitle: 'Single-Brand Fashion Store (Uniqlo Lifewear)',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 28),

          // 7. NÚT ĐĂNG XUẤT
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận đăng xuất'),
                    content: const Text(
                      'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(color: AppColors.grey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  cartProvider.clearCart();
                  await authProvider.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.primary),
              label: const Text(
                'ĐĂNG XUẤT',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: items.map((item) {
              return ListTile(
                leading: Icon(
                  item.icon,
                  color: item.iconColor ?? AppColors.black,
                  size: 22,
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: item.subtitle != null
                    ? Text(
                        item.subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.grey,
                ),
                onTap: item.onTap,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
