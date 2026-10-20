import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Màn hình Bản đồ OpenStreetMap hiển thị 2 chi nhánh và cho phép chọn tọa độ giao hàng
class StoreMapScreen extends StatefulWidget {
  final bool isPickerMode;
  const StoreMapScreen({super.key, this.isPickerMode = false});

  @override
  State<StoreMapScreen> createState() => _StoreMapScreenState();
}

class _StoreMapScreenState extends State<StoreMapScreen> {
  final MapController _mapController = MapController();
  LatLng _selectedPoint = const LatLng(15.9689, 108.2608); // Mặc định FPT Campus
  String _selectedAddressName = 'Khu đô thị FPT City, Ngũ Hành Sơn, Đà Nẵng';
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (AppConstants.storeBranches.isNotEmpty) {
      _selectedPoint = AppConstants.storeBranches.first['location'] as LatLng;
      _selectedAddressName = AppConstants.storeBranches.first['address'] as String;
    }
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
      body: Stack(
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
                  // Marker 2 Chi nhánh cố định của shop
                  ...AppConstants.storeBranches.map((branch) {
                    final LatLng pos = branch['location'] as LatLng;
                    return Marker(
                      point: pos,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPoint = pos;
                            _selectedAddressName = branch['address'] as String;
                          });
                        },
                        child: const Icon(
                          Icons.store_mall_directory,
                          color: AppColors.primary,
                          size: 38,
                        ),
                      ),
                    );
                  }),

                  // Marker điểm đang chọn nếu ở chế độ Picker
                  if (widget.isPickerMode)
                    Marker(
                      point: _selectedPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
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

          // 3. THẺ THÔNG TIN ĐỊA CHỈ & NÚT XÁC NHẬN CHỌN
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _selectedAddressName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('XÁC NHẬN VỊ TRÍ GIAO HÀNG NÀY'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
