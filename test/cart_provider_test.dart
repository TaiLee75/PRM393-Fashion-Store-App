import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';

void main() {
  group('Kiểm thử Đơn vị (Unit Test) cho CartProvider thật:', () {
    late CartProvider cartProvider;

    setUp(() {
      cartProvider = CartProvider();
      // Giả lập thêm 2 món hàng có tổng tiền 500.000đ vào giỏ
      cartProvider.addItem(const CartItemModel(
        cartItemId: "prod_001_L_Den",
        productId: "prod_001",
        productName: "Áo Polo Nam",
        imageUrl: "https://example.com/polo.jpg",
        price: 250000,
        size: "L",
        color: "Đen",
        quantity: 2,
      ));
    });

    test('Kiểm tra tổng tiền hàng tạm tính ban đầu (subtotal)', () {
      expect(cartProvider.subtotal, 500000);
    });

    test('Áp dụng mã SALE10 phải chiết khấu đúng 10% tổng tiền hàng', () {
      cartProvider.applyVoucher("SALE10");
      expect(cartProvider.discountAmount, 50000);
      expect(cartProvider.totalPrice, 450000); // 500.000 - 50.000
    });

    test('Áp dụng mã FREESHIP phải giảm đúng 30.000đ', () {
      cartProvider.applyVoucher("FREESHIP");
      expect(cartProvider.discountAmount, 30000);
      expect(cartProvider.totalPrice, 470000); // 500.000 - 30.000
    });

    test('Nhập mã voucher không tồn tại thì discountAmount = 0', () {
      cartProvider.applyVoucher("MA_KHONG_TON_TAI");
      expect(cartProvider.discountAmount, 0);
      expect(cartProvider.totalPrice, 500000);
    });

    test('Hàm clearCart() phải dọn sạch giỏ hàng và đặt lại tổng tiền về 0', () {
      cartProvider.clearCart();
      expect(cartProvider.items.isEmpty, true);
      expect(cartProvider.totalPrice, 0);
    });
  });
}
