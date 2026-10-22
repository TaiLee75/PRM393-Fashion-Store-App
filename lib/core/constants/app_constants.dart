import 'package:latlong2/latlong.dart';

class AppConstants {
  // 1. Tọa độ chi nhánh cửa hàng cố định (Dùng cho OpenStreetMap)
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

  // 2. Danh sách mã giảm giá mẫu (Vouchers) xử lý trực tiếp trong CartProvider
  static const Map<String, dynamic> vouchers = {
    "SALE10": {"type": "percent", "value": 0.10, "desc": "Giảm 10% tổng đơn"},
    "FREESHIP": {"type": "fixed", "value": 30000, "desc": "Giảm thẳng 30.000 VNĐ"},
  };

  // 3. Cấu hình Cổng thanh toán VietQR Napas247
  static const String bankId = 'MB'; // MBBank (Ngân hàng TMCP Quân Đội)
  static const String bankName = 'MBBank - Ngân hàng TMCP Quân Đội';
  static const String bankAccountNo = '0987654321';
  static const String bankAccountName = 'FASHION STORE PRM393';

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