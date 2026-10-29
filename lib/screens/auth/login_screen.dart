import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';
import '../main_nav_screen.dart';

/// Màn hình Đăng nhập phong cách Uniqlo tối giản, hiện đại
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithEmailOrPhone(
      _emailController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    } else if (mounted && authProvider.errorMessage != null) {
      final isUnverified = authProvider.errorMessage!.contains('chưa được kích hoạt');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: isUnverified ? 6 : 4),
          action: isUnverified
              ? SnackBarAction(
                  label: 'Gửi lại',
                  textColor: Colors.amber,
                  onPressed: () => _handleResendVerificationForLogin(),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _handleResendVerificationForLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Vui lòng nhập đúng Email và Mật khẩu để gửi lại liên kết kích hoạt.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendVerificationEmail(
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🔄 Đã gửi lại email kích hoạt tới $email. Vui lòng kiểm tra Gmail (cả mục Thư rác)!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Gửi lại email thất bại!'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    } else if (mounted && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showForgotPasswordBottomSheet() async {
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ForgotPasswordBottomSheet(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (email != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📧 Đã gửi liên kết khôi phục tới $email!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo thương hiệu đỏ trắng chuẩn Uniqlo
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PRM',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.5,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'STORE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 2,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'ĐĂNG NHẬP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chào mừng bạn đến với cửa hàng thời trang',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 1. Ô nhập Email hoặc Số điện thoại
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email hoặc Số điện thoại',
                      hintText: 'vidu@gmail.com hoặc 0901234567',
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
                        return 'Vui lòng nhập email hoặc số điện thoại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. Ô nhập Mật khẩu
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      hintText: 'Nhập mật khẩu',
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải từ 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Quên mật khẩu?
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordBottomSheet,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nút Đăng nhập thông thường (ElevatedButton)
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Đường phân cách
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'HOẶC',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nút Đăng nhập với Google
                  OutlinedButton.icon(
                    onPressed: authProvider.isLoading ? null : _handleGoogleLogin,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.g_mobiledata,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    label: const Text(
                      'Đăng nhập với Google',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Chuyển sang màn hình Đăng ký
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Chưa có tài khoản? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Đăng ký ngay',
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
      ),
    );
  }
}

class _ForgotPasswordBottomSheet extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordBottomSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordBottomSheet> createState() => _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState extends State<_ForgotPasswordBottomSheet> {
  late final TextEditingController _resetEmailController;
  final _resetFormKey = GlobalKey<FormState>();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _resetEmailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    final email = _resetEmailController.text.trim();
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPasswordResetEmail(email);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, email);
    } else {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Không thể gửi email đặt lại mật khẩu',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Form(
        key: _resetFormKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QUÊN MẬT KHẨU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhập email tài khoản của bạn để nhận liên kết đặt lại mật khẩu từ hệ thống.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email của bạn *',
                  hintText: 'vidu@gmail.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  if (!value.contains('@')) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSending ? null : _handleSendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'GỬI LIÊN KẾT ĐẶT LẠI MẬT KHẨU',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

