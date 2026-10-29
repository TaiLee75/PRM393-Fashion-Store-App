import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/branch_model.dart';
import '../../services/firestore_service.dart';

/// Màn hình Bản đồ OpenStreetMap hiển thị các chi nhánh từ Firestore real-time
/// và hỗ trợ Chọn tọa độ giao hàng tận nơi (Picker Mode) kèm Reverse Geocoding (Khóa Bẫy 19)
class StoreMapScreen extends StatefulWidget {
  final bool isPickerMode;
  final bool isBranchPicker;

  const StoreMapScreen({
    super.key,
    this.isPickerMode = false,
    this.isBranchPicker = false,
  });

  @override
  State<StoreMapScreen> createState() => _StoreMapScreenState();
}

class _StoreMapScreenState extends State<StoreMapScreen> {
  final MapController _mapController = MapController();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _detailAddressController = TextEditingController();

  LatLng _selectedPoint = const LatLng(15.9689, 108.2608); // Mặc định FPT Campus Đà Nẵng
  LatLng? _userGpsLocation;
  String _selectedAddressName = '';
  bool _hasSelectedLocation = false;
  bool _isLoadingLocation = false;
  bool _isGeocoding = false;
  int _geocodeRequestId = 0;
  String? _selectedBranchId;
  Timer? _debounceTimer;

  late final Stream<List<BranchModel>> _branchesStream = _firestoreService.streamBranches();

  bool get isPicker => widget.isPickerMode || widget.isBranchPicker;

  @override
  void initState() {
    super.initState();
    if (isPicker) {
      // Khóa Bẫy 19: Tuyệt đối không gán sẵn tên/địa chỉ chi nhánh vào địa chỉ nhà của khách
      _hasSelectedLocation = false;
      _selectedAddressName = widget.isBranchPicker
          ? 'Chạm vào bản đồ hoặc bấm GPS để chọn vị trí chi nhánh'
          : 'Chạm vào bản đồ hoặc bấm nút GPS để chọn vị trí giao hàng';
      if (AppConstants.storeBranches.isNotEmpty) {
        _selectedPoint = AppConstants.storeBranches.first['location'] as LatLng;
      }
    } else {
      // Chế độ xem chi nhánh
      _hasSelectedLocation = true;
      if (AppConstants.storeBranches.isNotEmpty) {
        _selectedPoint = AppConstants.storeBranches.first['location'] as LatLng;
        _selectedAddressName =
            '${AppConstants.storeBranches.first['name']} - ${AppConstants.storeBranches.first['address']}';
        _selectedBranchId = AppConstants.storeBranches.first['name'] as String;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    _detailAddressController.dispose();
    super.dispose();
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

  /// Phân giải tọa độ ra địa chỉ chữ (OpenStreetMap Nominatim Reverse Geocoding)
  Future<void> _reverseGeocode(LatLng point) async {
    final currentRequestId = ++_geocodeRequestId;

    setState(() {
      _isGeocoding = true;
    });

    String resolved = '';
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'FashionStoreAppPRM393/1.0 (student-project)');
      request.headers.set('Accept-Language', 'vi');

      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;

        final addressObj = data['address'] as Map<String, dynamic>?;
        if (addressObj != null) {
          final houseNumber = addressObj['house_number'] as String?;
          final road = addressObj['road'] as String? ?? addressObj['pedestrian'] as String?;
          final suburb = addressObj['suburb'] as String? ??
              addressObj['neighbourhood'] as String? ??
              addressObj['quarter'] as String?;
          final district = addressObj['city_district'] as String? ??
              addressObj['district'] as String? ??
              addressObj['county'] as String?;
          final city = addressObj['city'] as String? ??
              addressObj['town'] as String? ??
              addressObj['state'] as String?;

          final parts = <String>[];
          if (houseNumber != null && houseNumber.isNotEmpty) parts.add(houseNumber);
          if (road != null && road.isNotEmpty) parts.add(road);
          if (suburb != null && suburb.isNotEmpty) parts.add(suburb);
          if (district != null && district.isNotEmpty) parts.add(district);
          if (city != null && city.isNotEmpty) parts.add(city);

          if (parts.length >= 2) {
            resolved = parts.join(', ');
          }
        }

        if (resolved.isEmpty) {
          final displayName = data['display_name'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            resolved = displayName;
          }
        }
      }
    } catch (_) {
      // Fallback khi offline, lỗi mạng hoặc trong môi trường test
    } finally {
      client?.close();
    }

    if (!mounted || currentRequestId != _geocodeRequestId) return;

    setState(() {
      _isGeocoding = false;
      if (resolved.isNotEmpty) {
        _selectedAddressName = resolved;
      }
    });
  }

  /// Lấy vị trí GPS hiện tại của người dùng (Chống ANR trên máy ảo với getLastKnownPosition trước)
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng bật định vị GPS hoặc chạm trực tiếp vào bản đồ!'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quyền định vị bị từ chối. Vui lòng chạm trực tiếp vào bản đồ để chọn vị trí!'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // 1. Thử lấy vị trí cache đã biết trước (tức thì 0ms, không gây ANR treo main thread)
        Position? position;
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}

        // 2. Nếu chưa có vị trí cache, thử lấy vị trí hiện tại với timeout an toàn
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 3),
              ),
            );
          } catch (_) {
            position = null;
          }
        }

        // 3. Fallback thông minh: Nếu máy ảo chưa được cấp tọa độ trong Extended Controls,
        // tự động định vị tại FPT Campus Đà Nẵng để trải nghiệm người dùng luôn thông suốt
        final LatLng targetLatLng;
        final bool isMockFallback;
        if (position != null) {
          targetLatLng = LatLng(position.latitude, position.longitude);
          isMockFallback = false;
        } else {
          targetLatLng = const LatLng(15.9689, 108.2608); // FPT Campus Đà Nẵng
          isMockFallback = true;
        }

        if (!mounted) return;
        setState(() {
          _userGpsLocation = targetLatLng;
          _selectedPoint = targetLatLng;
          _selectedBranchId = null;
          _hasSelectedLocation = true;
          _selectedAddressName =
              'Vị trí của bạn: ${targetLatLng.latitude.toStringAsFixed(4)}, ${targetLatLng.longitude.toStringAsFixed(4)}';
        });

        _mapController.move(targetLatLng, 15.5);
        if (isPicker) {
          _reverseGeocode(targetLatLng);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMockFallback
                    ? '📍 Đã định vị tại FPT Campus Đà Nẵng (Máy ảo: mở [...] > Location > Send để cấp tọa độ tùy ý)'
                    : '📍 Đã cập nhật vị trí GPS thành công!',
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể lấy vị trí GPS. Bạn hãy chạm trực tiếp vào bản đồ để chọn vị trí nhé!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _focusOnBranch(BranchModel branch) {
    if (widget.isPickerMode) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đây là "${branch.name}". Vui lòng chạm vào vị trí bạn muốn nhận hàng trên bản đồ!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      _mapController.move(branch.location, 15.5);
      return;
    }

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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.isBranchPicker
              ? 'CHỌN TỌA ĐỘ CHI NHÁNH'
              : (widget.isPickerMode
                  ? 'CHỌN ĐỊA CHỈ NHẬN HÀNG'
                  : 'HỆ THỐNG CHI NHÁNH'),
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
        stream: _branchesStream,
        builder: (context, snapshot) {
          final rawBranches = (snapshot.hasData && snapshot.data!.isNotEmpty)
              ? snapshot.data!
              : _getDefaultBranches();
          final branches = List<BranchModel>.from(rawBranches);

          if (_userGpsLocation != null) {
            branches.sort((a, b) {
              final dA = Geolocator.distanceBetween(
                _userGpsLocation!.latitude,
                _userGpsLocation!.longitude,
                a.latitude,
                a.longitude,
              );
              final dB = Geolocator.distanceBetween(
                _userGpsLocation!.latitude,
                _userGpsLocation!.longitude,
                b.latitude,
                b.longitude,
              );
              return dA.compareTo(dB);
            });
          }

          return Stack(
            children: [
              // 1. OPENSTREETMAP BẰNG FLUTTER_MAP
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedPoint,
                  initialZoom: 13.5,
                  onTap: (tapPosition, point) {
                    if (isPicker) {
                      setState(() {
                        _selectedPoint = point;
                        _selectedBranchId = null;
                        _hasSelectedLocation = true;
                        _selectedAddressName =
                            'Vị trí đã chọn: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
                      });
                      _debounceTimer?.cancel();
                      _debounceTimer =
                          Timer(const Duration(milliseconds: 500), () {
                        _reverseGeocode(point);
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    fallbackUrl: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.fptu.prm393.fashion_store_app',
                    maxZoom: 19.0,
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
                            child: Container(
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

                      // Marker điểm đang chọn nếu ở chế độ Picker Mode (Khóa Bẫy 19)
                      if (isPicker && _hasSelectedLocation)
                        Marker(
                          point: _selectedPoint,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 48,
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

              // 3. DANH SÁCH CHI NHÁNH LƯỚT NGANG (Chỉ hiển thị khi ở Viewer Mode để không gây nhiễu khi Picker)
              if (!isPicker && branches.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 110,
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
                        String? distanceStr;
                        if (_userGpsLocation != null) {
                          final meters = Geolocator.distanceBetween(
                            _userGpsLocation!.latitude,
                            _userGpsLocation!.longitude,
                            b.latitude,
                            b.longitude,
                          );
                          distanceStr = meters < 1000
                              ? '${meters.round()}m'
                              : '${(meters / 1000).toStringAsFixed(1)}km';
                        }
                        return InkWell(
                          onTap: () => _focusOnBranch(b),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 250,
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
                                    if (distanceStr != null) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.25)
                                              : AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          distanceStr,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
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

              // 4. THẺ THÔNG TIN ĐỊA CHỈ & NÚT XÁC NHẬN CHỌN (Khóa Bẫy 19)
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
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trạng thái địa chỉ đang chọn / loading
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _hasSelectedLocation ? Icons.location_on : Icons.touch_app_outlined,
                            color: _hasSelectedLocation ? AppColors.primary : AppColors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isGeocoding
                                ? const Row(
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Đang phân giải địa chỉ...',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _selectedAddressName,
                                    style: TextStyle(
                                      fontWeight: _hasSelectedLocation ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                      color: _hasSelectedLocation ? AppColors.textPrimary : AppColors.textSecondary,
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      // Ô nhập chi tiết số nhà (Chỉ hiện khi ở Picker Mode)
                      if (isPicker) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _detailAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Chi tiết số nhà, ngõ/ngách, phòng/tầng',
                            hintText: 'VD: Số 123 ngõ 4, Tầng 3 Chung cư A...',
                            hintStyle: TextStyle(fontSize: 11),
                            prefixIcon: Icon(Icons.home_outlined, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_hasSelectedLocation && !_isGeocoding)
                                ? () {
                                    final detail = _detailAddressController.text.trim();
                                    final fullAddress = detail.isNotEmpty
                                        ? '$detail, $_selectedAddressName'
                                        : _selectedAddressName;
                                    Navigator.pop(context, {
                                      'address': fullAddress,
                                      'latitude': _selectedPoint.latitude,
                                      'longitude': _selectedPoint.longitude,
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              _isGeocoding
                                  ? 'ĐANG TÌM ĐỊA CHỈ...'
                                  : (_hasSelectedLocation
                                      ? (widget.isBranchPicker
                                          ? 'XÁC NHẬN TỌA ĐỘ CHI NHÁNH NÀY'
                                          : 'XÁC NHẬN VỊ TRÍ GIAO HÀNG NÀY')
                                      : 'CHẠM BẢN ĐỒ ĐỂ CHỌN ĐỊA CHỈ'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
