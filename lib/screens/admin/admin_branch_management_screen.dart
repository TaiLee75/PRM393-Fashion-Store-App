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
  void _showAddBranchSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController(text: '1900 1234');
    final latController = TextEditingController(text: '15.9689');
    final lngController = TextEditingController(text: '108.2608');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'THÊM CHI NHÁNH MỚI',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên chi nhánh *',
                          hintText: 'VD: Chi nhánh 3 - Hoan Kiem Store',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (v) =>
                            AppValidators.validateRequired(v, 'Tên chi nhánh'),
                      ),
                      const SizedBox(height: 12),

                      // Địa chỉ kèm nút Ghim Bản đồ
                      TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ chi nhánh *',
                          hintText: 'VD: 123 Phố Tràng Tiền, Quận Hoàn Kiếm, Hà Nội',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                            tooltip: 'Ghim trên Bản đồ',
                            onPressed: () async {
                              final result = await Navigator.push<Map<String, dynamic>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StoreMapScreen(
                                    isBranchPicker: true,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setSheetState(() {
                                  if (result['address'] != null) {
                                    addressController.text = result['address'].toString();
                                  }
                                  if (result['latitude'] != null) {
                                    latController.text = result['latitude'].toString();
                                  }
                                  if (result['longitude'] != null) {
                                    lngController.text = result['longitude'].toString();
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        validator: (v) =>
                            AppValidators.validateRequired(v, 'Địa chỉ'),
                      ),
                      const SizedBox(height: 8),

                      // Nút Ghim Bản đồ trực quan
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StoreMapScreen(
                                isBranchPicker: true,
                              ),
                            ),
                          );
                          if (result != null) {
                            setSheetState(() {
                              if (result['address'] != null) {
                                addressController.text = result['address'].toString();
                              }
                              if (result['latitude'] != null) {
                                latController.text = result['latitude'].toString();
                              }
                              if (result['longitude'] != null) {
                                lngController.text = result['longitude'].toString();
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.pin_drop_outlined, size: 18),
                        label: const Text(
                          'Ghim vị trí trên Bản đồ OpenStreetMap',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại hotline *',
                          hintText: 'VD: 0901234567 hoặc 1900 1234',
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
                              controller: latController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Vĩ độ (Latitude) *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => AppValidators.validateRequired(
                                v,
                                'Vĩ độ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: lngController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Kinh độ (Longitude) *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => AppValidators.validateRequired(
                                v,
                                'Kinh độ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tọa độ mẫu tiện lợi
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Hà Nội', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              setSheetState(() {
                                latController.text = '21.0285';
                                lngController.text = '105.8542';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('Đà Nẵng', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              setSheetState(() {
                                latController.text = '15.9689';
                                lngController.text = '108.2608';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('TP.HCM', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              setSheetState(() {
                                latController.text = '10.8411';
                                lngController.text = '106.8105';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isSaving = true);

                                  try {
                                    final branch = BranchModel(
                                      id: '',
                                      name: nameController.text.trim(),
                                      address: addressController.text.trim(),
                                      latitude: double.tryParse(
                                            latController.text.trim(),
                                          ) ??
                                          15.9689,
                                      longitude: double.tryParse(
                                            lngController.text.trim(),
                                          ) ??
                                          108.2608,
                                      phone: phoneController.text.trim(),
                                      createdAt: DateTime.now(),
                                    );

                                    await _firestoreService.addBranch(branch);

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '🎉 Đã thêm chi nhánh mới vào Firestore!',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() => isSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi thêm chi nhánh: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'LƯU CHI NHÁNH',
                                  style: TextStyle(
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
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      addressController.dispose();
      phoneController.dispose();
      latController.dispose();
      lngController.dispose();
    });
  }

  /// Sheet Chỉnh sửa Chi nhánh hiện có (Khóa Bẫy 19: Cập nhật Firestore)
  void _showEditBranchSheet(BuildContext context, BranchModel branch) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: branch.name);
    final addressController = TextEditingController(text: branch.address);
    final phoneController = TextEditingController(text: branch.phone);
    final latController =
        TextEditingController(text: branch.latitude.toString());
    final lngController =
        TextEditingController(text: branch.longitude.toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CHỈNH SỬA CHI NHÁNH',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên chi nhánh *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (v) =>
                            AppValidators.validateRequired(v, 'Tên chi nhánh'),
                      ),
                      const SizedBox(height: 12),

                      // Địa chỉ kèm nút Ghim Bản đồ
                      TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ chi nhánh *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                            tooltip: 'Ghim trên Bản đồ',
                            onPressed: () async {
                              final result = await Navigator.push<Map<String, dynamic>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StoreMapScreen(
                                    isBranchPicker: true,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setSheetState(() {
                                  if (result['address'] != null) {
                                    addressController.text = result['address'].toString();
                                  }
                                  if (result['latitude'] != null) {
                                    latController.text = result['latitude'].toString();
                                  }
                                  if (result['longitude'] != null) {
                                    lngController.text = result['longitude'].toString();
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        validator: (v) =>
                            AppValidators.validateRequired(v, 'Địa chỉ'),
                      ),
                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StoreMapScreen(
                                isBranchPicker: true,
                              ),
                            ),
                          );
                          if (result != null) {
                            setSheetState(() {
                              if (result['address'] != null) {
                                addressController.text = result['address'].toString();
                              }
                              if (result['latitude'] != null) {
                                latController.text = result['latitude'].toString();
                              }
                              if (result['longitude'] != null) {
                                lngController.text = result['longitude'].toString();
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.pin_drop_outlined, size: 18),
                        label: const Text(
                          'Ghim vị trí trên Bản đồ OpenStreetMap',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại hotline *',
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
                              controller: latController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Vĩ độ (Latitude) *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => AppValidators.validateRequired(
                                v,
                                'Vĩ độ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: lngController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Kinh độ (Longitude) *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => AppValidators.validateRequired(
                                v,
                                'Kinh độ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isSaving = true);

                                  try {
                                    final updatedBranch = branch.copyWith(
                                      name: nameController.text.trim(),
                                      address: addressController.text.trim(),
                                      latitude: double.tryParse(
                                            latController.text.trim(),
                                          ) ??
                                          branch.latitude,
                                      longitude: double.tryParse(
                                            lngController.text.trim(),
                                          ) ??
                                          branch.longitude,
                                      phone: phoneController.text.trim(),
                                    );

                                    await _firestoreService
                                        .updateBranch(updatedBranch);

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✅ Đã cập nhật chi nhánh "${updatedBranch.name}"!',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() => isSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi cập nhật chi nhánh: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'CẬP NHẬT CHI NHÁNH',
                                  style: TextStyle(
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
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      addressController.dispose();
      phoneController.dispose();
      latController.dispose();
      lngController.dispose();
    });
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
                    'Chưa có chi nhánh nào trên Firestore\nBấm nút bên dưới để thêm mới!',
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
              return Container(
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
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.storefront,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              branch.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
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
              );
            },
          );
        },
      ),
    );
  }
}
