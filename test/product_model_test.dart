import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/product_model.dart';

void main() {
  group('ProductModel & ReviewModel Enterprise Serialization Tests:', () {
    test('1. Tương thích ngược: Parse dữ liệu cũ không có trường mới vẫn nhận default an toàn', () {
      final oldMap = {
        'id': 'prod_old_001',
        'name': 'Áo Thun Cũ',
        'categoryId': 'cat_aothun',
        'price': 200000,
        'description': 'Mô tả áo cũ',
        'imageUrls': ['https://example.com/a.jpg'],
        'sizes': ['S', 'M'],
        'colors': ['Đen', 'Trắng'],
        'rating': 4.5,
        'reviews': [
          {
            'userName': 'Khách Cũ',
            'rating': 5,
            'comment': 'Đẹp',
            'createdAt': '2026-10-20T10:00:00Z',
          }
        ],
      };

      final product = ProductModel.fromMap(oldMap);

      expect(product.id, 'prod_old_001');
      expect(product.price, 200000);
      expect(product.originalPrice, isNull);
      expect(product.hasDiscount, isFalse);
      expect(product.discountPercent, 0);
      expect(product.stock, 99); // Fallback mặc định
      expect(product.variantStock.isEmpty, isTrue);
      expect(product.effectiveStock, 99);
      expect(product.soldCount, 0);
      expect(product.isActive, isTrue);
      expect(product.reviews.length, 1);

      final review = product.reviews.first;
      expect(review.userName, 'Khách Cũ');
      expect(review.userId, '');
      expect(review.orderId, '');
      expect(review.isVerifiedPurchase, isFalse);
    });

    test('2. Parse dữ liệu mới chuẩn doanh nghiệp: SKU Variant Stock, Original Price, Verified Reviews', () {
      final newMap = {
        'id': 'prod_new_002',
        'name': 'Áo Polo Cao Cấp',
        'categoryId': 'cat_aothun',
        'price': 240000,
        'originalPrice': 300000, // Giảm 20%
        'description': 'Polo chất lượng cao',
        'imageUrls': ['https://example.com/polo1.jpg', 'https://example.com/polo2.jpg'],
        'sizes': ['S', 'M', 'L'],
        'colors': ['Trắng', 'Đen'],
        'stock': 25,
        'variantStock': {
          'S_Trắng': 10,
          'M_Trắng': 8,
          'L_Trắng': 7,
          'L_Đen': 0, // Hết hàng phân loại này
        },
        'soldCount': 42,
        'isActive': true,
        'rating': 4.9,
        'reviews': [
          {
            'userId': 'usr_123',
            'userName': 'Nguyễn Văn A',
            'rating': 5,
            'comment': 'Vải cực mát, form chuẩn',
            'createdAt': '2026-10-25T08:00:00Z',
            'orderId': 'ord_999',
            'variantInfo': 'Phân loại: Size M, Màu Trắng',
            'isVerifiedPurchase': true,
          }
        ],
      };

      final product = ProductModel.fromMap(newMap);

      expect(product.id, 'prod_new_002');
      expect(product.hasDiscount, isTrue);
      expect(product.discountPercent, 20); // (300k - 240k)/300k = 20%
      expect(product.effectiveStock, 25); // 10 + 8 + 7 + 0 = 25
      expect(product.getStockForVariant('S', 'Trắng'), 10);
      expect(product.getStockForVariant('M', 'Trắng'), 8);
      expect(product.getStockForVariant('L', 'Đen'), 0);
      expect(product.isOutOfStock('L', 'Đen'), isTrue); // Hết hàng Size L - Đen
      expect(product.isOutOfStock('S', 'Trắng'), isFalse);
      expect(product.soldCount, 42);
      expect(product.isActive, isTrue);

      final review = product.reviews.first;
      expect(review.userId, 'usr_123');
      expect(review.orderId, 'ord_999');
      expect(review.isVerifiedPurchase, isTrue);
      expect(review.variantInfo, 'Phân loại: Size M, Màu Trắng');

      // Kiểm tra toMap & copyWith
      final mapOutput = product.toMap();
      expect(mapOutput['originalPrice'], 300000);
      expect(mapOutput['soldCount'], 42);
      expect(mapOutput['variantStock']['S_Trắng'], 10);

      final cloned = product.copyWith(soldCount: 43);
      expect(cloned.soldCount, 43);
      expect(cloned.price, 240000);
      expect(cloned, equals(product)); // Cùng id thì bằng nhau

      // 3. Test các kịch bản kiểm tra tồn kho nâng cao (Edge cases)
      // Variant không tồn tại trong variantStock -> phải trả về 0 (không bị bug lọt về 99)
      expect(product.getStockForVariant('S', 'Hồng'), 0);
      expect(product.isOutOfStock('S', 'Hồng'), isTrue);

      // Tra cứu tồn kho chỉ theo Size (tổng tồn kho của toàn bộ màu trong Size M: 8)
      expect(product.getStockForVariant('M'), 8);
      expect(product.isOutOfStock('M'), isFalse);

      // Tra cứu tồn kho Size L (L_Trắng: 7, L_Đen: 0 -> tổng là 7)
      expect(product.getStockForVariant('L'), 7);

      // Tra cứu Size không tồn tại (XL) -> trả về 0
      expect(product.getStockForVariant('XL'), 0);
      expect(product.isOutOfStock('XL'), isTrue);
    });

    test('3. Xử lý an toàn khi Firestore trả về Map lồng dynamic <Object?, Object?>', () {
      final Map<dynamic, dynamic> rawDynamicMap = {
        'id': 'prod_dynamic_003',
        'name': 'Áo Khoác Gió',
        'categoryId': 'cat_aokhoac',
        'price': 450000,
        'imageUrls': ['https://example.com/jacket.jpg'],
        'sizes': ['M', 'L'],
        'colors': ['Xanh'],
        'variantStock': <dynamic, dynamic>{
          'M_Xanh': 12,
          'L_Xanh': 5,
        },
        'reviews': <dynamic>[
          <dynamic, dynamic>{
            'userId': 'usr_dynamic',
            'userName': 'Lê Văn B',
            'rating': 4.5,
            'comment': 'Áo chống nước tốt',
            'createdAt': DateTime.now().toIso8601String(),
          }
        ],
      };

      // Ép sang Map<String, dynamic> như Firestore Service thường làm
      final safeMap = Map<String, dynamic>.from(rawDynamicMap);
      final product = ProductModel.fromMap(safeMap);

      expect(product.id, 'prod_dynamic_003');
      expect(product.effectiveStock, 17); // 12 + 5 = 17
      expect(product.getStockForVariant('M', 'Xanh'), 12);
      expect(product.reviews.length, 1);
      expect(product.reviews.first.userName, 'Lê Văn B');
    });
  });
}
