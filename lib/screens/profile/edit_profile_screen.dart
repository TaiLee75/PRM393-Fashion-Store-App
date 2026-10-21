import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../providers/auth_provider.dart';

/// Màn hình Chỉnh sửa Hồ sơ cá nhân (Edit Profile Screen)
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _avatarUrlController;

  bool _isSaving = false;

  // Danh sách các Avatar mẫu phong cách thời trang tối giản (Unsplash CDN)
  final List<String> _presetAvatars = const [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;

    _nameController = TextEditingController(
      text: user?.fullName.isNotEmpty == true
          ? user!.fullName
          : auth.userFullName,
    );
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController =
        TextEditingController(text: user?.defaultAddress ?? '');
    _avatarUrlController = TextEditingController(text: user?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfile(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      defaultAddress: _addressController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cập nhật hồ sơ cá nhân thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Cập nhật hồ sơ thất bại!',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = _avatarUrlController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'CHỈNH SỬA HỒ SƠ CÁ NHÂN',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. KHU VỰC AVATAR & PREVIEW
            Center(
              child: ClipOval(
                child: Container(
                  width: 100,
                  height: 100,
                  color: AppColors.primary,
                  child: currentAvatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: currentAvatar,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Chọn Avatar mẫu hoặc dán link ảnh bên dưới:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 10),

            // Dãy Avatar mẫu
            SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _presetAvatars.map((url) {
                  final isSelected = currentAvatar == url;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _avatarUrlController.text = url;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.grey,
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 2. THÔNG TIN CÁ NHÂN
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Họ và tên
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên *',
                      hintText: 'VD: Nguyễn Văn A',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        AppValidators.validateRequired(v, 'Họ và tên'),
                  ),
                  const SizedBox(height: 16),

                  // Số điện thoại Việt Nam
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại liên hệ *',
                      hintText: 'VD: 0901234567 (10 chữ số)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: AppValidators.validatePhone,
                  ),
                  const SizedBox(height: 16),

                  // Địa chỉ nhận hàng mặc định
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ nhận hàng mặc định *',
                      hintText:
                          'VD: Số 123 Đường Nguyễn Tri Phương, Quận 10, TP.HCM',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => AppValidators.validateRequired(
                      v,
                      'Địa chỉ nhận hàng',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link ảnh đại diện tùy chỉnh (Tùy chọn)
                  TextFormField(
                    controller: _avatarUrlController,
                    decoration: InputDecoration(
                      labelText: 'Đường dẫn ảnh đại diện tùy chỉnh (URL)',
                      hintText: 'https://images.unsplash.com/...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Xem trước ảnh',
                        onPressed: () => setState(() {}),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 3. NÚT LƯU THAY ĐỔI
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'ĐANG LƯU DỮ LIỆU...' : 'LƯU THAY ĐỔI HỒ SƠ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
