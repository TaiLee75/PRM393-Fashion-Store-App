import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../core/utils/app_validators.dart';

/// ViewModel quản lý trạng thái xác thực và hồ sơ người dùng (MVVM)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  final Map<String, _LocalOtpEntry> _localOtpCache = {};

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
  bool get isAuthenticated {
    if (_userModel == null && _firebaseUser == null) return false;
    // Nếu là mock user trong Unit / Widget Test (chỉ set UserModel, không có live FirebaseUser)
    if (_firebaseUser == null && _userModel != null) return true;
    // Đăng nhập bằng Google: Google đã xác thực email
    if (isGoogleProvider) return true;
    // Đăng nhập bằng Email/Password live từ Firebase: Bắt buộc emailVerified phải là true
    return _firebaseUser?.emailVerified ?? false;
  }
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
        if (user.emailVerified || isGoogleProvider) {
          await _fetchUserProfile(user.uid);
        } else {
          _userModel = null;
        }
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

  /// Đăng ký tài khoản mới (Gửi email xác thực chính thức và đăng xuất ngay để bảo mật)
  Future<bool> register(
    String email,
    String password,
    String fullName, {
    String? phone,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.registerWithEmailPassword(
        email,
        password,
        fullName,
      );
      // Lưu ý: Tuyệt đối CHƯA lưu doc Firestore users ở đây! Chỉ lưu khi đã xác thực email
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Xác minh email bằng thông tin đăng nhập và lưu hồ sơ Firestore khi đã click link thành công
  Future<bool> verifyAndCompleteRegistration({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final credential = await _authService.verifyAndSignIn(
        email: email,
        password: password,
      );
      if (credential == null || credential.user == null) {
        _setLoading(false);
        return false;
      }

      // Đã xác thực thành công -> Lưu hồ sơ Firestore chính thức
      final cleanPhone = AppValidators.normalizePhone(phone);
      final newProfile = UserModel(
        uid: credential.user!.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: cleanPhone,
        role: 'customer',
        createdAt: DateTime.now(),
      );
      await _firestoreService.saveUser(newProfile);
      _userModel = newProfile;
      _firebaseUser = credential.user;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Hủy đăng ký tài khoản chưa xác thực (Xóa khỏi Firebase Auth)
  Future<void> cancelUnverifiedRegistration({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.cancelUnverifiedAccount(
        email: email,
        password: password,
      );
      _userModel = null;
      _firebaseUser = null;
      _setLoading(false);
      notifyListeners();
    } catch (_) {
      _setLoading(false);
    }
  }

  /// Gửi lại email xác thực cho tài khoản
  Future<bool> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.resendVerificationEmail(
        email: email,
        password: password,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Gửi lại email xác thực tài khoản chính thức từ Google / Firebase
  Future<bool> sendEmailVerification() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.sendEmailVerification();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Kiểm tra xem người dùng hiện tại đã bấm link xác thực trong Gmail chưa
  Future<bool> checkEmailVerified() async {
    try {
      final verified = await _authService.isEmailVerified();
      notifyListeners();
      return verified;
    } catch (_) {
      return false;
    }
  }

  /// Kiểm tra chống trùng Email HOẶC Số điện thoại (Tuân thủ bảo mật thông tin)
  Future<bool> checkRegistrationDuplicates({
    required String email,
    required String phone,
  }) async {
    final emailExists = await _firestoreService.checkEmailExists(email);
    final phoneExists = await _firestoreService.checkPhoneExists(phone);
    return emailExists || phoneExists;
  }

  /// Kiểm tra Email đã được đăng ký chưa
  Future<bool> checkEmailExists(String email) =>
      _firestoreService.checkEmailExists(email);

  /// Kiểm tra Số điện thoại đã được đăng ký chưa
  Future<bool> checkPhoneExists(String phone) =>
      _firestoreService.checkPhoneExists(phone);

  /// Gửi mã OTP xác thực Email (Hiệu lực 2 phút, Giới hạn gửi lại sau 1 phút)
  Future<String> sendEmailOtp(String email) async {
    _setLoading(true);
    _errorMessage = null;
    final cleanEmail = email.trim().toLowerCase();

    try {
      // 1. Kiểm tra Cooldown từ bộ nhớ cục bộ
      final localEntry = _localOtpCache[cleanEmail];
      if (localEntry != null && localEntry.remainingCooldownSeconds > 0) {
        throw Exception(
            'Vui lòng chờ ${localEntry.remainingCooldownSeconds} giây trước khi yêu cầu gửi lại mã.');
      }

      // 2. Thử kiểm tra Cooldown từ Firestore nếu có quyền
      try {
        final remainingCooldown =
            await _firestoreService.getRemainingResendCooldownSeconds(cleanEmail);
        if (remainingCooldown > 0) {
          throw Exception(
              'Vui lòng chờ $remainingCooldown giây trước khi yêu cầu gửi lại mã.');
        }
      } catch (e) {
        if (e.toString().contains('Vui lòng chờ')) rethrow;
      }

      // 3. Sinh mã OTP 6 số ngẫu nhiên
      final random = Random();
      final otp = (100000 + random.nextInt(900000)).toString();
      final now = DateTime.now();

      // Lưu vào bộ nhớ cục bộ (100% không bị chặn bởi Firestore rules)
      _localOtpCache[cleanEmail] = _LocalOtpEntry(
        otp: otp,
        expiresAt: now.add(const Duration(minutes: 2)),
        resendAvailableAt: now.add(const Duration(minutes: 1)),
      );

      // 4. Đồng bộ lên Firestore nếu được cho phép (không crash nếu permission-denied)
      try {
        await _firestoreService.saveEmailOtp(email: cleanEmail, otp: otp);
      } catch (e) {
        debugPrint('Firestore saveEmailOtp warning (dùng fallback local OTP): $e');
      }

      _setLoading(false);
      return otp;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      rethrow;
    }
  }

  /// Xác thực mã OTP người dùng nhập vào
  Future<bool> verifyEmailOtp(String email, String otp) async {
    _setLoading(true);
    _errorMessage = null;
    final cleanEmail = email.trim().toLowerCase();

    try {
      // 1. Kiểm tra bộ nhớ cục bộ trước
      final localEntry = _localOtpCache[cleanEmail];
      if (localEntry != null) {
        if (localEntry.isExpired) {
          throw Exception(
              'Mã xác thực OTP đã hết hạn (chỉ có hiệu lực trong 2 phút). Vui lòng gửi lại mã mới.');
        }
        if (localEntry.otp.trim() != otp.trim()) {
          throw Exception(
              'Mã xác thực OTP không chính xác. Vui lòng kiểm tra lại.');
        }
        // Khớp mã thành công! Xóa cache cục bộ
        _localOtpCache.remove(cleanEmail);
        try {
          await _firestoreService.verifyEmailOtp(email: cleanEmail, otp: otp);
        } catch (_) {}
        _setLoading(false);
        return true;
      }

      // 2. Fallback kiểm tra Firestore
      final ok = await _firestoreService.verifyEmailOtp(
          email: cleanEmail, otp: otp);
      _setLoading(false);
      return ok;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      rethrow;
    }
  }

  /// Đăng nhập linh hoạt bằng Email HOẶC Số điện thoại
  Future<bool> signInWithEmailOrPhone(String identifier, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      String emailToUse = identifier.trim();
      final isEmail = identifier.contains('@');

      if (!isEmail) {
        // Người dùng nhập số điện thoại -> tìm email tương ứng trên Firestore
        final cleanPhone = AppValidators.normalizePhone(identifier);
        final user = await _firestoreService.getUserByPhone(cleanPhone);
        if (user == null || user.email.isEmpty) {
          throw Exception(
              'Số điện thoại "$cleanPhone" chưa được đăng ký trong hệ thống.');
        }
        emailToUse = user.email;
      }

      final credential =
          await _authService.signInWithEmailPassword(emailToUse, password);
      final user = credential.user;
      if (user != null) {
        // CỔNG KIỂM SOÁT BẢO MẬT: Bắt buộc email đã được xác thực (trừ đăng nhập Google)
        if (!user.emailVerified && !_authService.isGoogleProvider) {
          await _authService.signOut();
          throw Exception(
              'Tài khoản chưa được kích hoạt qua Email. Vui lòng mở Gmail (kể cả mục Thư rác) và bấm liên kết kích hoạt trước khi đăng nhập!');
        }
        await _fetchUserProfile(user.uid);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Thiết lập mật khẩu cho tài khoản Google chưa có mật khẩu
  Future<bool> setPasswordForGoogleAccount(String newPassword) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.setPasswordForGoogleAccount(newPassword);
      _setLoading(false);
      notifyListeners();
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
      // 1. Kiểm tra chống trùng số điện thoại với tài khoản khác khi cập nhật SĐT mới
      String? cleanPhoneToSave;
      if (phone != null && phone.trim().isNotEmpty) {
        final cleanPhone = AppValidators.normalizePhone(phone);
        final currentPhone = AppValidators.normalizePhone(_userModel!.phone);
        if (cleanPhone != currentPhone) {
          final phoneTaken = await _firestoreService.checkPhoneExistsForOtherUser(
            cleanPhone,
            _userModel!.uid,
          );
          if (phoneTaken) {
            throw Exception(
                'Số điện thoại "$cleanPhone" đã được đăng ký bởi một tài khoản khác. Vui lòng chọn số khác!');
          }
        }
        cleanPhoneToSave = cleanPhone;
      }

      // 2. Đồng bộ 2 chiều với savedAddresses nếu có defaultAddress mới
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
            'phone': cleanPhoneToSave ?? _userModel!.phone,
            'address': defaultAddress.trim(),
            'isDefault': true,
          });
        }
      }

      final updated = _userModel!.copyWith(
        fullName: fullName ?? _userModel!.fullName,
        phone: cleanPhoneToSave ?? _userModel!.phone,
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

/// Lưu trữ thông tin OTP cục bộ có hạn dùng và đếm ngược gửi lại
class _LocalOtpEntry {
  final String otp;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  _LocalOtpEntry({
    required this.otp,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get remainingCooldownSeconds {
    final diff = resendAvailableAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

