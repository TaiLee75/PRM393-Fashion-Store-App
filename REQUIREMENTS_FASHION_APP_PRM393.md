# BẢN ĐẶC TẢ YÊU CẦU DỰ ÁN CUỐI KỲ - PRM393 (BẢN HOÀN THIỆN 100%)
## ĐỀ TÀI: ỨNG DỤNG MUA SẮM THỜI TRANG TRỰC TUYẾN (FASHION MOBILE STORE APP)
**Hệ thống:** Mobile Application (Flutter & Dart)  
**Nền tảng Backend:** Firebase (Authentication, Cloud Firestore)  
**Kiến trúc:** MVVM (Model - View - ViewModel) với thư viện State Management `provider`

---

## I. TỔNG QUAN & KIẾN TRÚC HỆ THỐNG

### 1. Giới thiệu bài toán (Case Study)
- **Mô hình:** Ứng dụng mua sắm thời trang cho một thương hiệu may mặc độc lập (Single-Brand Fashion App).
- **Người dùng chính:**
  - **Khách hàng (Customer):** Xem bộ sưu tập, chọn size/màu, thêm vào giỏ, áp mã voucher giảm giá, chọn chi nhánh trên bản đồ, viết đánh giá sản phẩm, nhận thông báo đơn hàng và chat tư vấn kích cỡ trực tiếp với shop.
  - **Nhân viên / Chủ shop (Admin / Staff):** Màn hình công cụ hỗ trợ `ShopAdminScreen` để đổi trạng thái đơn hàng (Pending -> Delivering -> Delivered) và phản hồi tin nhắn khách hàng (dùng trực tiếp lúc Demo bảo vệ đồ án trước giảng viên).

### 2. Kiến trúc ứng dụng (MVVM + Provider)
```
UI Screens (Views)
       ↕ (Lắng nghe trạng thái & gửi Action người dùng)
Providers (ViewModels - ChangeNotifier: Quản lý giỏ hàng, Voucher, Auth, Chat, Order)
       ↕ (Gọi xử lý nghiệp vụ & dữ liệu)
Services (Data Layer - FirebaseAuth, FirebaseFirestore)
       ↕ (Truy vấn mạng / CSDL thời gian thực)
Firebase Cloud (Remote Database Firestore)
```

---

## II. THIẾT KẾ CƠ SỞ DỮ LIỆU (FIREBASE FIRESTORE)

Hệ thống sử dụng **7 Collections** đồng bộ trên Cloud Firestore:

### 1. `users` (Thông tin tài khoản)
- `uid` (String, Document ID): Khóa chính lấy từ Firebase Auth.
- `email` (String): Email đăng ký.
- `fullName` (String): Họ và tên hiển thị.
- `phone` (String): Số điện thoại liên hệ.
- `avatarUrl` (String): Link ảnh đại diện.
- `defaultAddress` (String): Địa chỉ nhận hàng mặc định.
- `role` (String): `"customer"` (Khách hàng) hoặc `"admin"` (Chủ shop).
- `createdAt` (Timestamp): Ngày tạo tài khoản.

### 2. `categories` (Danh mục thời trang)
- `id` (String, Document ID): Mã danh mục (`cat_aothun`, `cat_aokhoac`, `cat_quanjean`, `cat_phukien`).
- `name` (String): Tên danh mục (Áo Thun, Áo Khoác, Quần Jean, Phụ Kiện).
- `iconUrl` (String): Link ảnh/icon danh mục.

### 3. `products` (Sản phẩm quần áo)
- `id` (String, Document ID): Mã sản phẩm (VD: `prod_001`).
- `name` (String): Tên sản phẩm (VD: "Áo Polo Nam Form Regular").
- `categoryId` (String): Liên kết với `categories.id`.
- `price` (Number): Đơn giá bán (VD: `250000`).
- `description` (String): Mô tả chất liệu, kiểu dáng, bảng chọn size.
- `imageUrls` (Array of Strings): Danh sách 2-4 link ảnh sản phẩm.
- `sizes` (Array of Strings): Danh sách kích cỡ `["S", "M", "L", "XL"]`.
- `colors` (Array of Strings): Danh sách màu sắc `["Đen", "Trắng", "Xám", "Be"]`.
- `rating` (Number): Điểm đánh giá trung bình (VD: `4.8`).
- `reviews` (Array of Maps): Danh sách đánh giá `[{userName: "Nguyen Van A", rating: 5, comment: "Vải mát form đẹp", createdAt: Timestamp}]`.

### 4. `carts` (Giỏ hàng của khách)
- Document ID = `uid` của khách hàng.
- `items` (Array of Maps): Danh sách món hàng đã chọn:
  - `cartItemId` (String): Ghép theo công thức: `"${productId}_${size}_${color}"` (giúp phân biệt cùng 1 áo nhưng khác size hoặc màu).
  - `productId` (String): ID sản phẩm.
  - `productName` (String): Tên sản phẩm.
  - `imageUrl` (String): Ảnh đại diện sản phẩm.
  - `price` (Number): Giá tiền tại thời điểm thêm vào giỏ.
  - `size` (String): Size đã chọn (VD: `"L"`).
  - `color` (String): Màu đã chọn (VD: `"Đen"`).
  - `quantity` (Number): Số lượng đặt (VD: `2`).

### 5. `orders` (Đơn đặt hàng)
- `orderId` (String, Document ID): Mã đơn hàng tự sinh.
- `userId` (String): UID người mua.
- `userName` (String): Tên người nhận.
- `phone` (String): SĐT người nhận.
- `shippingAddress` (String): Địa chỉ nhận hàng (nhập tay hoặc ghim chọn từ bản đồ).
- `items` (Array of Maps): Danh sách món lấy sang từ giỏ hàng.
- `subtotal` (Number): Tổng tiền hàng tạm tính.
- `voucherCode` (String): Mã giảm giá đã áp dụng (hoặc rỗng `""`).
- `discountAmount` (Number): Số tiền được chiết khấu từ CartProvider.
- `totalPrice` (Number): Tổng thanh toán cuối cùng (`subtotal - discountAmount`).
- `paymentMethod` (String): `"COD"` (Thanh toán khi nhận hàng) hoặc `"VIETQR"` (Chuyển khoản).
- `status` (String): `"Pending"` (Chờ xác nhận) -> `"Delivering"` (Đang giao) -> `"Delivered"` (Đã giao).
- `createdAt` (Timestamp): Thời gian đặt hàng.

### 6. `notifications` (Thông báo người dùng)
- `id` (String, Document ID).
- `userId` (String): UID người nhận thông báo.
- `title` (String): Tiêu đề (VD: "Đặt hàng thành công", "Đơn hàng đang giao").
- `body` (String): Chi tiết nội dung.
- `isRead` (Boolean): Trạng thái đã xem/chưa xem (`false` / `true`).
- `createdAt` (Timestamp): Thời gian gửi.

### 7. `chats` (Kênh tư vấn trực tuyến với Shop)
- Document ID = `uid` của khách hàng.
- `lastMessage` (String): Tin nhắn gần nhất.
- `updatedAt` (Timestamp): Thời gian tin nhắn cuối.
- `userName` (String): Tên khách hàng.
- **Sub-collection `messages`**: Mỗi tin nhắn là 1 Document con gồm `{id, senderId, text, createdAt}`.

---

### 🔥 Cấu hình Firestore Security Rules (Tab Rules trên Firebase Console)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Cho phép đọc/ghi dữ liệu khi người dùng đã đăng nhập thành công
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## III. DỮ LIỆU CỐ ĐỊNH & HẰNG SỐ (APP CONSTANTS)
Tất cả lưu tại `lib/core/constants/app_constants.dart`:

```dart
import 'package:latlong2/latlong.dart';

class AppConstants {
  // 1. Tọa độ chi nhánh cửa hàng cố định (Dùng cho OpenStreetMap)
  // Lưu ý: Nhóm có thể đổi tọa độ về Campus trường mình (Hà Nội, Đà Nẵng, Quy Nhơn, Cần Thơ, TP.HCM)
  static final List<Map<String, dynamic>> storeBranches = [
    {
      "name": "Chi nhánh 1 - FPT University Campus",
      "address": "Khu Công Nghệ Cao, TP. Thủ Đức, TP.HCM",
      "location": LatLng(10.8411, 106.8105),
    },
    {
      "name": "Chi nhánh 2 - Fashion Flagship Store",
      "address": "123 Nguyễn Huệ, Quận 1, TP.HCM",
      "location": LatLng(10.7745, 106.7036),
    },
  ];

  // 2. Danh sách mã giảm giá mẫu (Vouchers) xử lý trực tiếp trong CartProvider
  static const Map<String, dynamic> vouchers = {
    "SALE10": {"type": "percent", "value": 0.10, "desc": "Giảm 10% tổng đơn"},
    "FREESHIP": {"type": "fixed", "value": 30000, "desc": "Giảm thẳng 30.000 VNĐ"},
  };
}
```

---

## IV. BẢNG TỔNG HỢP 10 HẠNG MỤC CHỨC NĂNG (100% ĐIỂM DEMO)

| STT | Hạng mục chấm điểm (10%/mục) | Chi tiết chức năng trên App | Thành phần kỹ thuật |
| :--- | :--- | :--- | :--- |
| **1** | **Database / API Structure** | Thiết kế chuẩn 7 Collections Firestore & 7 Dart Models có đầy đủ hàm `fromMap()`, `toMap()`. | `models/` & `services/firestore_service.dart` |
| **2** | **Login Screen** | Đăng nhập bằng Email/Password & Google Sign-In; Đăng ký tài khoản; Đăng xuất (kèm lệnh `cartProvider.clearCart()`). | `AuthProvider` $\leftrightarrow$ `FirebaseAuth` |
| **3** | **Product List Screen** | Banner quảng cáo, thanh chọn danh mục (Áo thun, Khoác, Quần), tìm kiếm tên tức thì, lọc/sắp xếp theo giá. | `ProductProvider` $\leftrightarrow$ `products` |
| **4** | **Product Detail Screen** | Xem gallery ảnh, mô tả form áo, chọn Size (S/M/L/XL), Màu sắc, Số lượng; Xem đánh giá & **Bấm nút "Viết đánh giá"** (hiện Dialog chọn sao + nhập bình luận $\rightarrow$ ghi trực tiếp `FieldValue.arrayUnion` lên Firestore); Bấm thêm vào giỏ. | `ProductProvider`, `CartProvider` $\leftrightarrow$ `products` |
| **5** | **Shopping Cart Screen** | Xem danh sách giỏ hàng theo Size/Màu, tăng/giảm số lượng, xóa item, **áp mã Voucher (SALE10/FREESHIP)**, tự động tính `subtotal`, `discountAmount`, `totalPrice`. | `CartProvider` $\leftrightarrow$ `carts` |
| **6** | **Checkout / Billing Screen** | Nhập/chọn địa chỉ giao từ Map, hiển thị tóm tắt đơn (lấy trực tiếp tổng tiền từ `CartProvider`), chọn COD hoặc VietQR, bấm Đặt hàng để tạo order. | `OrderProvider`, `CartProvider` $\leftrightarrow$ `orders` |
| **7** | **Notifications Screen** | Tự động tạo thông báo khi đặt hàng thành công và khi Shop cập nhật trạng thái đơn (Real-time). | `NotificationProvider` $\leftrightarrow$ `notifications` |
| **8** | **Map Screen** | Hiển thị vị trí 2 chi nhánh shop trên OpenStreetMap (`flutter_map` - hoàn toàn miễn phí, không cần thẻ Visa) & cho phép chạm chọn tọa độ nhận hàng. | `flutter_map`, `latlong2`, `geolocator` |
| **9** | **Messaging / Chat Screen** | Khách hàng chat trực tiếp thời gian thực (Real-time) với Shop để được tư vấn chiều cao/cân nặng chọn size. | `ChatProvider` $\leftrightarrow$ `chats` subcollection |
| **10** | **State Management** | Quản lý trạng thái bằng `MultiProvider`, `ChangeNotifier` và `Consumer` xuyên suốt toàn bộ app. | 6 Providers trong thư mục `providers/` |

> **🌟 Công cụ hỗ trợ Demo đặc biệt (`ShopAdminScreen`):**  
> Dành riêng cho tài khoản có `role: "admin"` (hoặc nút chuyển vai trò lúc demo). Cho phép người demo:
> 1. Xem danh sách tất cả đơn hàng $\rightarrow$ bấm nút chuyển trạng thái từ `Pending` $\rightarrow$ `Delivering` $\rightarrow$ kích hoạt ngay Notification trên máy khách.
> 2. Xem danh sách chat $\rightarrow$ bấm trả lời tin nhắn của khách ngay trước mặt giảng viên.

---

## V. CẤU TRÚC DỰ ÁN FLUTTER CHUẨN (`lib/` & `test/`)

```text
fashion_store_app/
├── android/
│   └── app/
│       └── google-services.json       # File cấu hình Firebase Android
├── lib/
│   ├── main.dart                      # Khởi tạo Firebase & bọc MultiProvider
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart        # Bảng màu giao diện
│   │   │   └── app_constants.dart     # Tọa độ chi nhánh & Mã voucher
│   │   └── utils/
│   │       └── formatters.dart        # Định dạng tiền tệ VND (intl)
│   ├── models/                        # 7 Models ánh xạ từ Firestore
│   │   ├── user_model.dart
│   │   ├── category_model.dart
│   │   ├── product_model.dart
│   │   ├── cart_item_model.dart
│   │   ├── order_model.dart
│   │   ├── notification_model.dart
│   │   └── message_model.dart
│   ├── services/                      # Tầng làm việc với Firebase
│   │   ├── auth_service.dart          # FirebaseAuth + Google Sign-In
│   │   └── firestore_service.dart     # Toàn bộ lệnh CRUD Firestore
│   ├── providers/                     # 6 ViewModels kế thừa ChangeNotifier
│   │   ├── auth_provider.dart
│   │   ├── product_provider.dart
│   │   ├── cart_provider.dart         # Quản lý giỏ hàng, áp mã Voucher & tính tổng tiền
│   │   ├── order_provider.dart        # Nhận dữ liệu giỏ hàng để tạo đơn & đẩy lên orders
│   │   ├── notification_provider.dart
│   │   └── chat_provider.dart
│   └── screens/
│       ├── main_nav_screen.dart       # BottomNavigationBar (Home, Cart, Orders, Chat, Profile)
│       ├── auth/
│       │   ├── login_screen.dart      # Màn hình đăng nhập + Google Login
│       │   └── register_screen.dart
│       ├── home/
│       │   ├── product_list_screen.dart
│       │   └── product_detail_screen.dart # Chi tiết sản phẩm + Nút viết review
│       ├── cart/
│       │   ├── cart_screen.dart       # Giỏ hàng & Nhập mã Voucher
│       │   └── checkout_screen.dart   # Thanh toán & Xác nhận đơn
│       ├── orders/
│       │   └── order_history_screen.dart
│       ├── notifications/
│       │   └── notification_screen.dart
│       ├── map/
│       │   └── store_map_screen.dart  # Bản đồ chi nhánh OpenStreetMap
│       ├── chat/
│       │   └── chat_screen.dart
│       ├── profile/
│       │   └── profile_screen.dart    # Thông tin cá nhân & Nút Đăng xuất
│       └── admin/
│           └── shop_admin_screen.dart # Công cụ đổi status đơn hàng & rep chat khi demo
└── test/                              # BẮT BUỘC THEO ĐỀ BÀI (MỤC 4)
    ├── cart_provider_test.dart        # 01 Unit Test (Test trực tiếp CartProvider thật)
    └── login_screen_test.dart         # 01 Widget Test (Test trực tiếp LoginScreen thật)
```

---

## VI. DANH SÁCH THƯ VIỆN CẦN CÀI (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase & Authentication
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  google_sign_in: ^6.2.1

  # State Management
  provider: ^6.1.2

  # Bản đồ miễn phí (Không cần thẻ Visa / Google Cloud)
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^13.0.1

  # Giao diện & Tiện ích
  cached_network_image: ^3.4.1
  intl: ^0.19.0
  flutter_spinkit: ^5.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## VII. CODE MẪU 2 BÀI TEST CHUẨN XÁC (UNIT TEST & WIDGET TEST TRÊN CLASS THẬT)

### 1. File `test/cart_provider_test.dart` (Unit Test trực tiếp trên class `CartProvider` thật)
*Bài test import trực tiếp `CartProvider` từ thư mục `lib/providers/` để kiểm tra logic tính tiền và chiết khấu Voucher:*

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/providers/cart_provider.dart';
import 'package:fashion_store_app/models/cart_item_model.dart';

void main() {
  group('Kiểm thử Đơn vị (Unit Test) cho CartProvider thật:', () {
    late CartProvider cartProvider;

    setUp(() {
      cartProvider = CartProvider();
      // Giả lập thêm 2 món hàng có tổng tiền 500.000đ vào giỏ
      cartProvider.addItem(CartItemModel(
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
```
*Lệnh chạy kiểm thử:* `flutter test test/cart_provider_test.dart`

---

### 2. File `test/login_screen_test.dart` (Widget Test trực tiếp trên màn hình `LoginScreen` thật)
*Bài test import trực tiếp màn hình `LoginScreen` thật từ `lib/screens/auth/` và bọc trong Provider giả lập:*

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fashion_store_app/screens/auth/login_screen.dart';
import 'package:fashion_store_app/providers/auth_provider.dart';

void main() {
  testWidgets('Kiểm thử Giao diện (Widget Test) màn hình LoginScreen thật', (WidgetTester tester) async {
    // Render màn hình LoginScreen bọc trong AuthProvider
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Kiểm tra có ô nhập Email và Mật khẩu hay không
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Kiểm tra có nút Đăng nhập thông thường hay không
    expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);

    // Kiểm tra có nút Đăng nhập với Google hay không
    expect(find.textContaining('Google'), findsOneWidget);
  });
}
```
*Lệnh chạy kiểm thử:* `flutter test test/login_screen_test.dart`

---

## VIII. HƯỚNG DẪN BUILD RELEASE APK & CẤU HÌNH GOOGLE SIGN-IN

### ⚠️ Lưu ý sống còn để không bị lỗi `ApiException: 10` khi đăng nhập Google:
Khi chạy ở chế độ **Debug**, Google dùng keystore debug. Nhưng khi chạy lệnh `flutter build apk --release`, Gradle sẽ dùng keystore release. Nếu thiếu mã vân tay trên Firebase Console, nút Đăng nhập Google trên file APK Release sẽ bị văng lỗi ngay lập tức.

#### Quy trình chuẩn:
1. Mở Terminal tại thư mục `android/` và chạy lệnh:
   ```powershell
   ./gradlew signingReport
   ```
2. Tìm và copy **cả hai cặp mã SHA-1 và SHA-256** của:
   - `Variant: debug`
   - `Variant: release`
3. Truy cập **Firebase Console** $\rightarrow$ **Project Settings** (icon bánh răng ⚙️) $\rightarrow$ cuộn xuống mục **Your apps** $\rightarrow$ chọn App Android:
   - Bấm **Add fingerprint** và dán đủ cả 2 mã SHA-1 (debug & release).
   - Tiếp tục bấm **Add fingerprint** và dán cả 2 mã SHA-256.
4. Tải lại file **`google-services.json`** mới nhất và chép đè vào thư mục `android/app/`.

#### Lệnh xuất bản file APK:
1. Chạy lệnh:
   ```bash
   flutter build apk --release
   ```
2. File APK thành phẩm sẽ xuất hiện tại:
   `build/app/outputs/flutter-apk/app-release.apk`
3. Cài đặt file này vào điện thoại thật hoặc máy ảo, chụp ảnh màn hình ứng dụng đang chạy ở chế độ Release để đưa vào báo cáo.

---

## IX. CẤU TRÚC NỘI DUNG FILE BÁO CÁO KỸ THUẬT (.PDF)

Báo cáo gồm **7 mục** đúng chuẩn 100% barem chấm điểm của FPT:
1. **Team Introduction:** Bảng thành viên nhóm (Họ tên, MSSV, Email, Vai trò: Trưởng nhóm, Frontend, Backend, Tester).
2. **Case Study (10%):** Giới thiệu thương hiệu thời trang, bối cảnh vì sao cần ứng dụng di động để tăng doanh số và chăm sóc khách hàng.
3. **Business Analysis / System Design (15% + 15%):**
   - Danh sách Functional Requirements (10 chức năng) & Non-functional Requirements.
   - Công nghệ mới: Google OAuth 2.0, Firestore Realtime Streams, OpenStreetMap (`flutter_map`).
   - 3 Sơ đồ: Sơ đồ kiến trúc Provider (MVVM), Sơ đồ luồng màn hình (UI Flow), Sơ đồ 7 bảng Firestore.
4. **Development Requirements:** 
   - Ảnh chụp kết quả chạy lệnh `flutter test` (Unit Test & Widget Test xanh màu `All tests passed!`).
   - Ảnh chụp lệnh `flutter build apk --release` và màn hình app chạy ở chế độ Release.
5. **Demo of Mobile Application (50%):** Ảnh chụp chi tiết từng màn hình hoạt động, giải thích luồng Provider và tối ưu hiệu năng với `Consumer`, `cached_network_image`.
6. **Conclusion and Discussion (10%):** Ưu điểm, hạn chế của ứng dụng, bài học kinh nghiệm và định hướng mở rộng (tích hợp thanh toán trực tuyến qua cổng VNPAY/ZaloPay, gợi ý trang phục bằng AI).
7. **Contribution Table:** Bảng đánh giá % đóng góp của từng thành viên (tổng mỗi hàng là 100%).
