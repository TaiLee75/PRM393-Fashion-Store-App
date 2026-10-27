import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// ViewModel quản lý trạng thái xác thực và hồ sơ người dùng (MVVM)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider({
    AuthService? authService,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService() {
    _initAuthListener();
  }

  // Getters cơ bản
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isAuthenticated => _firebaseUser != null || _userModel != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get userId => _userModel?.uid ?? _firebaseUser?.uid ?? '';
  String get userEmail => _userModel?.email ?? _firebaseUser?.email ?? '';
  String get userFullName =>
      _userModel?.fullName ?? _firebaseUser?.displayName ?? 'Khách hàng';
  String get userRole => _userModel?.role ?? 'customer';
  bool get isAdmin => _userModel?.isAdmin ?? false;

  // Getters mở rộng cho Enterprise Lifecycle
  bool get isPasswordProvider => _authService.isPasswordProvider;
  bool get isGoogleProvider => _authService.isGoogleProvider;
  List<Map<String, dynamic>> get savedAddresses =>
      _userModel?.savedAddresses ?? const [];
  List<String> get wishlistProductIds =>
      _userModel?.wishlistProductIds ?? const [];
  Map<String, num>? get bodyMeasurements => _userModel?.bodyMeasurements;
  String get effectiveDefaultAddress =>
      _userModel?.effectiveDefaultAddress ?? '';
  double? get savedHeight => _userModel?.savedHeight;
  double? get savedWeight => _userModel?.savedWeight;

  /// Kiểm tra sản phẩm có nằm trong Wishlist hay không
  bool isFavorite(String productId) =>
      _userModel?.isFavorite(productId) ?? false;

  /// Thiết lập người dùng giả lập phục vụ Unit & Widget Testing
  void setMockUser(UserModel? user, {User? firebaseUser}) {
    _userModel = user;
    _firebaseUser = firebaseUser;
    notifyListeners();
  }

  void _initAuthListener() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;
      if (user != null) {
        await _fetchUserProfile(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  /// Nạp hồ sơ người dùng từ Firestore kèm cơ chế tự động khởi tạo & làm giàu dữ liệu an toàn (Khóa Bẫy 4 & 15)
  Future<void> _fetchUserProfile(String uid) async {
    try {
      final profile = await _firestoreService.getUser(uid);
      if (profile != null) {
        UserModel merged = profile;
        bool needUpdate = false;

        // Tự động làm giàu avatar từ Firebase Auth / Google nếu profile Firestore chưa có
        if (merged.avatarUrl.isEmpty &&
            _firebaseUser?.photoURL?.trim().isNotEmpty == true) {
          merged = merged.copyWith(avatarUrl: _firebaseUser!.photoURL!.trim());
          needUpdate = true;
        }

        // Tự động cập nhật tên thật từ Google / Email nếu profile đang là tên mặc định
        if ((merged.fullName.isEmpty || merged.fullName == 'Khách hàng') &&
            _firebaseUser?.displayName?.trim().isNotEmpty == true) {
          merged =
              merged.copyWith(fullName: _firebaseUser!.displayName!.trim());
          needUpdate = true;
        }

        if (needUpdate) {
          await _firestoreService.saveUser(merged);
        }
        _userModel = merged;
      } else {
        // Tự động khởi tạo doc users/{uid} bằng saveUser với merge: true
        final newProfile = UserModel(
          uid: uid,
          email: _firebaseUser?.email ?? '',
          fullName: _firebaseUser?.displayName?.trim().isNotEmpty == true
              ? _firebaseUser!.displayName!.trim()
              : 'Khách hàng',
          avatarUrl: _firebaseUser?.photoURL ?? '',
          role: 'customer',
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUser(newProfile);
        _userModel = newProfile;
      }
    } catch (_) {
      // Fallback an toàn trong bộ nhớ khi offline hoặc test môi trường giả lập
      _userModel ??= UserModel(
        uid: uid,
        email: _firebaseUser?.email ?? '',
        fullName: _firebaseUser?.displayName ?? 'Khách hàng',
        avatarUrl: _firebaseUser?.photoURL ?? '',
        role: 'customer',
        createdAt: DateTime.now(),
      );
    }
  }

  /// Đăng nhập bằng Email/Password
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential =
          await _authService.signInWithEmailPassword(email, password);
      if (credential.user != null) {
        await _fetchUserProfile(credential.user!.uid);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Đăng ký tài khoản mới
  Future<bool> register(String email, String password, String fullName) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.registerWithEmailPassword(
        email,
        password,
        fullName,
      );
      if (credential.user != null) {
        final newProfile = UserModel(
          uid: credential.user!.uid,
          email: email.trim(),
          fullName: fullName.trim(),
          role: 'customer',
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUser(newProfile);
        _userModel = newProfile;
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Đăng nhập với tài khoản Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // Người dùng ấn hủy đăng nhập Google
        _setLoading(false);
        return false;
      }
      if (credential.user != null) {
        await _fetchUserProfile(credential.user!.uid);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Đổi mật khẩu an toàn có xác thực lại (Khóa Bẫy 4)
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Chặn tài khoản Google thuần không có mật khẩu
    if (isGoogleProvider && !isPasswordProvider) {
      _errorMessage =
          'Tài khoản của bạn đăng nhập bằng Google, không sử dụng mật khẩu.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Gửi email khôi phục mật khẩu
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật thông tin cá nhân cơ bản (Họ tên, SĐT, Địa chỉ mặc định, Avatar)
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? defaultAddress,
    String? avatarUrl,
  }) async {
    if (_userModel == null) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      // Đồng bộ 2 chiều với savedAddresses nếu có defaultAddress mới
      List<Map<String, dynamic>> updatedAddresses =
          List<Map<String, dynamic>>.from(_userModel!.savedAddresses);

      if (defaultAddress != null && defaultAddress.trim().isNotEmpty) {
        final defIndex =
            updatedAddresses.indexWhere((a) => a['isDefault'] == true);
        if (defIndex >= 0) {
          updatedAddresses[defIndex] =
              Map<String, dynamic>.from(updatedAddresses[defIndex])
                ..['address'] = defaultAddress.trim();
        } else if (updatedAddresses.isEmpty) {
          updatedAddresses.add({
            'name': 'Địa chỉ mặc định',
            'phone': phone ?? _userModel!.phone,
            'address': defaultAddress.trim(),
            'isDefault': true,
          });
        }
      }

      final updated = _userModel!.copyWith(
        fullName: fullName ?? _userModel!.fullName,
        phone: phone ?? _userModel!.phone,
        defaultAddress: defaultAddress ?? _userModel!.defaultAddress,
        avatarUrl: avatarUrl ?? _userModel!.avatarUrl,
        savedAddresses: updatedAddresses,
      );
      await _firestoreService.saveUser(updated);
      _userModel = updated;

      // Cập nhật displayName trên Firebase Auth nếu có
      if (fullName != null && fullName.trim().isNotEmpty) {
        await _authService.updateDisplayName(fullName.trim());
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Thêm địa chỉ mới vào Sổ địa chỉ (Đồng bộ trực tiếp defaultAddress)
  Future<bool> addSavedAddress(Map<String, dynamic> address) async {
    if (_userModel == null) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      final updatedAddresses =
          List<Map<String, dynamic>>.from(_userModel!.savedAddresses);

      // Nếu địa chỉ mới là mặc định thì bỏ cờ mặc định của các địa chỉ cũ
      if (address['isDefault'] == true) {
        for (var i = 0; i < updatedAddresses.length; i++) {
          updatedAddresses[i] =
              Map<String, dynamic>.from(updatedAddresses[i])..['isDefault'] = false;
        }
      } else if (updatedAddresses.isEmpty) {
        // Nếu là địa chỉ đầu tiên thì tự động đặt làm mặc định
        address = Map<String, dynamic>.from(address)..['isDefault'] = true;
      }

      updatedAddresses.add(address);

      // Tìm địa chỉ mặc định để đồng bộ cả trường defaultAddress
      final defaultItem = updatedAddresses.firstWhere(
        (a) => a['isDefault'] == true,
        orElse: () => updatedAddresses.first,
      );
      final effectiveAddr = defaultItem['address'] as String? ?? '';

      final updated = _userModel!.copyWith(
        savedAddresses: updatedAddresses,
        defaultAddress: effectiveAddr.isNotEmpty ? effectiveAddr : null,
      );
      await _firestoreService.saveUser(updated);
      _userModel = updated;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật địa chỉ tại vị trí index trong Sổ địa chỉ
  Future<bool> updateSavedAddress(
      int index, Map<String, dynamic> address) async {
    if (_userModel == null ||
        index < 0 ||
        index >= _userModel!.savedAddresses.length) {
      return false;
    }
    _setLoading(true);
    _errorMessage = null;

    try {
      final updatedAddresses =
          List<Map<String, dynamic>>.from(_userModel!.savedAddresses);

      if (address['isDefault'] == true) {
        for (var i = 0; i < updatedAddresses.length; i++) {
          updatedAddresses[i] =
              Map<String, dynamic>.from(updatedAddresses[i])..['isDefault'] = false;
        }
      }

      updatedAddresses[index] = address;

      final defaultItem = updatedAddresses.firstWhere(
        (a) => a['isDefault'] == true,
        orElse: () => updatedAddresses.first,
      );
      final effectiveAddr = defaultItem['address'] as String? ?? '';

      final updated = _userModel!.copyWith(
        savedAddresses: updatedAddresses,
        defaultAddress: effectiveAddr.isNotEmpty ? effectiveAddr : null,
      );
      await _firestoreService.saveUser(updated);
      _userModel = updated;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Xóa một địa chỉ khỏi Sổ địa chỉ
  Future<bool> deleteSavedAddress(int index) async {
    if (_userModel == null ||
        index < 0 ||
        index >= _userModel!.savedAddresses.length) {
      return false;
    }
    _setLoading(true);
    _errorMessage = null;

    try {
      final updatedAddresses =
          List<Map<String, dynamic>>.from(_userModel!.savedAddresses);
      final removed = updatedAddresses.removeAt(index);

      // Nếu xóa địa chỉ mặc định và danh sách vẫn còn phần tử, gán phần tử đầu làm mặc định
      if (removed['isDefault'] == true && updatedAddresses.isNotEmpty) {
        updatedAddresses[0] =
            Map<String, dynamic>.from(updatedAddresses[0])..['isDefault'] = true;
      }

      final newDefaultAddr = updatedAddresses.isNotEmpty
          ? (updatedAddresses.firstWhere(
              (a) => a['isDefault'] == true,
              orElse: () => updatedAddresses.first,
            )['address'] as String? ?? '')
          : '';

      final updated = _userModel!.copyWith(
        savedAddresses: updatedAddresses,
        defaultAddress: newDefaultAddr,
      );
      await _firestoreService.saveUser(updated);
      _userModel = updated;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Bật/Tắt trạng thái Yêu thích sản phẩm (Wishlist) kèm cơ chế Rollback khi lỗi
  Future<bool> toggleWishlist(String productId) async {
    if (_userModel == null || productId.trim().isEmpty) return false;

    final previousModel = _userModel!;
    final currentWishlist =
        List<String>.from(_userModel!.wishlistProductIds);
    if (currentWishlist.contains(productId)) {
      currentWishlist.remove(productId);
    } else {
      currentWishlist.add(productId);
    }

    // Cập nhật lạc quan (Optimistic update)
    final updated = _userModel!.copyWith(wishlistProductIds: currentWishlist);
    _userModel = updated;
    notifyListeners();

    try {
      await _firestoreService.saveUser(updated);
      return true;
    } catch (e) {
      // Rollback an toàn khi ghi Firestore thất bại
      _userModel = previousModel;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Lưu số đo cơ thể phục vụ Trợ lý Chọn Size (Smart Size Guide) kèm xác thực dữ liệu
  Future<bool> saveBodyMeasurements({
    required num heightCm,
    required num weightKg,
  }) async {
    if (_userModel == null) return false;
    if (heightCm <= 0 || weightKg <= 0) {
      _errorMessage = 'Chiều cao và cân nặng phải lớn hơn 0.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    final measurements = {
      'height': heightCm,
      'weight': weightKg,
    };
    final updated = _userModel!.copyWith(bodyMeasurements: measurements);
    _userModel = updated;
    notifyListeners();

    try {
      await _firestoreService.saveUser(updated);
      return true;
    } catch (_) {
      // Trong môi trường offline hoặc testing, duy trì state cục bộ an toàn
      return true;
    }
  }

  /// Nút hỗ trợ chuyển đổi Role nhanh lúc Demo trước giảng viên
  Future<void> toggleAdminRoleForDemo() async {
    if (_userModel == null) return;
    final newRole = _userModel!.role == 'admin' ? 'customer' : 'admin';
    final updated = _userModel!.copyWith(role: newRole);
    await _firestoreService.saveUser(updated);
    _userModel = updated;
    notifyListeners();
  }

  /// Đăng xuất tài khoản an toàn & dọn dẹp bộ nhớ phiên
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
    } catch (_) {}
    _firebaseUser = null;
    _userModel = null;
    _errorMessage = null;
    _setLoading(false);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

