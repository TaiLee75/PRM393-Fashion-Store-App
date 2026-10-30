import 'package:latlong2/latlong.dart';

/// Quy tắc mã giảm giá Voucher chuẩn E-Commerce
class VoucherRule {
  final String code;
  final String name;
  final String description;
  final String type; // 'percent' (phần trăm) hoặc 'fixed' (số tiền cố định)
  final num value; // 0.10 (10%) hoặc 50000 (50k)
  final num minOrder; // Giá trị đơn hàng tối thiểu
  final num? maxDiscount; // Mức giảm tối đa (với voucher phần trăm)
  final bool isShippingVoucher; // true nếu là voucher giảm phí vận chuyển (FREESHIP)

  const VoucherRule({
    required this.code,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    this.minOrder = 0,
    this.maxDiscount,
    this.isShippingVoucher = false,
  });

  /// Kiểm tra đơn hàng có đủ điều kiện áp dụng mã hay không
  bool isApplicable(num subtotal) => subtotal >= minOrder;

  /// Lý do chưa đủ điều kiện áp dụng
  String? getInapplicableReason(num subtotal) {
    if (subtotal < minOrder) {
      return 'Đơn hàng tối thiểu để dùng mã này là ${minOrder.toInt()}đ (hiện có ${subtotal.toInt()}đ)';
    }
    return null;
  }

  /// Nhãn hiển thị mức giảm giá (VD: "Giảm 10%", "Giảm 30.000đ", "Giảm 50.000đ")
  String get discountLabel {
    if (type == 'percent') {
      return 'Giảm ${(value * 100).toInt()}%';
    } else {
      return 'Giảm ${value.toInt()}đ';
    }
  }

  /// Tính số tiền được giảm thực tế
  num calculateDiscount({required num subtotal, required num shippingFee}) {
    if (!isApplicable(subtotal)) return 0;

    if (isShippingVoucher) {
      // Voucher vận chuyển: giảm tối đa bằng phí vận chuyển hiện tại
      if (type == 'fixed') {
        return value > shippingFee ? shippingFee : value;
      }
      final disc = shippingFee * value;
      return maxDiscount != null && disc > maxDiscount! ? maxDiscount! : disc;
    } else {
      // Voucher tiền hàng: giảm trên subtotal
      if (type == 'percent') {
        final disc = (subtotal * value).round();
        return (maxDiscount != null && disc > maxDiscount!) ? maxDiscount! : disc;
      } else {
        return value > subtotal ? subtotal : value;
      }
    }
  }

  factory VoucherRule.fromMap(Map<String, dynamic> map) {
    return VoucherRule(
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description:
          map['desc'] as String? ?? map['description'] as String? ?? '',
      type: map['type'] as String? ?? 'fixed',
      value: (map['value'] as num?) ?? 0,
      minOrder: (map['minOrder'] as num?) ?? 0,
      maxDiscount: map['maxDiscount'] as num?,
      isShippingVoucher: map['isShippingVoucher'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'desc': description,
      'type': type,
      'value': value,
      'minOrder': minOrder,
      'maxDiscount': maxDiscount,
      'isShippingVoucher': isShippingVoucher,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoucherRule &&
          runtimeType == other.runtimeType &&
          code == other.code);

  @override
  int get hashCode => code.hashCode;
}

class AppConstants {
  // 1. Phí giao hàng & Hạn mức Freeship Enterprise
  static const num standardShippingFee = 30000; // Phí giao hàng chuẩn toàn quốc
  static const num defaultShippingFee = 30000; // Alias tương thích
  static const num freeShippingThreshold = 499000; // Đơn từ 499.000đ tự động Freeship

  // 2. Danh mục Voucher chuẩn doanh nghiệp
  static const List<VoucherRule> voucherRules = [
    VoucherRule(
      code: 'SALE10',
      name: 'Giảm 10% Tiền Hàng',
      description: 'Giảm 10% tối đa 50.000đ cho đơn từ 200.000đ',
      type: 'percent',
      value: 0.10,
      minOrder: 200000,
      maxDiscount: 50000,
      isShippingVoucher: false,
    ),
    VoucherRule(
      code: 'FREESHIP',
      name: 'Miễn Phí Vận Chuyển',
      description: 'Giảm 30.000đ phí giao hàng cho đơn từ 300.000đ',
      type: 'fixed',
      value: 30000,
      minOrder: 300000,
      isShippingVoucher: true,
    ),
    VoucherRule(
      code: 'UNIQLO50K',
      name: 'Ưu Đãi Lifewear 50K',
      description: 'Giảm thẳng 50.000đ cho đơn hàng từ 400.000đ',
      type: 'fixed',
      value: 50000,
      minOrder: 400000,
      isShippingVoucher: false,
    ),
    VoucherRule(
      code: 'VIP100K',
      name: 'Tri Ân Khách Hàng VIP',
      description: 'Giảm ngay 100.000đ cho đơn hàng từ 700.000đ',
      type: 'fixed',
      value: 100000,
      minOrder: 700000,
      isShippingVoucher: false,
    ),
  ];

  /// Map vouchers phục vụ tương thích ngược với CartProvider hiện tại
  static final Map<String, dynamic> vouchers = {
    for (final rule in voucherRules) rule.code: rule.toMap(),
  };

  /// Tra cứu luật voucher theo mã
  static VoucherRule? findVoucher(String code) {
    final clean = code.trim().toUpperCase();
    try {
      return voucherRules.firstWhere((r) => r.code == clean);
    } catch (_) {
      return null;
    }
  }

  // 3. Tọa độ chi nhánh cửa hàng cố định (Dùng cho OpenStreetMap & Mock Seed)
  static final List<Map<String, dynamic>> storeBranches = [
    {
      "name": "Chi nhánh 1 - FPT University Da Nang",
      "address": "Khu đô thị FPT City, Ngũ Hành Sơn, Đà Nẵng",
      "location": const LatLng(15.9689, 108.2608),
    },
    {
      "name": "Chi nhánh 2 - Fashion Flagship Store",
      "address": "Đường Bạch Đằng, Quận Hải Châu, Đà Nẵng",
      "location": const LatLng(16.0678, 108.2248),
    },
  ];

  // 4. Cấu hình Cổng thanh toán VietQR Napas247 & Cổng SePay
  static const String bankId = 'MB'; // MBBank (Ngân hàng TMCP Quân Đội)
  static const String bankName = 'MBBank - Ngân hàng TMCP Quân Đội';
  static const String bankAccountNo = '0844332333';
  static const String bankAccountName = 'Le Nguyen Minh Tai';
  static const String sepayApiToken = 'LB6M6CPB50XNPO2YTVFG1YRLZWEQP4DMGTKRN9SVKXF5Q27LNUH31TNHWAQ0ABLH';

  /// Thời gian tối đa chờ khách thanh toán VietQR trước khi tự động hủy đơn (phút)
  /// - Demo đồ án: 2 phút (để chấm điểm và test nhanh).
  /// - Thực tế thương mại điện tử (Shopee/Lazada): 1440 phút (24 giờ).
  static const int unpaidOrderTimeoutMinutes = 2;

  /// Tạo đường link mã QR thanh toán động VietQR Napas247 theo chuẩn ngân hàng
  static String generateVietQrUrl({
    required num amount,
    required String orderId,
  }) {
    final cleanAmount = amount.toInt();
    final shortOrderId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
    final addInfo = Uri.encodeComponent('DH $shortOrderId');
    final accountNameEncoded = Uri.encodeComponent(bankAccountName);
    return 'https://img.vietqr.io/image/$bankId-$bankAccountNo-compact2.png?amount=$cleanAmount&addInfo=$addInfo&accountName=$accountNameEncoded';
  }
}