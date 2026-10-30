import 'package:cloud_firestore/cloud_firestore.dart';

/// Model thông tin người dùng trong hệ thống (Collection `users`) chuẩn Enterprise
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String avatarUrl;
  final String defaultAddress;
  final String role; // "customer" hoặc "admin"
  final DateTime createdAt;

  // Tính năng nâng cao Enterprise
  final List<Map<String, dynamic>> savedAddresses; // Sổ địa chỉ giao hàng
  final List<String> wishlistProductIds; // Danh sách ID sản phẩm yêu thích
  final Map<String, num>? bodyMeasurements; // Số đo cơ thể: {'height': 175, 'weight': 68}

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.phone = '',
    this.avatarUrl = '',
    this.defaultAddress = '',
    this.role = 'customer',
    required this.createdAt,
    this.savedAddresses = const [],
    this.wishlistProductIds = const [],
    this.bodyMeasurements,
  });

  /// Kiểm tra quyền Quản trị viên
  bool get isAdmin => role.toLowerCase() == 'admin';

  /// Kiểm tra một sản phẩm có nằm trong danh sách yêu thích hay không
  bool isFavorite(String productId) => wishlistProductIds.contains(productId);

  /// Chiều cao đã lưu (cm)
  double? get savedHeight => bodyMeasurements?['height']?.toDouble();

  /// Cân nặng đã lưu (kg)
  double? get savedWeight => bodyMeasurements?['weight']?.toDouble();

  /// Địa chỉ nhận hàng ưu tiên:
  /// 1. Nếu có địa chỉ trong sổ địa chỉ được người dùng chủ động tick 'isDefault == true' -> Lấy địa chỉ đó.
  /// 2. Nếu không có địa chỉ nào trong sổ có isDefault == true (hoặc sổ trống) -> Luôn lấy defaultAddress của Hồ sơ chính!
  String get effectiveDefaultAddress {
    if (savedAddresses.isNotEmpty) {
      final defaultItem = savedAddresses.firstWhere(
        (a) => a['isDefault'] == true,
        orElse: () => const {},
      );
      final addr = defaultItem['address'] as String? ?? '';
      if (addr.isNotEmpty) return addr;
    }
    return defaultAddress;
  }

  /// Họ tên người nhận ưu tiên (Lấy từ mục mặc định trong sổ địa chỉ nếu có, hoặc fallback về fullName)
  String get effectiveRecipientName {
    if (savedAddresses.isNotEmpty) {
      final defaultItem = savedAddresses.firstWhere(
        (a) => a['isDefault'] == true,
        orElse: () => const {},
      );
      final name = defaultItem['recipientName'] as String? ?? '';
      if (name.isNotEmpty) return name;
    }
    return fullName;
  }

  /// Số điện thoại người nhận ưu tiên (Lấy từ mục mặc định trong sổ địa chỉ nếu có, hoặc fallback về phone)
  String get effectivePhone {
    if (savedAddresses.isNotEmpty) {
      final defaultItem = savedAddresses.firstWhere(
        (a) => a['isDefault'] == true,
        orElse: () => const {},
      );
      final p = defaultItem['phone'] as String? ?? '';
      if (p.isNotEmpty) return p;
    }
    return phone;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    // Parse an toàn danh sách địa chỉ đã lưu
    final List<Map<String, dynamic>> parsedAddresses = [];
    if (map['savedAddresses'] is List) {
      for (final item in map['savedAddresses'] as List) {
        if (item is Map) {
          parsedAddresses.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Parse an toàn danh sách sản phẩm yêu thích
    final List<String> parsedWishlist = [];
    if (map['wishlistProductIds'] is List) {
      for (final item in map['wishlistProductIds'] as List) {
        if (item != null) {
          parsedWishlist.add(item.toString());
        }
      }
    }

    // Parse an toàn số đo cơ thể
    Map<String, num>? parsedMeasurements;
    if (map['bodyMeasurements'] is Map) {
      parsedMeasurements = {};
      (map['bodyMeasurements'] as Map).forEach((k, v) {
        if (v is num) {
          parsedMeasurements![k.toString()] = v;
        }
      });
    }

    return UserModel(
      uid: id ?? map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      defaultAddress: map['defaultAddress'] as String? ?? '',
      role: (map['role'] as String?)?.toLowerCase() ?? 'customer',
      createdAt: parseDate(map['createdAt']),
      savedAddresses: parsedAddresses,
      wishlistProductIds: parsedWishlist,
      bodyMeasurements: parsedMeasurements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'defaultAddress': defaultAddress,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'savedAddresses': savedAddresses,
      'wishlistProductIds': wishlistProductIds,
      'bodyMeasurements': bodyMeasurements,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? defaultAddress,
    String? role,
    DateTime? createdAt,
    List<Map<String, dynamic>>? savedAddresses,
    List<String>? wishlistProductIds,
    Map<String, num>? bodyMeasurements,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultAddress: defaultAddress ?? this.defaultAddress,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      wishlistProductIds: wishlistProductIds ?? this.wishlistProductIds,
      bodyMeasurements: bodyMeasurements ?? this.bodyMeasurements,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid);

  @override
  int get hashCode => uid.hashCode;
}
