import 'package:flutter/material.dart';

/// Bảng màu giao diện chuẩn phong cách thời trang Uniqlo
/// Tối giản, hiện đại, tương phản mạnh với màu đỏ đặc trưng và tông đen/trắng tinh tế.
class AppColors {
  AppColors._();

  // 1. Brand Signature Colors
  static const Color primary = Color(0xFFE60012); // Đỏ Uniqlo biểu tượng
  static const Color primaryDark = Color(0xFFC4000F);
  static const Color primaryLight = Color(0xFFFFEBEE);

  // 2. Monochrome & Backgrounds
  static const Color black = Color(0xFF111111); // Đen chữ và viền chính
  static const Color charcoal = Color(0xFF222222);
  static const Color darkGrey = Color(0xFF4A4A4A);
  static const Color grey = Color(0xFF757575);
  static const Color lightGrey = Color(0xFFE5E5EA);
  static const Color ultraLightGrey = Color(0xFFF7F7F8);
  static const Color white = Color(0xFFFFFFFF);

  // 3. UI Element Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF9F9F9);
  static const Color divider = Color(0xFFEFEFEF);
  static const Color border = Color(0xFFE0E0E0);

  // 4. Typography Colors
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textMuted = Color(0xFF8E8E93);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // 5. Functional & Feedback
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color star = Color(0xFFFFB300);

  // 6. Badge & Discount
  static const Color saleBadge = Color(0xFFE60012);
  static const Color priceHighlight = Color(0xFFE60012);
}
