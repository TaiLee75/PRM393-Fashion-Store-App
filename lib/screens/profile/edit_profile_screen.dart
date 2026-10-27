import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../providers/auth_provider.dart';

/// Màn hình Chỉnh sửa Hồ sơ cá nhân & Sổ địa chỉ (Edit Profile Screen) chuẩn Enterprise
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

  // Controllers cho Số đo cơ thể (Smart Size Guide)
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  bool _isSaving = false;

  // Danh sách các Avatar mẫu phong cách thời trang tối giản (Unsplash CDN)
  static const List<String> _presetAvatars = [
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

    // Khởi tạo số đo cơ thể nếu có
    final savedHeight = user?.savedHeight;
    final savedWeight = user?.savedWeight;
    _heightController = TextEditingController(
      text: savedHeight != null && savedHeight > 0
          ? savedHeight.round().toString()
          : '',
    );
    _weightController = TextEditingController(
      text: savedWeight != null && savedWeight > 0
          ? savedWeight.round().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _avatarUrlController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();

    // 1. Cập nhật thông tin cơ bản
    final success = await authProvider.updateProfile(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      defaultAddress: _addressController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim(),
    );

    // 2. Cập nhật số đo cơ thể nếu có nhập
    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();
    if (heightText.isNotEmpty && weightText.isNotEmpty) {
      final h = double.tryParse(heightText);
      final w = double.tryParse(weightText);
      if (h != null && w != null && h > 0 && w > 0) {
        await authProvider.saveBodyMeasurements(heightCm: h, weightKg: w);
      }
    }

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

  /// Hộp thoại thêm địa chỉ mới vào Sổ địa chỉ
  Future<void> _showAddAddressDialog() async {
    final labelCtrl = TextEditingController(text: 'Nhà riêng');
    final addrCtrl = TextEditingController();
    bool setAsDefault = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'THÊM ĐỊA CHỈ NHẬN HÀNG',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên gợi nhớ *',
                    hintText: 'VD: Nhà riêng, Văn phòng...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ chi tiết *',
                    hintText: 'Số nhà, tên đường, phường/xã, quận/huyện...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Đặt làm địa chỉ nhận hàng mặc định',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: setAsDefault,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setDialogState(() {
                      setAsDefault = val ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppColors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final address = addrCtrl.text.trim();
                if (label.isEmpty || address.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đầy đủ tên và địa chỉ!'),
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final ok = await auth.addSavedAddress({
                  'label': label,
                  'address': address,
                  'isDefault': setAsDefault,
                });

                if (ok && setAsDefault && mounted) {
                  setState(() {
                    _addressController.text = address;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Lưu địa chỉ'),
            ),
          ],
        ),
      ),
    );

    labelCtrl.dispose();
    addrCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = _avatarUrlController.text.trim();
    final authProvider = context.watch<AuthProvider>();
    final savedAddresses = authProvider.savedAddresses;

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
                  width: 96,
                  height: 96,
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
                            size: 48,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person, size: 48, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Chọn Avatar mẫu hoặc dán link ảnh tùy chỉnh bên dưới:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 10),

            // Dãy Avatar mẫu
            SizedBox(
              height: 50,
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
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 18,
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

            // 2. THÔNG TIN CÁ NHÂN CƠ BẢN
            _buildSectionCard(
              title: 'THÔNG TIN CƠ BẢN',
              icon: Icons.person_outline,
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

                // Link ảnh đại diện tùy chỉnh (URL)
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
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return AppValidators.validateUrl(v);
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. SỐ ĐO CƠ THỂ (SMART SIZE PROFILE)
            _buildSectionCard(
              title: 'SỐ ĐO CƠ THỂ (GỢI Ý SIZE CHUẨN XÁC)',
              icon: Icons.accessibility_new_rounded,
              children: [
                const Text(
                  'Số đo của bạn được dùng để tự động tính toán và gợi ý kích cỡ phù hợp nhất khi duyệt qua các sản phẩm Lifewear.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Chiều cao (cm)',
                          hintText: 'VD: 172',
                          border: OutlineInputBorder(),
                          suffixText: 'cm',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cân nặng (kg)',
                          hintText: 'VD: 65',
                          border: OutlineInputBorder(),
                          suffixText: 'kg',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 4. SỔ ĐỊA CHỈ NHẬN HÀNG (SAVED ADDRESSES)
            _buildSectionCard(
              title: 'SỔ ĐỊA CHỈ GIAO HÀNG (${savedAddresses.length})',
              icon: Icons.markunread_mailbox_outlined,
              action: TextButton.icon(
                onPressed: _showAddAddressDialog,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text(
                  'Thêm mới',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              children: [
                if (savedAddresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Chưa có địa chỉ lưu phụ. Bạn có thể thêm địa chỉ văn phòng, nhà người thân để đặt hàng nhanh hơn.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: savedAddresses.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, idx) {
                      final item = savedAddresses[idx];
                      final label = item['label'] as String? ?? 'Địa chỉ';
                      final addr = item['address'] as String? ?? '';
                      final isDef = item['isDefault'] == true;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isDef
                              ? AppColors.primary
                              : AppColors.ultraLightGrey,
                          radius: 16,
                          child: Icon(
                            isDef ? Icons.check : Icons.location_on,
                            size: 16,
                            color: isDef ? Colors.white : AppColors.grey,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isDef) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Mặc định',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          addr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isDef)
                              IconButton(
                                icon: const Icon(
                                  Icons.radio_button_unchecked,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                tooltip: 'Đặt làm mặc định',
                                onPressed: () async {
                                  await authProvider.updateSavedAddress(
                                    idx,
                                    {
                                      ...item,
                                      'isDefault': true,
                                    },
                                  );
                                  setState(() {
                                    _addressController.text = addr;
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.grey,
                              ),
                              tooltip: 'Xóa địa chỉ',
                              onPressed: () async {
                                await authProvider.deleteSavedAddress(idx);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),

            const SizedBox(height: 28),

            // 5. NÚT LƯU THAY ĐỔI
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
