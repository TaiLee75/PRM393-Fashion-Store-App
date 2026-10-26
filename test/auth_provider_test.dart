import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:fashion_store_app/models/user_model.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';
import 'package:fashion_store_app/services/auth_service.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

class FakeAuthService extends AuthService {
  final StreamController<User?> _controller = StreamController<User?>.broadcast();
  bool mockIsPassword = true;
  bool mockIsGoogle = false;
  bool changePasswordSuccess = true;
  bool sendPasswordResetEmailSuccess = true;
  String? updatedDisplayName;
  bool signedOut = false;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  void emitUser(User? user) {
    _controller.add(user);
  }

  @override
  bool get isPasswordProvider => mockIsPassword;

  @override
  bool get isGoogleProvider => mockIsGoogle;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!changePasswordSuccess) {
      throw Exception('Mật khẩu hiện tại không chính xác.');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (!sendPasswordResetEmailSuccess) {
      throw Exception('Email không tồn tại.');
    }
  }

  @override
  Future<void> updateDisplayName(String fullName) async {
    updatedDisplayName = fullName;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class FakeFirestoreServiceForAuth extends FirestoreService {
  final Map<String, UserModel> usersDb = {};
  bool shouldFailSave = false;

  @override
  Future<UserModel?> getUser(String uid) async {
    return usersDb[uid];
  }

  @override
  Future<void> saveUser(UserModel user) async {
    if (shouldFailSave) {
      throw Exception('Firestore network timeout');
    }
    usersDb[user.uid] = user;
  }
}

void main() {
  group('AuthProvider Enterprise Unit Tests (Task 2.1):', () {
    late FakeAuthService fakeAuthService;
    late FakeFirestoreServiceForAuth fakeFirestoreService;
    late AuthProvider authProvider;

    setUp(() {
      fakeAuthService = FakeAuthService();
      fakeFirestoreService = FakeFirestoreServiceForAuth();
      authProvider = AuthProvider(
        authService: fakeAuthService,
        firestoreService: fakeFirestoreService,
      );
    });

    test('1. Khởi tạo ban đầu an toàn & Nhận diện trạng thái chưa đăng nhập', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.userId, isEmpty);
      expect(authProvider.userEmail, isEmpty);
      expect(authProvider.userFullName, 'Khách hàng');
      expect(authProvider.userRole, 'customer');
      expect(authProvider.isAdmin, isFalse);
      expect(authProvider.savedAddresses, isEmpty);
      expect(authProvider.wishlistProductIds, isEmpty);
      expect(authProvider.bodyMeasurements, isNull);
    });

    test('2. Nạp dữ liệu giả lập setMockUser & kiểm tra Getters Enterprise', () {
      final mockUser = UserModel(
        uid: 'user_enterprise_01',
        email: 'student@fpt.edu.vn',
        fullName: 'Nguyễn Văn FPT',
        phone: '0901234567',
        role: 'customer',
        createdAt: DateTime.now(),
        wishlistProductIds: const ['prod_001', 'prod_002'],
        bodyMeasurements: const {'height': 175, 'weight': 68},
      );

      authProvider.setMockUser(mockUser);

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.userId, 'user_enterprise_01');
      expect(authProvider.userEmail, 'student@fpt.edu.vn');
      expect(authProvider.userFullName, 'Nguyễn Văn FPT');
      expect(authProvider.isFavorite('prod_001'), isTrue);
      expect(authProvider.isFavorite('prod_999'), isFalse);
      expect(authProvider.savedHeight, 175.0);
      expect(authProvider.savedWeight, 68.0);
      expect(authProvider.isPasswordProvider, isTrue);
    });

    test('3. Quản lý Sổ địa chỉ (addSavedAddress, updateSavedAddress, deleteSavedAddress)', () async {
      final initialUser = UserModel(
        uid: 'user_addr_01',
        email: 'addr@fpt.edu.vn',
        fullName: 'Địa Chỉ Test',
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(initialUser);

      // Thêm địa chỉ đầu tiên -> Tự động trở thành mặc định
      final addr1 = {
        'name': 'Nhà riêng',
        'phone': '0901111111',
        'address': 'Khu Công Nghệ Cao Hòa Lạc, Hà Nội',
        'isDefault': false,
      };
      final ok1 = await authProvider.addSavedAddress(addr1);
      expect(ok1, isTrue);
      expect(authProvider.savedAddresses.length, 1);
      expect(authProvider.savedAddresses[0]['isDefault'], isTrue);
      expect(authProvider.effectiveDefaultAddress, 'Khu Công Nghệ Cao Hòa Lạc, Hà Nội');

      // Thêm địa chỉ thứ hai đánh dấu isDefault = true -> Địa chỉ đầu tiên bị hạ cờ mặc định
      final addr2 = {
        'name': 'Văn phòng FPT',
        'phone': '0902222222',
        'address': 'Toà nhà FPT Tân Thuận, Quận 7, TP.HCM',
        'isDefault': true,
      };
      final ok2 = await authProvider.addSavedAddress(addr2);
      expect(ok2, isTrue);
      expect(authProvider.savedAddresses.length, 2);
      expect(authProvider.savedAddresses[0]['isDefault'], isFalse);
      expect(authProvider.savedAddresses[1]['isDefault'], isTrue);
      expect(authProvider.effectiveDefaultAddress, 'Toà nhà FPT Tân Thuận, Quận 7, TP.HCM');

      // Cập nhật địa chỉ 0
      final okUpdate = await authProvider.updateSavedAddress(0, {
        'name': 'Nhà riêng Cũ',
        'phone': '0901111111',
        'address': 'Thạch Thất, Hà Nội',
        'isDefault': false,
      });
      expect(okUpdate, isTrue);
      expect(authProvider.savedAddresses[0]['address'], 'Thạch Thất, Hà Nội');

      // Xóa địa chỉ mặc định (index 1) -> Địa chỉ còn lại (index 0) tự động lên làm mặc định
      final okDelete = await authProvider.deleteSavedAddress(1);
      expect(okDelete, isTrue);
      expect(authProvider.savedAddresses.length, 1);
      expect(authProvider.savedAddresses[0]['isDefault'], isTrue);
      expect(authProvider.effectiveDefaultAddress, 'Thạch Thất, Hà Nội');
    });

    test('4. Thêm / Xóa Wishlist (toggleWishlist)', () async {
      final user = UserModel(
        uid: 'user_wishlist_01',
        email: 'wishlist@fpt.edu.vn',
        fullName: 'Wishlist User',
        createdAt: DateTime.now(),
        wishlistProductIds: const ['prod_001'],
      );
      authProvider.setMockUser(user);

      expect(authProvider.isFavorite('prod_001'), isTrue);
      expect(authProvider.isFavorite('prod_002'), isFalse);

      // Thêm prod_002
      await authProvider.toggleWishlist('prod_002');
      expect(authProvider.isFavorite('prod_002'), isTrue);
      expect(authProvider.wishlistProductIds.contains('prod_002'), isTrue);

      // Bỏ prod_001
      await authProvider.toggleWishlist('prod_001');
      expect(authProvider.isFavorite('prod_001'), isFalse);
      expect(authProvider.wishlistProductIds.contains('prod_001'), isFalse);
    });

    test('5. Lưu số đo cơ thể Smart Size Guide (saveBodyMeasurements)', () async {
      final user = UserModel(
        uid: 'user_fit_01',
        email: 'fit@fpt.edu.vn',
        fullName: 'Fit User',
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);

      final ok = await authProvider.saveBodyMeasurements(heightCm: 180, weightKg: 75);
      expect(ok, isTrue);
      expect(authProvider.savedHeight, 180.0);
      expect(authProvider.savedWeight, 75.0);
      expect(authProvider.bodyMeasurements!['height'], 180);
      expect(authProvider.bodyMeasurements!['weight'], 75);
    });

    test('6. Đổi mật khẩu & Quên mật khẩu qua AuthService', () async {
      final user = UserModel(
        uid: 'user_pass_01',
        email: 'pass@fpt.edu.vn',
        fullName: 'Pass User',
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);

      // Đổi mật khẩu thành công
      final okPass = await authProvider.changePassword(
        currentPassword: 'oldPassword123',
        newPassword: 'newPassword123',
      );
      expect(okPass, isTrue);
      expect(authProvider.errorMessage, isNull);

      // Đổi mật khẩu thất bại
      fakeAuthService.changePasswordSuccess = false;
      final failPass = await authProvider.changePassword(
        currentPassword: 'wrongPassword',
        newPassword: 'newPassword123',
      );
      expect(failPass, isFalse);
      expect(authProvider.errorMessage, contains('Mật khẩu hiện tại không chính xác'));

      // Gửi email reset thành công
      final okReset = await authProvider.sendPasswordResetEmail('pass@fpt.edu.vn');
      expect(okReset, isTrue);

      // Gửi email reset thất bại
      fakeAuthService.sendPasswordResetEmailSuccess = false;
      final failReset = await authProvider.sendPasswordResetEmail('nonexistent@fpt.edu.vn');
      expect(failReset, isFalse);
      expect(authProvider.errorMessage, contains('Email không tồn tại'));
    });

    test('7. Chuyển đổi quyền Admin Demo & Đăng xuất sạch sẽ (signOut)', () async {
      final user = UserModel(
        uid: 'user_demo_01',
        email: 'demo@fpt.edu.vn',
        fullName: 'Demo User',
        role: 'customer',
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);
      expect(authProvider.isAdmin, isFalse);

      // Chuyển sang Admin
      await authProvider.toggleAdminRoleForDemo();
      expect(authProvider.isAdmin, isTrue);
      expect(authProvider.userRole, 'admin');

      // Chuyển lại Customer
      await authProvider.toggleAdminRoleForDemo();
      expect(authProvider.isAdmin, isFalse);
      expect(authProvider.userRole, 'customer');

      // Đăng xuất
      await authProvider.signOut();
      expect(fakeAuthService.signedOut, isTrue);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.userModel, isNull);
      expect(authProvider.userId, isEmpty);
    });

    test('8. Rollback trạng thái Wishlist khi ghi Firestore thất bại (Optimistic Rollback)', () async {
      final user = UserModel(
        uid: 'user_rollback_01',
        email: 'rollback@fpt.edu.vn',
        fullName: 'Rollback User',
        createdAt: DateTime.now(),
        wishlistProductIds: const ['prod_001'],
      );
      authProvider.setMockUser(user);

      // Giả lập lỗi mạng khi ghi Firestore
      fakeFirestoreService.shouldFailSave = true;

      final ok = await authProvider.toggleWishlist('prod_002');
      expect(ok, isFalse);
      // Đã rollback lại danh sách ban đầu chỉ có prod_001
      expect(authProvider.isFavorite('prod_002'), isFalse);
      expect(authProvider.isFavorite('prod_001'), isTrue);
      expect(authProvider.wishlistProductIds, ['prod_001']);
      expect(authProvider.errorMessage, contains('Firestore network timeout'));
    });

    test('9. Xác thực số đo cơ thể không được <= 0', () async {
      final user = UserModel(
        uid: 'user_val_01',
        email: 'val@fpt.edu.vn',
        fullName: 'Val User',
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);

      final okInvalid = await authProvider.saveBodyMeasurements(heightCm: -10, weightKg: 50);
      expect(okInvalid, isFalse);
      expect(authProvider.errorMessage, contains('Chiều cao và cân nặng phải lớn hơn 0'));
      expect(authProvider.bodyMeasurements, isNull);
    });

    test('10. Chặn đổi mật khẩu đối với tài khoản Google OAuth thuần', () async {
      final user = UserModel(
        uid: 'user_google_01',
        email: 'google@fpt.edu.vn',
        fullName: 'Google User',
        createdAt: DateTime.now(),
      );
      authProvider.setMockUser(user);

      fakeAuthService.mockIsGoogle = true;
      fakeAuthService.mockIsPassword = false;

      final ok = await authProvider.changePassword(
        currentPassword: 'anyPassword',
        newPassword: 'newPassword123',
      );
      expect(ok, isFalse);
      expect(authProvider.errorMessage, contains('Google'));
    });
  });
}

