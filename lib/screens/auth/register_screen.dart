import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

import 'dart:async';
import '../../core/utils/app_validators.dart';
import '../main_nav_screen.dart';

/// Màn hình Đăng ký tài khoản chuẩn Enterprise với xác thực Email OTP
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isChecking = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final phone = AppValidators.normalizePhone(_phoneController.text);
    final fullName = _fullNameController.text.trim();
    final password = _passwordController.text;

    setState(() => _isChecking = true);
    final authProvider = context.read<AuthProvider>();

    try {
      // 1. Kiểm tra chống trùng Email HOẶC Số điện thoại trên Firestore (Bảo mật thông tin chuẩn)
      final hasDuplicate = await authProvider.checkRegistrationDuplicates(
        email: email,
        phone: phone,
      );
      if (hasDuplicate) {
        if (!mounted) return;
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ Email hoặc Số điện thoại này đã được đăng ký trong hệ thống!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // 2. Đăng ký tài khoản (Firebase tự động gửi email xác thực chính thức từ Google và đăng xuất ngay)
      final success = await authProvider.register(
        email,
        password,
        fullName,
        phone: phone,
      );

      if (!mounted) return;
      setState(() => _isChecking = false);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Đăng ký tài khoản thất bại!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // 3. Mở BottomSheet chờ xác thực Email (chỉ cho phép hoàn tất sau khi bấm link hoặc hủy đăng ký)
      final verified = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _EmailVerificationPendingSheet(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
        ),
      );

      if (!mounted) return;
      if (verified == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Chúc mừng! Tài khoản của bạn đã được kích hoạt thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'ĐĂNG KÝ TÀI KHOẢN',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tạo tài khoản mới',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Điền các thông tin bên dưới để bắt đầu mua sắm',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Họ và tên
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Họ và tên',
                    hintText: 'Nguyễn Văn A',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.black, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.ultraLightGrey,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ và tên';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Số điện thoại
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại liên hệ *',
                    hintText: 'VD: 0901234567',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.black, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.ultraLightGrey,
                  ),
                  validator: AppValidators.validatePhone,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    hintText: 'vidu@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.black, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.ultraLightGrey,
                  ),
                  validator: AppValidators.validateEmail,
                ),
                const SizedBox(height: 16),

                // Mật khẩu
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu *',
                    hintText: 'Tối thiểu 6 ký tự',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.black, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.ultraLightGrey,
                  ),
                  validator: AppValidators.validatePassword,
                ),
                const SizedBox(height: 16),

                // Xác nhận mật khẩu
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleRegister(),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu *',
                    hintText: 'Nhập lại mật khẩu',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.black, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.ultraLightGrey,
                  ),
                  validator: (value) => AppValidators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 28),

                // Nút Đăng ký (Xác thực OTP)
                ElevatedButton(
                  onPressed: (_isChecking || authProvider.isLoading)
                      ? null
                      : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: (_isChecking || authProvider.isLoading)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          'ĐĂNG KÝ VÀ XÁC THỰC EMAIL',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Trở về đăng nhập
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Đăng nhập ngay',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// BottomSheet Chờ xác minh Email chính thức từ Google / Firebase
class _EmailVerificationPendingSheet extends StatefulWidget {
  final String email;
  final String password;
  final String fullName;
  final String phone;

  const _EmailVerificationPendingSheet({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  @override
  State<_EmailVerificationPendingSheet> createState() =>
      _EmailVerificationPendingSheetState();
}

class _EmailVerificationPendingSheetState
    extends State<_EmailVerificationPendingSheet> {
  int _resendCooldownSeconds = 60; // 1 phút
  Timer? _timer;
  bool _isChecking = false;
  bool _isResending = false;
  bool _isCanceling = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCooldownSeconds > 0) {
          _resendCooldownSeconds--;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleResendEmail() async {
    if (_resendCooldownSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    final authProvider = context.read<AuthProvider>();

    try {
      final success = await authProvider.resendVerificationEmail(
        email: widget.email,
        password: widget.password,
      );
      if (!mounted) return;
      setState(() {
        _resendCooldownSeconds = 60;
        _isResending = false;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔄 Đã gửi lại email xác thực tới ${widget.email}. Vui lòng kiểm tra hộp thư (hoặc Thư rác)!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Gửi lại email xác thực thất bại!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleCheckVerified() async {
    setState(() => _isChecking = true);
    final authProvider = context.read<AuthProvider>();

    try {
      final isVerified = await authProvider.verifyAndCompleteRegistration(
        email: widget.email,
        password: widget.password,
        fullName: widget.fullName,
        phone: widget.phone,
      );
      if (!mounted) return;
      setState(() => _isChecking = false);

      if (isVerified) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Bạn chưa bấm vào liên kết xác thực trong Gmail. Vui lòng mở email và bấm vào liên kết để kích hoạt tài khoản!',
            ),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleCancelRegistration() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đăng ký tài khoản?'),
        content: const Text(
          'Nếu bạn hủy, tài khoản sẽ chưa được tạo và bạn sẽ quay lại màn hình đăng nhập.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục xác thực'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hủy đăng ký'),
          ),
        ],
      ),
    );

    if (shouldCancel != true || !mounted) return;

    setState(() => _isCanceling = true);
    final authProvider = context.read<AuthProvider>();
    await authProvider.cancelUnverifiedRegistration(
      email: widget.email,
      password: widget.password,
    );

    if (!mounted) return;
    setState(() => _isCanceling = false);
    Navigator.pop(context, false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã hủy đăng ký tài khoản.'),
        backgroundColor: AppColors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh gạt
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon Email to nổi bật
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            const Text(
              'KIỂM TRA HÒM THƯ GMAIL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Hướng dẫn
            const Text(
              'Google đã gửi email xác thực kích hoạt tài khoản tới:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ultraLightGrey,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '📌 Hướng dẫn: Mở ứng dụng Gmail (kiểm tra cả hộp thư Đến và Thư rác/Spam), sau đó bấm vào liên kết xác nhận từ Google để kích hoạt tài khoản.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Nút "TÔI ĐÃ BẤM LIÊN KẾT TRONG GMAIL"
            ElevatedButton(
              onPressed: (_isChecking || _isCanceling) ? null : _handleCheckVerified,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text(
                      'TÔI ĐÃ BẤM LIÊN KẾT TRONG GMAIL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
            const SizedBox(height: 10),

            // Nút Gửi lại email xác thực
            TextButton(
              onPressed: _resendCooldownSeconds > 0 || _isResending || _isCanceling
                  ? null
                  : _handleResendEmail,
              child: Text(
                _resendCooldownSeconds > 0
                    ? 'Gửi lại email sau (${_resendCooldownSeconds}s)'
                    : 'Gửi lại email xác thực',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _resendCooldownSeconds > 0
                      ? AppColors.grey
                      : AppColors.primary,
                ),
              ),
            ),

            // Nút Hủy đăng ký (Xóa tài khoản chưa xác thực khỏi Firebase)
            TextButton(
              onPressed: (_isChecking || _isCanceling) ? null : _handleCancelRegistration,
              child: _isCanceling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Hủy đăng ký',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
