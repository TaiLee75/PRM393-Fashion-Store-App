import 'package:cloud_firestore/cloud_firestore.dart';

/// Model thông tin người dùng trong hệ thống (Collection `users`)
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String avatarUrl;
  final String defaultAddress;
  final String role; // "customer" hoặc "admin"
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.phone = '',
    this.avatarUrl = '',
    this.defaultAddress = '',
    this.role = 'customer',
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    return UserModel(
      uid: id ?? map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      defaultAddress: map['defaultAddress'] as String? ?? '',
      role: map['role'] as String? ?? 'customer',
      createdAt: parseDate(map['createdAt']),
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
    );
  }
}
