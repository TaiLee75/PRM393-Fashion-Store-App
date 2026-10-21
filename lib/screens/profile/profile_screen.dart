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

/// Màn hình Thông tin cá nhân & Đăng xuất (Tài khoản)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final userModel = authProvider.userModel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. HEADER AVATAR & TÊN
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primary,
                  backgroundImage: userModel?.avatarUrl.isNotEmpty == true
                      ? NetworkImage(userModel!.avatarUrl)
                      : null,
                  child: userModel?.avatarUrl.isEmpty != false
                      ? Text(
                          authProvider.userFullName.isNotEmpty
                              ? authProvider.userFullName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
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
                if (userModel?.phone.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '📞 ${userModel!.phone}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: authProvider.isAdmin ? AppColors.primary : AppColors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    authProvider.isAdmin ? 'QUẢN TRỊ VIÊN (ADMIN)' : 'KHÁCH HÀNG (CUSTOMER)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2. DANH SÁCH MENU TIỆN ÍCH
          _buildMenuSection(
            title: 'TÀI KHOẢN & TIỆN ÍCH',
            items: [
              _MenuItem(
                icon: Icons.person_outline,
                title: 'Chỉnh sửa hồ sơ cá nhân',
                subtitle: userModel?.defaultAddress.isNotEmpty == true
                    ? userModel!.defaultAddress
                    : 'Cập nhật SĐT, địa chỉ nhận hàng & ảnh đại diện',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'Thông báo',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen()),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.store_mall_directory_outlined,
                title: 'Chi nhánh cửa hàng (Bản đồ)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoreMapScreen()),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Shop Admin & Công cụ Demo',
                subtitle: 'Duyệt đơn hàng và nạp Seed Data',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ShopAdminScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. THÔNG TIN HỖ TRỢ
          _buildMenuSection(
            title: 'HỖ TRỢ & ĐIỀU KHOẢN',
            items: [
              _MenuItem(
                icon: Icons.info_outline,
                title: 'Đồ án PRM393 - Đại học FPT',
                subtitle: 'Single-Brand Fashion Store (Uniqlo Lifewear)',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 4. NÚT ĐĂNG XUẤT
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận đăng xuất'),
                    content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy', style: TextStyle(color: AppColors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({required String title, required List<_MenuItem> items}) {
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
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: items.map((item) {
              return ListTile(
                leading: Icon(item.icon, color: AppColors.black, size: 22),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: item.subtitle != null
                    ? Text(
                        item.subtitle!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.grey),
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
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
