import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Dịch vụ xác thực tài khoản qua FirebaseAuth & Google Sign-In
class AuthService {
  FirebaseAuth? _authInstance;
  GoogleSignIn? _googleSignInInstance;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _authInstance = auth,
        _googleSignInInstance = googleSignIn;

  FirebaseAuth get _auth {
    _authInstance ??= FirebaseAuth.instance;
    return _authInstance!;
  }

  GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn();
    return _googleSignInInstance!;
  }

  /// Stream theo dõi trạng thái đăng nhập thời gian thực
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Lấy user hiện tại
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Kiểm tra người dùng hiện tại có dùng phương thức đăng nhập bằng Email/Password không
  bool get isPasswordProvider {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Kiểm tra người dùng hiện tại có đăng nhập bằng Google OAuth không
  bool get isGoogleProvider {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  /// Đăng nhập bằng Email & Mật khẩu
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Đăng ký tài khoản mới bằng Email & Mật khẩu (gửi email xác thực và đăng xuất ngay)
  Future<UserCredential> registerWithEmailPassword(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Cập nhật displayName trên Firebase User và gửi email xác thực
      if (credential.user != null) {
        if (fullName.isNotEmpty) {
          await credential.user!.updateDisplayName(fullName.trim());
        }
        try {
          await credential.user!.sendEmailVerification();
        } catch (_) {}
        // Đăng xuất ngay để chặn tuyệt đối việc lọt vào phiên đăng nhập khi chưa xác thực
        await _auth.signOut();
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Gửi lại email xác thực cho tài khoản (có hỗ trợ khi người dùng chưa đăng nhập)
  Future<void> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        if (!credential.user!.emailVerified) {
          await credential.user!.sendEmailVerification();
        }
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Xác minh email bằng thông tin đăng nhập và hoàn tất đăng nhập nếu đã bấm link kích hoạt
  Future<UserCredential?> verifyAndSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await user.reload();
        final verified = _auth.currentUser?.emailVerified ?? false;
        if (!verified) {
          // Chưa bấm liên kết trong Gmail -> đăng xuất ngay
          await _auth.signOut();
          return null;
        }
        return credential;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Hủy tài khoản chưa xác thực (Xóa vĩnh viễn khỏi Firebase Auth)
  Future<void> cancelUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await credential.user!.delete();
      }
    } catch (_) {
      // Bỏ qua nếu tài khoản đã bị xóa hoặc sai mật khẩu
    } finally {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  /// Gửi lại email xác thực tài khoản chính thức từ Google / Firebase
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Kiểm tra xem người dùng hiện tại đã bấm link xác thực trong Gmail chưa
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  /// Đăng nhập bằng tài khoản Google (OAuth 2.0)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Dọn cache phiên trước để Google Play Services luôn hiển thị hộp thoại chọn tài khoản (Account Chooser)
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Người dùng hủy màn hình chọn tài khoản Google
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Đăng nhập Google thất bại: ${e.toString()}');
    }
  }

  /// Thiết lập mật khẩu cho tài khoản Google (giúp tài khoản có thể đăng nhập bằng cả 2 cách)
  Future<void> setPasswordForGoogleAccount(String newPassword) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập. Vui lòng đăng nhập lại.');
    }
    if (newPassword.trim().length < 6) {
      throw Exception('Mật khẩu mới phải có ít nhất 6 ký tự.');
    }
    try {
      await user.updatePassword(newPassword.trim());
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Đổi mật khẩu an toàn với cơ chế Re-Authentication (Khóa Bẫy 4 - chống lỗi requires-recent-login)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập. Vui lòng đăng nhập lại.');
    }
    if (user.email == null || user.email!.isEmpty) {
      throw Exception('Tài khoản không có địa chỉ email hợp lệ.');
    }
    if (currentPassword.isEmpty) {
      throw Exception('Vui lòng nhập mật khẩu hiện tại.');
    }
    if (newPassword.trim().length < 6) {
      throw Exception('Mật khẩu mới phải có ít nhất 6 ký tự.');
    }
    if (currentPassword == newPassword.trim()) {
      throw Exception('Mật khẩu mới không được trùng với mật khẩu hiện tại.');
    }

    try {
      // Bước 1: Re-authenticate để làm mới phiên bảo mật (Bẫy 4)
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Bước 2: Cập nhật mật khẩu mới khi phiên bảo mật đã được xác thực lại thành công
      await user.updatePassword(newPassword.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Đổi mật khẩu thất bại: ${e.toString()}');
    }
  }

  /// Gửi email khôi phục / đặt lại mật khẩu (Quên mật khẩu)
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw Exception('Vui lòng nhập địa chỉ email.');
    }
    // Hỗ trợ đầy đủ các domain hiện đại (.vn, .edu.vn, .clothing, .fashion, etc.)
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      throw Exception('Địa chỉ email không đúng định dạng.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gửi email khôi phục mật khẩu thất bại: ${e.toString()}');
    }
  }

  /// Cập nhật tên hiển thị của người dùng (displayName)
  Future<void> updateDisplayName(String fullName) async {
    try {
      await currentUser?.updateDisplayName(fullName.trim());
    } catch (_) {}
  }

  /// Nạp lại thông tin người dùng từ máy chủ Firebase Auth
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (_) {}
  }

  /// Đăng xuất tài khoản an toàn (đảm bảo cả GoogleSignIn và FirebaseAuth đều được dọn dẹp độc lập)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Chuyển đổi mã lỗi Firebase sang thông báo tiếng Việt dễ hiểu
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hoặc thông tin đăng nhập không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng bởi một tài khoản khác.';
      case 'invalid-email':
        return 'Địa chỉ email không đúng định dạng.';
      case 'weak-password':
        return 'Mật khẩu quá ngắn, vui lòng nhập ít nhất 6 ký tự.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra lại kết nối internet.';
      case 'user-disabled':
        return 'Tài khoản này đã bị khóa.';
      case 'requires-recent-login':
        return 'Phiên đăng nhập đã hết hạn bảo mật. Vui lòng đăng nhập lại trước khi thực hiện thao tác này.';
      case 'user-mismatch':
        return 'Thông tin xác thực không khớp với người dùng hiện tại.';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu không hợp lệ. Vui lòng thử lại sau vài phút.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được kích hoạt.';
      case 'channel-error':
        return 'Vui lòng điền đầy đủ thông tin xác thực.';
      default:
        return e.message ?? 'Đã xảy ra lỗi trong quá trình xác thực.';
    }
  }
}
