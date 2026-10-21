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

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get userId => _firebaseUser?.uid ?? '';
  String get userEmail => _userModel?.email ?? _firebaseUser?.email ?? '';
  String get userFullName =>
      _userModel?.fullName ?? _firebaseUser?.displayName ?? 'Khách hàng';
  String get userRole => _userModel?.role ?? 'customer';
  bool get isAdmin => _userModel?.isAdmin ?? false;

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

  Future<void> _fetchUserProfile(String uid) async {
    try {
      final profile = await _firestoreService.getUser(uid);
      if (profile != null) {
        _userModel = profile;
      } else {
        // Nếu vừa tạo tài khoản chưa có doc users thì tạo mới
        final newProfile = UserModel(
          uid: uid,
          email: _firebaseUser?.email ?? '',
          fullName: _firebaseUser?.displayName ?? 'Khách hàng',
          avatarUrl: _firebaseUser?.photoURL ?? '',
          role: 'customer',
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUser(newProfile);
        _userModel = newProfile;
      }
    } catch (_) {
      // Bỏ qua lỗi Firestore offline
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

  /// Cập nhật thông tin cá nhân (Họ tên, SĐT, Địa chỉ, Avatar)
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? defaultAddress,
    String? avatarUrl,
  }) async {
    if (_userModel == null) return false;
    _setLoading(true);

    try {
      final updated = _userModel!.copyWith(
        fullName: fullName ?? _userModel!.fullName,
        phone: phone ?? _userModel!.phone,
        defaultAddress: defaultAddress ?? _userModel!.defaultAddress,
        avatarUrl: avatarUrl ?? _userModel!.avatarUrl,
      );
      await _firestoreService.saveUser(updated);
      _userModel = updated;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
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

  /// Đăng xuất
  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    _firebaseUser = null;
    _userModel = null;
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
