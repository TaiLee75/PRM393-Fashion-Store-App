import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/chat_provider.dart';
import '../admin/shop_admin_screen.dart';
import '../map/store_map_screen.dart';
import '../main_nav_screen.dart';
import '../notifications/notification_screen.dart';
import 'edit_profile_screen.dart';
import 'wishlist_screen.dart';

/// Màn hình Thông tin cá nhân & Phân quyền vai trò (Profile Screen) chuẩn Enterprise
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Hộp thoại Đổi mật khẩu an toàn với cơ chế Re-authentication (Khóa Bẫy 4)
  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isObscuredCurrent = true;
    bool isObscuredNew = true;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ĐỔI MẬT KHẨU AN TOÀN',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Để bảo mật tài khoản, vui lòng nhập mật khẩu hiện tại trước khi thiết lập mật khẩu mới.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mật khẩu hiện tại
                  TextFormField(
                    controller: currentPassCtrl,
                    obscureText: isObscuredCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscuredCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            isObscuredCurrent = !isObscuredCurrent;
                          });
                        },
                      ),
                    ),
                    validator: (v) => AppValidators.validateRequired(
                      v,
                      'Mật khẩu hiện tại',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mật khẩu mới
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: isObscuredNew,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới (tối thiểu 6 ký tự) *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscuredNew
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            isObscuredNew = !isObscuredNew;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      final req = AppValidators.validateRequired(
                        v,
                        'Mật khẩu mới',
                      );
                      if (req != null) return req;
                      if (v!.trim().length < 6) {
                        return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                      }
                      if (v.trim() == currentPassCtrl.text.trim()) {
                        return 'Mật khẩu mới không được trùng mật khẩu cũ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Xác nhận mật khẩu mới
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: isObscuredNew,
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu mới';
                      }
                      if (v.trim() != newPassCtrl.text.trim()) {
                        return 'Mật khẩu xác nhận không khớp!';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppColors.grey)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);

                      final auth = context.read<AuthProvider>();
                      final ok = await auth.changePassword(
                        currentPassword: currentPassCtrl.text.trim(),
                        newPassword: newPassCtrl.text.trim(),
                      );

                      if (ctx.mounted) {
                        setDialogState(() => isSubmitting = false);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? '✅ Đổi mật khẩu tài khoản thành công!'
                                  : (auth.errorMessage ??
                                      'Đổi mật khẩu thất bại!'),
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );

    currentPassCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final userModel = authProvider.userModel;
    final isAdmin = authProvider.isAdmin;

    // Thống kê đơn hàng cho Status Bar
    final userOrders = orderProvider.userOrders;
    final pendingCount = userOrders
        .where((o) => o.status == OrderModel.statusPending)
        .length;
    final deliveringCount = userOrders
        .where((o) => o.status == OrderModel.statusDelivering)
        .length;
    final deliveredCount = userOrders
        .where((o) => o.status == OrderModel.statusDelivered)
        .length;
    final returnCount = userOrders
        .where(
          (o) =>
              o.status == OrderModel.statusReturnRequested ||
              o.status == OrderModel.statusReturned,
        )
        .length;

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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

          // 2. THANH TÓM TẮT TRẠNG THÁI ĐƠN HÀNG (ORDER STATUS SUMMARY BAR)
          _buildOrderStatusSummaryBar(
            context,
            pending: pendingCount,
            delivering: deliveringCount,
            delivered: deliveredCount,
            returned: returnCount,
          ),
          const SizedBox(height: 16),

          // 3. THẺ TÓM TẮT THÔNG TIN GIAO HÀNG & SỐ ĐO
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
                          userModel?.effectiveDefaultAddress.isNotEmpty == true
                              ? 'Địa chỉ: ${userModel!.effectiveDefaultAddress}'
                              : 'Chạm để thiết lập địa chỉ nhận hàng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (userModel?.savedHeight != null &&
                            userModel!.savedHeight! > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.accessibility_new,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Số đo: ${userModel.savedHeight!.round()}cm - ${userModel.savedWeight?.round() ?? "--"}kg',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 4. MENU DÀNH CHO SHOP ADMIN (ROUTE GUARD - CHỈ ADMIN MỚI THẤY)
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

          // 5. DANH SÁCH MENU TIỆN ÍCH CHUNG
          _buildMenuSection(
            title: 'TÀI KHOẢN & TIỆN ÍCH',
            items: [
              _MenuItem(
                icon: Icons.person_outline,
                title: 'Chỉnh sửa hồ sơ cá nhân',
                subtitle: 'Họ tên, SĐT, số đo cơ thể & sổ địa chỉ',
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
                icon: Icons.favorite_border_rounded,
                iconColor: AppColors.primary,
                title: 'Danh sách Yêu thích (Wishlist)',
                subtitle:
                    '${authProvider.wishlistProductIds.length} sản phẩm đã thả tim',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WishlistScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu tài khoản',
                subtitle: 'Xác thực lại và cập nhật mật khẩu an toàn',
                onTap: () => _showChangePasswordDialog(context),
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

          // 6. CÔNG CỤ DEMO PHÂN QUYỀN (DÀNH CHO BUỔI BẢO VỆ / GIẢNG VIÊN TEST)
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
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.black,
                      size: 20,
                    ),
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

          // 7. THÔNG TIN HỌC PHẦN
          _buildMenuSection(
            title: 'THÔNG TIN HỌC PHẦN',
            items: [
              _MenuItem(
                icon: Icons.info_outline,
                title: 'Đồ án PRM393 - Đại học FPT',
                subtitle: 'Single-Brand Fashion Store (Lifewear Uniqlo Style)',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 28),

          // 8. NÚT ĐĂNG XUẤT AN TOÀN (KHÓA BẪY 13)
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

                if (confirm == true && context.mounted) {
                  final orderProv = context.read<OrderProvider?>();
                  final notiProv = context.read<NotificationProvider?>();
                  final chatProv = context.read<ChatProvider?>();

                  // Khóa Bẫy 13: unload giỏ hàng khỏi RAM, giữ nguyên Cloud Firestore
                  cartProvider.unloadCartOnLogout();
                  orderProv?.resetSession();
                  notiProv?.resetSession();
                  chatProv?.resetSession();
                  await authProvider.signOut();
                  if (context.mounted) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Thanh tóm tắt trạng thái đơn hàng (Order Status Summary Bar)
  Widget _buildOrderStatusSummaryBar(
    BuildContext context, {
    required int pending,
    required int delivering,
    required int delivered,
    required int returned,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ĐƠN HÀNG CỦA TÔI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: () => MainNavScreen.switchToTab(context, 2),
                child: const Row(
                  children: [
                    Text(
                      'Xem lịch sử',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
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
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                context,
                icon: Icons.hourglass_top_rounded,
                label: 'Chờ duyệt',
                count: pending,
              ),
              _buildStatusItem(
                context,
                icon: Icons.local_shipping_outlined,
                label: 'Đang giao',
                count: delivering,
              ),
              _buildStatusItem(
                context,
                icon: Icons.check_circle_outline_rounded,
                label: 'Đã giao',
                count: delivered,
              ),
              _buildStatusItem(
                context,
                icon: Icons.assignment_return_outlined,
                label: 'Đổi / Trả',
                count: returned,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
  }) {
    return InkWell(
      onTap: () => MainNavScreen.switchToTab(context, 2),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24, color: AppColors.textPrimary),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Container(
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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        item.icon,
                        color: item.iconColor ?? AppColors.textPrimary,
                        size: 22,
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: item.subtitle != null
                          ? Text(
                              item.subtitle!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                      trailing: const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onTap: item.onTap,
                    ),
                    if (index < items.length - 1)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.grey.shade100,
                      ),
                  ],
                );
              }),
            ),
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
