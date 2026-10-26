import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';
import 'package:fashion_store_app/models/product_model.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/services/firestore_service.dart';

class FakeFirestoreServiceForCart extends FirestoreService {
  final Map<String, List<CartItemModel>> cartsDb = {};

  @override
  Stream<List<CartItemModel>> streamCart(String userId) {
    return Stream.value(cartsDb[userId] ?? []);
  }

  @override
  Future<void> saveCart(String userId, List<CartItemModel> items) async {
    cartsDb[userId] = List.from(items);
  }
}

void main() {
  group('Kiểm thử Đơn vị Toàn diện (Unit Test) cho CartProvider Enterprise (Task 2.3):', () {
    late FakeFirestoreServiceForCart fakeFirestoreService;
    late CartProvider cartProvider;

    setUp(() {
      fakeFirestoreService = FakeFirestoreServiceForCart();
      cartProvider = CartProvider(firestoreService: fakeFirestoreService);

      // Thêm 2 món hàng:
      // Món 1: 2 cái Áo Polo x 200.000đ = 400.000đ (Size L, Màu Đen)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_001_L_Đen',
        productId: 'prod_001',
        productName: 'Áo Polo Nam',
        imageUrl: 'https://example.com/polo.jpg',
        price: 200000,
        size: 'L',
        color: 'Đen',
        quantity: 2,
        isSelected: true,
      ));

      // Món 2: 1 cái Áo Thun x 150.000đ = 150.000đ (Size M, Màu Trắng)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_002_M_Trắng',
        productId: 'prod_002',
        productName: 'Áo Thun Basic',
        imageUrl: 'https://example.com/tee.jpg',
        price: 150000,
        size: 'M',
        color: 'Trắng',
        quantity: 1,
        isSelected: true,
      ));
    });

    test('1. Kiểm tra ban đầu: Tổng số lượng, subtotal và trạng thái chọn tất cả', () {
      expect(cartProvider.totalQuantity, 3); // 2 + 1 = 3
      expect(cartProvider.selectedQuantity, 3);
      expect(cartProvider.subtotal, 550000); // 400.000 + 150.000 = 550.000
      expect(cartProvider.isAllSelected, isTrue);
    });

    test('2. Chọn lọc thanh toán (toggleItemSelection & toggleSelectAll - Khóa Bẫy 1)', () {
      // Bỏ chọn món 2 (Áo Thun 150k)
      cartProvider.toggleItemSelection('prod_002_M_Trắng');
      expect(cartProvider.selectedQuantity, 2);
      expect(cartProvider.selectedItems.length, 1);
      expect(cartProvider.subtotal, 400000); // Chỉ tính tiền Áo Polo 400k
      expect(cartProvider.isAllSelected, isFalse);

      // Bỏ chọn tất cả
      cartProvider.toggleSelectAll(false);
      expect(cartProvider.selectedQuantity, 0);
      expect(cartProvider.selectedItems.isEmpty, isTrue);
      expect(cartProvider.subtotal, 0);
      expect(cartProvider.isAllSelected, isFalse);

      // Chọn lại tất cả
      cartProvider.toggleSelectAll(true);
      expect(cartProvider.selectedQuantity, 3);
      expect(cartProvider.subtotal, 550000);
      expect(cartProvider.isAllSelected, isTrue);
    });

    test('3. Đổi phân loại Size/Màu sang phân loại mới chưa có trong giỏ', () {
      // Đổi Áo Polo từ Size L_Đen sang Size XL_Đen (chưa có trong giỏ)
      cartProvider.updateItemVariant(
        oldCartItemId: 'prod_001_L_Đen',
        newSize: 'XL',
        newColor: 'Đen',
        maxVariantStock: 10,
      );

      expect(cartProvider.items.any((i) => i.cartItemId == 'prod_001_L_Đen'), isFalse);
      final newItem = cartProvider.items.firstWhere((i) => i.cartItemId == 'prod_001_XL_Đen');
      expect(newItem.size, 'XL');
      expect(newItem.color, 'Đen');
      expect(newItem.quantity, 2);
    });

    test('4. Khóa Bẫy 2: Đổi phân loại trùng với dòng đã có -> Tự động cộng dồn và xóa dòng cũ', () {
      // Thêm trước 1 dòng Áo Polo Size M_Đen (số lượng 3)
      cartProvider.addItem(const CartItemModel(
        cartItemId: 'prod_001_M_Đen',
        productId: 'prod_001',
        productName: 'Áo Polo Nam',
        imageUrl: 'https://example.com/polo.jpg',
        price: 200000,
        size: 'M',
        color: 'Đen',
        quantity: 3,
        isSelected: true,
      ));
      expect(cartProvider.items.length, 3); // L_Đen (2), M_Trắng (1), M_Đen (3)

      // Bây giờ khách đổi dòng 'prod_001_L_Đen' (2 cái) sang Size M và Màu Đen
      cartProvider.updateItemVariant(
        oldCartItemId: 'prod_001_L_Đen',
        newSize: 'M',
        newColor: 'Đen',
        maxVariantStock: 10,
      );

      // Dòng cũ 'prod_001_L_Đen' phải bị xóa hoàn toàn khỏi giỏ hàng
      expect(cartProvider.items.any((i) => i.cartItemId == 'prod_001_L_Đen'), isFalse);
      // Giỏ chỉ còn 2 dòng, không bao giờ sinh ra 2 dòng trùng cartItemId!
      expect(cartProvider.items.length, 2);

      // Dòng 'prod_001_M_Đen' được cộng dồn số lượng: 3 + 2 = 5
      final mergedItem = cartProvider.items.firstWhere((i) => i.cartItemId == 'prod_001_M_Đen');
      expect(mergedItem.quantity, 5);
    });

    test('5. Kẹp trần số lượng theo tồn kho khi đổi phân loại hoặc tăng số lượng', () {
      // Đổi variant nhưng tồn kho chỉ còn 4 cái
      cartProvider.updateItemVariant(
        oldCartItemId: 'prod_001_L_Đen',
        newSize: 'S',
        newColor: 'Đen',
        maxVariantStock: 1, // Kho chỉ còn 1 cái
      );

      final clampedItem = cartProvider.items.firstWhere((i) => i.cartItemId == 'prod_001_S_Đen');
      expect(clampedItem.quantity, 1); // Bị kẹp trần về 1
    });

    test('6. Áp dụng mã giảm giá SALE10: Giảm 10% tối đa 50k', () {
      // Subtotal = 550.000đ -> 10% là 55.000đ nhưng bị chặn trần maxDiscount = 50.000đ
      final ok = cartProvider.applyVoucher('SALE10');
      expect(ok, isTrue);
      expect(cartProvider.discountAmount, 50000);
      expect(cartProvider.totalPrice, 500000); // 550.000 - 50.000
    });

    test('7. Khóa Bẫy 3: Chặn áp mã FREESHIP khi đơn hàng đã đạt hạn mức Freeship (subtotal >= 499k)', () {
      // Subtotal hiện tại = 550.000đ >= 499.000đ -> Đã được miễn phí giao hàng tự động (0đ)
      final ok = cartProvider.applyVoucher('FREESHIP');
      expect(ok, isFalse); // Chặn không cho áp mã vô nghĩa
      expect(cartProvider.discountAmount, 0); // Không trừ phí ship 0đ ảo
    });

    test('8. Áp dụng mã FREESHIP thành công khi đơn dưới 499k và từ 300k trở lên', () {
      // Bỏ bớt món 1 để subtotal chỉ còn 150k + 200k = 350.000đ (< 499k và >= 300k)
      cartProvider.updateQuantity('prod_001_L_Đen', 1); // 1 x 200k
      expect(cartProvider.subtotal, 350000); // 200k + 150k = 350k

      final ok = cartProvider.applyVoucher('FREESHIP');
      expect(ok, isTrue);
      expect(cartProvider.discountAmount, 30000); // Giảm đúng 30k phí ship
    });

    test('9. Nhập mã voucher không tồn tại thì không giảm giá', () {
      final ok = cartProvider.applyVoucher('MA_VOUCHER_LUA_DAO');
      expect(ok, isFalse);
      expect(cartProvider.discountAmount, 0);
    });

    test('10. Hàm tính toán tài chính độc lập (calculateOrderPricing) cho mọi luồng', () {
      final sampleItems = [
        const CartItemModel(
          cartItemId: 'item_direct_buy',
          productId: 'prod_buy_now',
          productName: 'Áo Khoác Bomber',
          imageUrl: '',
          price: 499000,
          size: 'L',
          color: 'Be',
          quantity: 1,
        ),
      ];

      // Kịch bản A: Nhận tại cửa hàng (PICKUP) -> Phí ship luôn = 0đ
      final pickupPricing = cartProvider.calculateOrderPricing(
        items: sampleItems,
        deliveryMethod: 'PICKUP',
        voucherCode: 'FREESHIP',
      );
      expect(pickupPricing.shippingFee, 0);
      expect(pickupPricing.shippingDiscount, 0); // Chặn mã FREESHIP khi PICKUP
      expect(pickupPricing.finalTotalPrice, 499000);

      // Kịch bản B: Giao tận nơi (DELIVERY) đơn >= 499k -> Phí ship = 0đ tự động
      final autoFreeshipPricing = cartProvider.calculateOrderPricing(
        items: sampleItems,
        deliveryMethod: 'DELIVERY',
      );
      expect(autoFreeshipPricing.shippingFee, 0);
      expect(autoFreeshipPricing.finalTotalPrice, 499000);

      // Kịch bản C: Giao tận nơi đơn nhỏ (250k) -> Phí ship = 30.000đ
      final smallItems = [
        const CartItemModel(
          cartItemId: 'item_small',
          productId: 'prod_small',
          productName: 'Áo Thun',
          imageUrl: '',
          price: 250000,
          size: 'M',
          color: 'Trắng',
          quantity: 1,
        ),
      ];
      final smallPricing = cartProvider.calculateOrderPricing(
        items: smallItems,
        deliveryMethod: 'DELIVERY',
      );
      expect(smallPricing.shippingFee, 30000);
      expect(smallPricing.finalTotalPrice, 280000); // 250k + 30k = 280k
    });

    test('11. Chỉ xóa các món đã tích chọn thanh toán (removePurchasedItems - Khóa Bẫy 6)', () {
      // Tích chọn món 1 (Polo), bỏ chọn món 2 (Áo Thun)
      cartProvider.toggleItemSelection('prod_002_M_Trắng');
      expect(cartProvider.items[0].isSelected, isTrue);
      expect(cartProvider.items[1].isSelected, isFalse);

      // Đặt hàng thành công -> Xóa các món đã mua
      cartProvider.removePurchasedItems();

      // Món 1 đã bị xóa, món 2 chưa mua vẫn còn nguyên vẹn trong giỏ
      expect(cartProvider.items.length, 1);
      expect(cartProvider.items.first.cartItemId, 'prod_002_M_Trắng');
    });

    test('12. Đăng xuất an toàn: unloadCartOnLogout dọn RAM nhưng không xóa Firestore (Khóa Bẫy 13)', () {
      cartProvider.loadUserCart('user_test_logout');
      expect(cartProvider.activeUserId, 'user_test_logout');

      // Khi đăng xuất
      cartProvider.unloadCartOnLogout();
      expect(cartProvider.items.isEmpty, isTrue);
      expect(cartProvider.activeUserId, isNull);
      expect(cartProvider.subtotal, 0);
    });

    test('13. Đối chiếu giỏ hàng với giá & kho live từ Firestore (validateAndAlignCart - Khóa Bẫy 9)', () {
      // Giả lập sản phẩm live từ Firestore: prod_001 giảm giá từ 200k xuống 180k, prod_002 hết hàng
      final liveProducts = [
        const ProductModel(
          id: 'prod_001',
          name: 'Áo Polo Nam',
          categoryId: 'cat_aothun',
          price: 180000, // Đổi giá
          description: '',
          imageUrls: [],
          sizes: ['L'],
          colors: ['Đen'],
          stock: 10,
          variantStock: {'L_Đen': 10},
          isActive: true,
        ),
        const ProductModel(
          id: 'prod_002',
          name: 'Áo Thun Basic',
          categoryId: 'cat_aothun',
          price: 150000,
          description: '',
          imageUrls: [],
          sizes: ['M'],
          colors: ['Trắng'],
          stock: 0,
          variantStock: {'M_Trắng': 0}, // Hết hàng phân loại này
          isActive: true,
        ),
      ];

      cartProvider.validateAndAlignCart(liveProducts);

      // prod_001 được cập nhật giá mới 180.000đ
      final polo = cartProvider.items.firstWhere((i) => i.productId == 'prod_001');
      expect(polo.price, 180000);
      expect(polo.isSelected, isTrue);

      // prod_002 hết hàng -> Tự động bỏ chọn isSelected = false để chặn thanh toán
      final tee = cartProvider.items.firstWhere((i) => i.productId == 'prod_002');
      expect(tee.isSelected, isFalse);

      // Subtotal chỉ còn tính trên món còn hàng và được chọn (2 x 180k = 360k)
      expect(cartProvider.subtotal, 360000);
    });

    test('14. Thêm món vào giỏ (addItem) tự động kẹp trần theo tồn kho', () {
      // Thêm món mới với maxStock = 3 nhưng số lượng = 5 -> Kẹp về 3
      cartProvider.addItem(
        const CartItemModel(
          cartItemId: 'prod_999_XL_Đen',
          productId: 'prod_999',
          productName: 'Quần Jean Slim',
          imageUrl: '',
          price: 350000,
          size: 'XL',
          color: 'Đen',
          quantity: 5,
          isSelected: true,
        ),
        3, // maxStock = 3
      );
      final item = cartProvider.items.firstWhere((i) => i.cartItemId == 'prod_999_XL_Đen');
      expect(item.quantity, 3);

      // Thêm tiếp 2 cái vào món này với maxStock = 4 -> 3 + 2 = 5 nhưng kẹp về 4
      cartProvider.addItem(
        const CartItemModel(
          cartItemId: 'prod_999_XL_Đen',
          productId: 'prod_999',
          productName: 'Quần Jean Slim',
          imageUrl: '',
          price: 350000,
          size: 'XL',
          color: 'Đen',
          quantity: 2,
        ),
        4, // maxStock = 4
      );
      final updatedItem = cartProvider.items.firstWhere((i) => i.cartItemId == 'prod_999_XL_Đen');
      expect(updatedItem.quantity, 4);
    });

    test('15. validateAndAlignCart kẹp số lượng khi kho sụt giảm và bỏ chọn món bị xóa', () {
      // Giỏ đang có prod_001_L_Đen số lượng 2
      final liveProducts = [
        const ProductModel(
          id: 'prod_001',
          name: 'Áo Polo Nam',
          categoryId: 'cat_aothun',
          price: 200000,
          description: '',
          imageUrls: [],
          sizes: ['L'],
          colors: ['Đen'],
          stock: 1,
          variantStock: {'L_Đen': 1}, // Tồn kho tụt từ 10 xuống còn 1
          isActive: true,
        ),
        // prod_002 đã bị xóa khỏi hệ thống hoàn toàn (không có trong liveProducts)
      ];

      cartProvider.validateAndAlignCart(liveProducts);

      // prod_001 bị kẹp số lượng từ 2 về 1
      final polo = cartProvider.items.firstWhere((i) => i.productId == 'prod_001');
      expect(polo.quantity, 1);
      expect(polo.isSelected, isTrue);

      // prod_002 không còn trong liveProducts -> Bị bỏ chọn isSelected = false
      final tee = cartProvider.items.firstWhere((i) => i.productId == 'prod_002');
      expect(tee.isSelected, isFalse);
    });
  });
}
