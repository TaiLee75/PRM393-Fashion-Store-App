import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../models/branch_model.dart';
import '../../services/firestore_service.dart';
import '../map/store_map_screen.dart';

/// Màn hình Quản lý Danh sách Chi nhánh Cửa hàng dành cho Admin (Khóa Bẫy 19)
class AdminBranchManagementScreen extends StatefulWidget {
  final FirestoreService? firestoreService;

  const AdminBranchManagementScreen({super.key, this.firestoreService});

  @override
  State<AdminBranchManagementScreen> createState() =>
      _AdminBranchManagementScreenState();
}

class _AdminBranchManagementScreenState
    extends State<AdminBranchManagementScreen> {
  late final FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
  }

  /// Sheet Thêm Chi nhánh mới
  Future<void> _showAddBranchSheet([BuildContext? _]) async {
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchFormSheet(
        firestoreService: _firestoreService,
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Đã thêm chi nhánh mới thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// Sheet Chỉnh sửa Chi nhánh hiện có (Khóa Bẫy 19: Cập nhật Firestore)
  Future<void> _showEditBranchSheet(
    BuildContext _,
    BranchModel branch,
  ) async {
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchFormSheet(
        branch: branch,
        firestoreService: _firestoreService,
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã cập nhật chi nhánh "${branch.name}"!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// Chuyển đổi trạng thái hoạt động (Active <-> Inactive) của chi nhánh
  Future<void> _toggleBranchStatus(BranchModel branch) async {
    final nextStatus = !branch.isActive;
    try {
      await _firestoreService.updateBranch(
        branch.copyWith(isActive: nextStatus),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextStatus
                  ? '🟢 Đã kích hoạt hoạt động chi nhánh "${branch.name}"'
                  : '⏸️ Đã tạm ngừng đón khách chi nhánh "${branch.name}"',
            ),
            backgroundColor: nextStatus ? AppColors.success : AppColors.black,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật trạng thái: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmDeleteBranch(BuildContext context, BranchModel branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${branch.name}" khỏi danh sách chi nhánh?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestoreService.deleteBranch(branch.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🗑️ Đã xóa chi nhánh "${branch.name}"'),
                      backgroundColor: AppColors.black,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi xóa chi nhánh: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'QUẢN LÝ HỆ THỐNG CHI NHÁNH',
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text(
          'THÊM CHI NHÁNH',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        onPressed: () => _showAddBranchSheet(context),
      ),
      body: StreamBuilder<List<BranchModel>>(
        stream: _firestoreService.streamBranches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi nạp danh sách chi nhánh: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final branches = snapshot.data ?? [];

          if (branches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có chi nhánh nào trong hệ thống\nBấm nút bên dưới để thêm mới!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final branch = branches[index];
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: branch.isActive ? 1.0 : 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    color: branch.isActive ? AppColors.white : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: branch.isActive ? Colors.grey.shade200 : Colors.grey.shade300,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (branch.isActive ? AppColors.primary : Colors.grey)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.storefront,
                                color: branch.isActive ? AppColors.primary : Colors.grey,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    branch.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: branch.isActive
                                          ? AppColors.textPrimary
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: branch.isActive
                                          ? AppColors.success.withValues(alpha: 0.1)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: branch.isActive
                                            ? AppColors.success.withValues(alpha: 0.4)
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: branch.isActive
                                                ? AppColors.success
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          branch.isActive
                                              ? 'Đang hoạt động'
                                              : 'Tạm ngừng đón khách',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: branch.isActive
                                                ? AppColors.success
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Nút Bật/Tắt hoạt động nhanh
                            IconButton(
                              icon: Icon(
                                branch.isActive
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                color: branch.isActive
                                    ? Colors.orange.shade700
                                    : AppColors.success,
                                size: 22,
                              ),
                              tooltip: branch.isActive
                                  ? 'Tạm ngừng chi nhánh'
                                  : 'Kích hoạt lại chi nhánh',
                              onPressed: () => _toggleBranchStatus(branch),
                            ),
                            // Nút Chỉnh sửa chi nhánh
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blue,
                                size: 22,
                              ),
                              tooltip: 'Chỉnh sửa chi nhánh',
                              onPressed: () =>
                                  _showEditBranchSheet(context, branch),
                            ),
                            // Nút Xóa chi nhánh
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                                size: 22,
                              ),
                              tooltip: 'Xóa chi nhánh',
                              onPressed: () =>
                                  _confirmDeleteBranch(context, branch),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              branch.address,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            branch.phone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'GPS: ${branch.latitude.toStringAsFixed(4)}, ${branch.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          );
        },
      ),
    );
  }
}

/// Sheet Form Thêm / Chỉnh sửa Chi nhánh độc lập (StatefulWidget)
class _BranchFormSheet extends StatefulWidget {
  final BranchModel? branch;
  final FirestoreService firestoreService;

  const _BranchFormSheet({
    this.branch,
    required this.firestoreService,
  });

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late bool _isActive;
  bool _isSaving = false;

  bool get _isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameController = TextEditingController(text: b?.name ?? '');
    _addressController = TextEditingController(text: b?.address ?? '');
    _phoneController = TextEditingController(text: b?.phone ?? '1900 1234');
    _latController =
        TextEditingController(text: (b?.latitude ?? 15.9689).toString());
    _lngController =
        TextEditingController(text: (b?.longitude ?? 108.2608).toString());
    _isActive = b?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
      final phone = _phoneController.text.trim();
      final lat = double.tryParse(_latController.text.trim()) ?? 15.9689;
      final lng = double.tryParse(_lngController.text.trim()) ?? 108.2608;

      if (_isEdit) {
        final updated = widget.branch!.copyWith(
          name: name,
          address: address,
          phone: phone,
          latitude: lat,
          longitude: lng,
          isActive: _isActive,
        );
        await widget.firestoreService.updateBranch(updated);
      } else {
        final newBranch = BranchModel(
          id: '',
          name: name,
          address: address,
          phone: phone,
          latitude: lat,
          longitude: lng,
          isActive: _isActive,
          createdAt: DateTime.now(),
        );
        await widget.firestoreService.addBranch(newBranch);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEdit ? 'CHỈNH SỬA CHI NHÁNH' : 'THÊM CHI NHÁNH MỚI',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên chi nhánh *',
                  hintText: 'VD: Chi nhánh 3 - Bien My Khe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (v) =>
                    AppValidators.validateRequired(v, 'Tên chi nhánh'),
              ),
              const SizedBox(height: 12),

              // Địa chỉ kèm nút Ghim Bản đồ
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ chi nhánh *',
                  hintText: 'VD: 532, Võ Nguyên Giáp, Ngũ Hành Sơn, Đà Nẵng',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                    tooltip: 'Ghim trên Bản đồ',
                    onPressed: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const StoreMapScreen(isBranchPicker: true),
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          if (result['address'] != null) {
                            _addressController.text =
                                result['address'].toString();
                          }
                          if (result['latitude'] != null) {
                            _latController.text =
                                result['latitude'].toString();
                          }
                          if (result['longitude'] != null) {
                            _lngController.text =
                                result['longitude'].toString();
                          }
                        });
                      }
                    },
                  ),
                ),
                validator: (v) =>
                    AppValidators.validateRequired(v, 'Địa chỉ chi nhánh'),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const StoreMapScreen(isBranchPicker: true),
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        if (result['address'] != null) {
                          _addressController.text =
                              result['address'].toString();
                        }
                        if (result['latitude'] != null) {
                          _latController.text =
                              result['latitude'].toString();
                        }
                        if (result['longitude'] != null) {
                          _lngController.text =
                              result['longitude'].toString();
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.pin_drop_outlined, size: 18),
                  label: const Text(
                    'Ghim vị trí trên Bản đồ OpenStreetMap',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại hotline *',
                  hintText: 'VD: 0236 1234 567',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) =>
                    AppValidators.validateRequired(v, 'Số điện thoại'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Vĩ độ (Latitude) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          AppValidators.validateRequired(v, 'Vĩ độ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Kinh độ (Longitude) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          AppValidators.validateRequired(v, 'Kinh độ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Switch Bật/Tắt trạng thái hoạt động chi nhánh
              Material(
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  title: const Text(
                    'Trạng thái hoạt động',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Chi nhánh mở cửa, hiển thị trên Bản đồ & nhận hàng tại Checkout'
                        : 'Tạm ngừng đón khách, ẩn khỏi danh sách nhận hàng tại Checkout',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  activeThumbColor: AppColors.success,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEdit ? 'CẬP NHẬT CHI NHÁNH' : 'LƯU CHI NHÁNH',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
