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
  final String? viewOrderAddress;
  final String? viewOrderRecipient;
  final LatLng? viewOrderLocation;

  const StoreMapScreen({
    super.key,
    this.isPickerMode = false,
    this.isBranchPicker = false,
    this.viewOrderAddress,
    this.viewOrderRecipient,
    this.viewOrderLocation,
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
  bool get isOrderViewMode => widget.viewOrderAddress != null;

  @override
  void initState() {
    super.initState();
    if (isOrderViewMode) {
      _hasSelectedLocation = true;
      _selectedAddressName = widget.viewOrderAddress!;
      if (widget.viewOrderLocation != null) {
        _selectedPoint = widget.viewOrderLocation!;
      } else {
        if (AppConstants.storeBranches.isNotEmpty) {
          _selectedPoint = AppConstants.storeBranches.first['location'] as LatLng;
        }
        // Phân giải tự động địa chỉ chữ ra tọa độ chính xác nếu đơn hàng chưa lưu sẵn tọa độ
        _forwardGeocode(widget.viewOrderAddress!);
      }
    } else if (isPicker) {
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

  /// Phân giải tọa độ ra địa chỉ chữ đa tầng (Photon OSM -> BigDataCloud -> Nominatim -> Offline Fallback)
  Future<void> _reverseGeocode(LatLng point) async {
    final currentRequestId = ++_geocodeRequestId;

    setState(() {
      _isGeocoding = true;
    });

    String resolved = '';

    // TẦNG 1: Photon OpenStreetMap API (Siêu nhanh, không bị reset connection, dữ liệu OSM chi tiết)
    try {
      final jsonStr = await _fetchJsonString(
        'https://photon.komoot.io/reverse?lat=${point.latitude}&lon=${point.longitude}&lang=default',
      );
      if (jsonStr != null && jsonStr.isNotEmpty) {
        resolved = _parsePhotonResponse(jsonStr);
      }
    } catch (_) {}

    // TẦNG 2: BigDataCloud Client Reverse Geocode API (Dự phòng độ khả dụng cao)
    if (resolved.isEmpty) {
      try {
        final jsonStr = await _fetchJsonString(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${point.latitude}&longitude=${point.longitude}&localityLanguage=vi',
        );
        if (jsonStr != null && jsonStr.isNotEmpty) {
          resolved = _parseBigDataCloudResponse(jsonStr);
        }
      } catch (_) {}
    }

    // TẦNG 3: Nominatim OpenStreetMap API
    if (resolved.isEmpty) {
      try {
        final jsonStr = await _fetchJsonString(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
          headers: {'Accept-Language': 'vi'},
        );
        if (jsonStr != null && jsonStr.isNotEmpty) {
          resolved = _parseNominatimResponse(jsonStr);
        }
      } catch (_) {}
    }

    // TẦNG 4: Offline Regional Proximity Fallback (Đảm bảo 100% không bao giờ để trơ trọi tọa độ số)
    if (resolved.isEmpty) {
      resolved = _getRegionalFallback(point);
    }

    if (!mounted || currentRequestId != _geocodeRequestId) return;

    setState(() {
      _isGeocoding = false;
      if (resolved.isNotEmpty) {
        _selectedAddressName = resolved;
      }
    });
  }

  /// Phân giải địa chỉ chữ ra tọa độ bản đồ (Forward Geocode) khi đơn hàng chỉ có địa chỉ text
  Future<void> _forwardGeocode(String address) async {
    final clean = address.trim();
    if (clean.isEmpty) return;

    // Tầng 1: Photon OpenStreetMap Search API
    try {
      final jsonStr = await _fetchJsonString(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(clean)}&limit=1',
      );
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final first = features.first as Map<String, dynamic>;
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 2) {
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final point = LatLng(lat, lon);
            if (!mounted) return;
            setState(() {
              _selectedPoint = point;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mapController.move(point, 15.5);
            });
            return;
          }
        }
      }
    } catch (_) {}

    // Tầng 2: Nominatim OpenStreetMap Search
    try {
      final jsonStr = await _fetchJsonString(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&limit=1',
        headers: {'Accept-Language': 'vi'},
      );
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as List<dynamic>;
        if (data.isNotEmpty) {
          final first = data.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final point = LatLng(lat, lon);
            if (!mounted) return;
            setState(() {
              _selectedPoint = point;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mapController.move(point, 15.5);
            });
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<String?> _fetchJsonString(String url, {Map<String, String>? headers}) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'FashionStoreAppPRM393/1.0 (student-project)');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach((k, v) => request.headers.set(k, v));
      }
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return await response.transform(utf8.decoder).join();
      }
    } catch (_) {
      // Fallback
    } finally {
      client?.close();
    }
    return null;
  }

  String _parsePhotonResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return '';

      final firstFeature = features.first as Map<String, dynamic>;
      final props = firstFeature['properties'] as Map<String, dynamic>?;
      if (props == null) return '';

      final name = props['name'] as String?;
      final houseNumber = props['housenumber'] as String?;
      final street = props['street'] as String?;
      final district = props['district'] as String?;
      final city = props['city'] as String?;

      final parts = <String>[];
      if (name != null && name.isNotEmpty && name != street) {
        parts.add(name);
      }
      if (houseNumber != null && houseNumber.isNotEmpty && street != null && street.isNotEmpty) {
        parts.add('$houseNumber $street');
      } else {
        if (street != null && street.isNotEmpty) parts.add(street);
        if (houseNumber != null && houseNumber.isNotEmpty) parts.add(houseNumber);
      }
      if (district != null && district.isNotEmpty) parts.add(district);
      if (city != null && city.isNotEmpty) parts.add(city);

      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    } catch (_) {}
    return '';
  }

  String _parseBigDataCloudResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final locality = data['locality'] as String?;
      final city = data['city'] as String? ?? data['principalSubdivision'] as String?;
      final parts = <String>[];
      if (locality != null && locality.isNotEmpty) parts.add(locality);
      if (city != null && city.isNotEmpty) parts.add(city);
      if (parts.isNotEmpty) return parts.join(', ');
    } catch (_) {}
    return '';
  }

  String _parseNominatimResponse(String body) {
    try {
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
          return parts.join(', ');
        }
      }

      final displayName = data['display_name'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
    } catch (_) {}
    return '';
  }

  String _getRegionalFallback(LatLng point) {
    // 1. Kiểm tra lân cận các chi nhánh trong hệ thống
    for (final branch in AppConstants.storeBranches) {
      final loc = branch['location'] as LatLng?;
      if (loc != null) {
        final distance = Geolocator.distanceBetween(
          point.latitude,
          point.longitude,
          loc.latitude,
          loc.longitude,
        );
        if (distance <= 3000) {
          return 'Gần ${branch['name']} (${(distance / 1000).toStringAsFixed(1)}km), ${branch['address']}';
        }
      }
    }

    // 2. Tự động nhận diện khu vực địa lý đô thị chính
    if (point.latitude >= 15.8 && point.latitude <= 16.3 &&
        point.longitude >= 108.0 && point.longitude <= 108.5) {
      if (point.latitude <= 16.02) {
        return 'Khu vực Ngũ Hành Sơn, Hòa Hải, Đà Nẵng';
      }
      return 'Khu vực Trung tâm TP. Đà Nẵng';
    } else if (point.latitude >= 10.5 && point.latitude <= 11.2 &&
        point.longitude >= 106.3 && point.longitude <= 107.0) {
      return 'Khu vực TP. Hồ Chí Minh';
    } else if (point.latitude >= 20.8 && point.latitude <= 21.4 &&
        point.longitude >= 105.5 && point.longitude <= 106.2) {
      return 'Khu vực Thủ đô Hà Nội';
    }

    return 'Vị trí đã chọn: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
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
          _isGeocoding = true;
          _selectedAddressName =
              'Đang định vị GPS (${targetLatLng.latitude.toStringAsFixed(4)}, ${targetLatLng.longitude.toStringAsFixed(4)})...';
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

    if (!branch.isActive && !widget.isPickerMode && !widget.isBranchPicker) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏸️ "${branch.name}" hiện đang tạm ngừng hoạt động đón khách.',
          ),
          backgroundColor: AppColors.black,
          duration: const Duration(seconds: 2),
        ),
      );
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
          isOrderViewMode
              ? 'VỊ TRÍ GIAO HÀNG'
              : (widget.isBranchPicker
                  ? 'CHỌN TỌA ĐỘ CHI NHÁNH'
                  : (widget.isPickerMode
                      ? 'CHỌN ĐỊA CHỈ NHẬN HÀNG'
                      : 'HỆ THỐNG CHI NHÁNH')),
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
                        _isGeocoding = true;
                        _selectedAddressName =
                            'Đang phân giải địa chỉ (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})...';
                      });
                      _debounceTimer?.cancel();
                      _debounceTimer =
                          Timer(const Duration(milliseconds: 250), () {
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
                        final active = branch.isActive;
                        final markerBg = isSelected
                            ? (active ? AppColors.primary : Colors.grey.shade700)
                            : (active ? Colors.white : Colors.grey.shade100);
                        final markerBorder = isSelected
                            ? Colors.white
                            : (active ? AppColors.primary : Colors.grey.shade400);
                        final markerIconColor = isSelected
                            ? Colors.white
                            : (active ? AppColors.primary : Colors.grey.shade500);
                        return Marker(
                          point: branch.location,
                          width: isSelected ? 56 : 46,
                          height: isSelected ? 56 : 46,
                          child: GestureDetector(
                            onTap: () => _focusOnBranch(branch),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: markerBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: markerBorder,
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
                                color: markerIconColor,
                                size: isSelected ? 30 : 24,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Marker điểm đang chọn nếu ở chế độ Picker Mode hoặc Order View Mode
                      if ((isPicker && _hasSelectedLocation) || isOrderViewMode)
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
              if (!isPicker && !isOrderViewMode && branches.isNotEmpty)
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
                              color: isSelected
                                  ? (b.isActive ? AppColors.primary : Colors.grey.shade700)
                                  : (b.isActive ? Colors.white : const Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? (b.isActive ? AppColors.primary : Colors.grey.shade700)
                                    : (b.isActive ? Colors.grey.shade300 : Colors.grey.shade400),
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
                                      color: isSelected
                                          ? Colors.white
                                          : (b.isActive ? AppColors.primary : Colors.grey),
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
                                          color: isSelected
                                              ? Colors.white
                                              : (b.isActive ? AppColors.textPrimary : Colors.grey.shade700),
                                        ),
                                      ),
                                    ),
                                    if (!b.isActive) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.25)
                                              : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          'TẠM ĐÓNG',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
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
                child: isOrderViewMode
                    ? _buildOrderLocationBottomSheet()
                    : Container(
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

  Widget _buildOrderLocationBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ĐỊA CHỈ GIAO HÀNG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Vị trí nhận hàng của đơn hàng',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.ultraLightGrey,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.viewOrderAddress ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.viewOrderRecipient != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.viewOrderRecipient!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'QUAY LẠI ĐƠN HÀNG',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
