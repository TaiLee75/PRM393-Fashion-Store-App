import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/branch_model.dart';
import '../../services/firestore_service.dart';

/// Màn hình Bản đồ OpenStreetMap hiển thị các chi nhánh từ Firestore real-time và cho phép chọn tọa độ giao hàng
class StoreMapScreen extends StatefulWidget {
  final bool isPickerMode;
  const StoreMapScreen({super.key, this.isPickerMode = false});

  @override
  State<StoreMapScreen> createState() => _StoreMapScreenState();
}

class _StoreMapScreenState extends State<StoreMapScreen> {
  final MapController _mapController = MapController();
  final FirestoreService _firestoreService = FirestoreService();

  LatLng _selectedPoint = const LatLng(15.9689, 108.2608); // Mặc định FPT Campus Đà Nẵng
  String _selectedAddressName = 'Khu đô thị FPT City, Ngũ Hành Sơn, Đà Nẵng';
  bool _isLoadingLocation = false;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    if (AppConstants.storeBranches.isNotEmpty) {
      _selectedPoint = AppConstants.storeBranches.first['location'] as LatLng;
      _selectedAddressName = AppConstants.storeBranches.first['address'] as String;
    }
  }

  /// Danh sách chi nhánh mặc định fallback
  List<BranchModel> _getDefaultBranches() {
    return AppConstants.storeBranches.map((b) {
      final loc = b['location'] as LatLng;
      return BranchModel(
        id: b['name'] as String,
        name: b['name'] as String,
        address: b['address'] as String,
        latitude: loc.latitude,
        longitude: loc.longitude,
        phone: '1900 1234',
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  /// Lấy vị trí GPS hiện tại của người dùng
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final userLatLng = LatLng(position.latitude, position.longitude);

        setState(() {
          _selectedPoint = userLatLng;
          _selectedBranchId = null;
          _selectedAddressName =
              'Vị trí GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });

        _mapController.move(userLatLng, 15.0);
      }
    } catch (_) {
      // Giữ vị trí mặc định nếu thiết bị không bật GPS
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _focusOnBranch(BranchModel branch) {
    setState(() {
      _selectedPoint = branch.location;
      _selectedBranchId = branch.id;
      _selectedAddressName = '${branch.name} - ${branch.address}';
    });
    _mapController.move(branch.location, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          widget.isPickerMode ? 'CHỌN ĐỊA CHỈ NHẬN HÀNG' : 'HỆ THỐNG CHI NHÁNH',
          style: const TextStyle(
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
      body: StreamBuilder<List<BranchModel>>(
        stream: _firestoreService.streamBranches(),
        builder: (context, snapshot) {
          final branches = (snapshot.hasData && snapshot.data!.isNotEmpty)
              ? snapshot.data!
              : _getDefaultBranches();

          return Stack(
            children: [
              // 1. OPENSTREETMAP BẰNG FLUTTER_MAP
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedPoint,
                  initialZoom: 13.5,
                  onTap: (tapPosition, point) {
                    if (widget.isPickerMode) {
                      setState(() {
                        _selectedPoint = point;
                        _selectedBranchId = null;
                        _selectedAddressName =
                            'Tọa độ giao hàng: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fptu.prm393.fashion_store_app',
                  ),
                  MarkerLayer(
                    markers: [
                      // Markers các Chi nhánh cửa hàng (từ Firestore Real-time)
                      ...branches.map((branch) {
                        final isSelected = branch.id == _selectedBranchId;
                        return Marker(
                          point: branch.location,
                          width: isSelected ? 56 : 46,
                          height: isSelected ? 56 : 46,
                          child: GestureDetector(
                            onTap: () => _focusOnBranch(branch),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : AppColors.primary,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.store_mall_directory,
                                color: isSelected ? Colors.white : AppColors.primary,
                                size: isSelected ? 30 : 24,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Marker điểm đang chọn nếu ở chế độ Picker Mode
                      if (widget.isPickerMode)
                        Marker(
                          point: _selectedPoint,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 44,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // 2. NÚT ĐỊNH VỊ GPS HIỆN TẠI
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'btnGpsLocation',
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.black,
                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),

              // 3. DANH SÁCH CHI NHÁNH LƯỚT NGANG (CAROUSEL)
              if (branches.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: widget.isPickerMode ? 140 : 100,
                  child: SizedBox(
                    height: 80,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: branches.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final b = branches[index];
                        final isSelected = b.id == _selectedBranchId;
                        return InkWell(
                          onTap: () => _focusOnBranch(b),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 240,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.store,
                                      size: 16,
                                      color: isSelected ? Colors.white : AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        b.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isSelected ? Colors.white : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  b.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.white70 : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // 4. THẺ THÔNG TIN ĐỊA CHỈ & NÚT XÁC NHẬN CHỌN
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddressName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      if (widget.isPickerMode) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, _selectedAddressName);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'XÁC NHẬN VỊ TRÍ GIAO HÀNG NÀY',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

