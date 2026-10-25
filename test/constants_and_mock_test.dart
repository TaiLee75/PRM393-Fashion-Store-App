import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/core/constants/app_constants.dart';
import 'package:fashion_store_app/core/constants/mock_data.dart';
import 'package:fashion_store_app/models/product_model.dart';

void main() {
  group('AppConstants & VoucherRule Enterprise Tests:', () {
    test('1. Hằng số vận chuyển & Hạn mức Freeship', () {
      expect(AppConstants.standardShippingFee, 30000);
      expect(AppConstants.defaultShippingFee, 30000);
      expect(AppConstants.freeShippingThreshold, 499000);
    });

    test('2. Tương thích ngược: Map AppConstants.vouchers chứa đủ 4 mã hợp lệ', () {
      expect(AppConstants.vouchers.containsKey('SALE10'), isTrue);
      expect(AppConstants.vouchers.containsKey('FREESHIP'), isTrue);
      expect(AppConstants.vouchers.containsKey('UNIQLO50K'), isTrue);
      expect(AppConstants.vouchers.containsKey('VIP100K'), isTrue);

      final sale10 = AppConstants.vouchers['SALE10'];
      expect(sale10['type'], 'percent');
      expect(sale10['value'], 0.10);

      final freeship = AppConstants.vouchers['FREESHIP'];
      expect(freeship['type'], 'fixed');
      expect(freeship['value'], 30000);
    });

    test('3. Tính toán Voucher SALE10: MinOrder 200k & MaxDiscount 50k', () {
      final rule = AppConstants.findVoucher('SALE10');
      expect(rule, isNotNull);

      // Đơn 150k chưa đủ điều kiện
      expect(rule!.isApplicable(150000), isFalse);
      expect(rule.calculateDiscount(subtotal: 150000, shippingFee: 30000), 0);
      expect(rule.getInapplicableReason(150000), contains('200000'));

      // Đơn 300k được giảm 10% = 30k
      expect(rule.isApplicable(300000), isTrue);
      expect(rule.calculateDiscount(subtotal: 300000, shippingFee: 30000), 30000);

      // Đơn 800k (10% = 80k) bị chặn trần maxDiscount 50k
      expect(rule.calculateDiscount(subtotal: 800000, shippingFee: 30000), 50000);
    });

    test('4. Tính toán Voucher FREESHIP: Khóa bẫy giảm âm khi phí ship = 0', () {
      final rule = AppConstants.findVoucher('FREESHIP');
      expect(rule, isNotNull);
      expect(rule!.isShippingVoucher, isTrue);

      // Đơn 250k chưa đủ minOrder 300k
      expect(rule.isApplicable(250000), isFalse);
      expect(rule.calculateDiscount(subtotal: 250000, shippingFee: 30000), 0);

      // Đơn 350k có phí ship 30k -> giảm đúng 30k
      expect(rule.isApplicable(350000), isTrue);
      expect(rule.calculateDiscount(subtotal: 350000, shippingFee: 30000), 30000);

      // Khóa bẫy: Nếu phí ship = 0 (khách nhận tại shop hoặc đã đủ 499k freeship), không được giảm 30k
      expect(rule.calculateDiscount(subtotal: 350000, shippingFee: 0), 0);
    });

    test('5. Tính toán Voucher UNIQLO50K và VIP100K', () {
      final u50 = AppConstants.findVoucher('UNIQLO50K');
      expect(u50, isNotNull);
      expect(u50!.isApplicable(350000), isFalse); // Cần 400k
      expect(u50.calculateDiscount(subtotal: 450000, shippingFee: 30000), 50000);

      final v100 = AppConstants.findVoucher('VIP100K');
      expect(v100, isNotNull);
      expect(v100!.isApplicable(650000), isFalse); // Cần 700k
      expect(v100.calculateDiscount(subtotal: 750000, shippingFee: 30000), 100000);
    });

    test('6. VoucherRule: fromMap, discountLabel, and equality', () {
      final rule = AppConstants.findVoucher('SALE10')!;
      expect(rule.discountLabel, 'Giảm 10%');

      final freeship = AppConstants.findVoucher('FREESHIP')!;
      expect(freeship.discountLabel, 'Giảm 30000đ');

      final map = rule.toMap();
      final parsed = VoucherRule.fromMap(map);
      expect(parsed, equals(rule));
      expect(parsed.code, 'SALE10');
      expect(parsed.minOrder, 200000);
    });
  });

  group('Mock Data Enterprise Integrity Tests:', () {
    test('1. Kiểm tra 4 danh mục và 8 sản phẩm mẫu đầy đủ thông số Enterprise', () {
      expect(mockCategories.length, 4);
      expect(mockProducts.length, 8);

      for (final raw in mockProducts) {
        final product = ProductModel.fromMap(raw);

        // Kiểm tra ID và tên
        expect(product.id, isNotEmpty);
        expect(product.name, isNotEmpty);

        // Kiểm tra giá gốc và phần trăm giảm
        expect(product.originalPrice, isNotNull);
        expect(product.originalPrice!, greaterThan(product.price));
        expect(product.hasDiscount, isTrue);
        expect(product.discountPercent, greaterThan(0));

        // Kiểm tra tồn kho SKU khớp chuẩn với tổng tồn kho
        expect(product.variantStock.isNotEmpty, isTrue);
        expect(product.effectiveStock, product.stock);

        // Kiểm tra số lượng đã bán và trạng thái kích hoạt
        expect(product.soldCount, greaterThan(0));
        expect(product.isActive, isTrue);
      }
    });

    test('2. Phụ kiện thời trang (Mũ, Thắt lưng) hỗ trợ chuẩn FreeSize', () {
      final hatRaw = mockProducts.firstWhere((p) => p['id'] == 'prod_007');
      final hat = ProductModel.fromMap(hatRaw);
      expect(hat.sizes, contains('FreeSize'));
      expect(hat.getStockForVariant('FreeSize', 'Đen'), 30);
      expect(hat.isOutOfStock('FreeSize', 'Đen'), isFalse);

      final beltRaw = mockProducts.firstWhere((p) => p['id'] == 'prod_008');
      final belt = ProductModel.fromMap(beltRaw);
      expect(belt.sizes, contains('FreeSize'));
      expect(belt.getStockForVariant('FreeSize', 'Nâu'), 28);
    });

    test('3. Đánh giá sản phẩm mẫu chứa đầy đủ thông tin xác thực Verified Purchase', () {
      final poloRaw = mockProducts.firstWhere((p) => p['id'] == 'prod_001');
      final polo = ProductModel.fromMap(poloRaw);

      expect(polo.reviews.length, 2);
      final review = polo.reviews.first;
      expect(review.isVerifiedPurchase, isTrue);
      expect(review.userId, isNotEmpty);
      expect(review.orderId, isNotEmpty);
      expect(review.variantInfo, contains('Size M'));
    });
  });
}
