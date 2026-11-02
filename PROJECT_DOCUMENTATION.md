# 📘 BẢN TÀI LIỆU DỰ ÁN TOÀN DIỆN (PROJECT SPECIFICATION & ARCHITECTURE)
## ĐỀ TÀI: ỨNG DỤNG MUA SẮM THỜI TRANG TRỰC TUYẾN (FASHION MOBILE STORE APP)
**Học phần:** PRM393 - Mobile Application Development • Trường Đại học FPT  
**Công nghệ:** Flutter 3.x • Dart 3.x • Firebase Cloud Services • OpenStreetMap • SePay Gateway  
**Kiến trúc:** MVVM (Model - View - ViewModel) với thư viện State Management `provider`

---

## I. TỔNG QUAN HỆ THỐNG

### 1. Giới thiệu bài toán
Dự án xây dựng một ứng dụng thương mại điện tử chuyên biệt cho thương hiệu thời trang độc lập (Single-Brand E-Commerce, phong cách thời trang tối giản Lifewear). Hệ thống cung cấp trải nghiệm mua sắm mượt mà từ khâu chọn kích cỡ chuẩn xác, ghim địa chỉ nhận hàng trên bản đồ vệ tinh, thanh toán tự động qua mã VietQR Napas24/7 đến kênh tư vấn khách hàng thời gian thực và trung tâm quản trị cửa hàng chuyên nghiệp.

### 2. Hai nhóm người dùng chính (RBAC - Role-Based Access Control)
- **Khách hàng (Customer):** Đăng ký/đăng nhập, tìm kiếm sản phẩm, nhận gợi ý size thông minh theo chiều cao/cân nặng, quản lý sổ địa chỉ, đặt hàng COD/VietQR, theo dõi đơn hàng, gửi yêu cầu đổi/trả và chat trực tuyến với cửa hàng.
- **Quản trị viên (Shop Admin):** Truy cập cổng quản trị riêng biệt (`ShopAdminScreen`), xem báo cáo kinh doanh (BI Dashboard doanh thu thực, đơn hàng, tỷ lệ hoàn), kiểm duyệt đơn hàng, quản lý kho hàng chi tiết tới từng SKU (Kích cỡ x Màu sắc), quản trị hệ thống showroom chi nhánh và trực chat hỗ trợ khách hàng.

---

## II. NGĂN XẾP CÔNG NGHỆ (TECH STACK)

| Thành phần | Công nghệ / Thư viện | Vai trò |
| :--- | :--- | :--- |
| **Framework & Ngôn ngữ** | Flutter (SDK 3.x) & Dart (3.x Null-Safety) | Xây dựng ứng dụng di động đa nền tảng tối ưu hiệu năng |
| **Kiến trúc & Quản lý trạng thái** | MVVM Pattern + `provider` (MultiProvider, ChangeNotifier) | Tách biệt hoàn toàn giao diện (Views) và logic nghiệp vụ (ViewModels) |
| **Xác thực người dùng** | `firebase_auth` & `google_sign_in` | Đăng nhập Email/Mật khẩu, Đăng nhập 1 chạm Google OAuth 2.0 |
| **Cơ sở dữ liệu đám mây** | `cloud_firestore` (NoSQL Realtime Database) | Đồng bộ dữ liệu thời gian thực cho 7 bộ sưu tập cốt lõi |
| **Thanh toán trực tuyến** | VietQR Specification & `http` (SePay Webhook/API) | Tạo mã QR Napas24/7 động, tự động đối soát giao dịch và hủy đơn timeout |
| **Bản đồ & Định vị** | `flutter_map`, `latlong2`, `geolocator` | Bản đồ OpenStreetMap hoàn toàn miễn phí, không phụ thuộc API key trả phí |
| **Xử lý hình ảnh** | `image_picker`, `cached_network_image`, `AppImage` | Hỗ trợ cả URL đám mây và ảnh Base64 nén cục bộ tải từ thiết bị |
| **Kiểm thử tự động** | `flutter_test` (203 Test Cases) | Bộ kiểm thử toàn diện từ Unit Test Provider/Service tới Widget Test giao diện |

---

## III. KIẾN TRÚC DỮ LIỆU (7 FIRESTORE COLLECTIONS)

Cơ sở dữ liệu được thiết kế chuẩn NoSQL trên Cloud Firestore, tối ưu hóa cho truy vấn thời gian thực:

```
Cloud Firestore
├── users/{uid}                     # Hồ sơ tài khoản, vai trò, số đo & sổ địa chỉ
├── categories/{cat_id}             # Danh mục sản phẩm thời trang
├── products/{product_id}           # Sản phẩm, biến thể SKU, tồn kho & đánh giá
├── carts/{uid}                     # Giỏ hàng cá nhân hóa theo từng người dùng
├── orders/{order_id}               # Đơn hàng, lịch sử trạng thái & thanh toán
├── notifications/{notification_id} # Thông báo đẩy thời gian thực
└── chats/{uid}                     # Kênh chat trực tuyến (Subcollection: messages)
```

### Chi tiết các Collections:
1. **`users`:**
   - `uid` (String, DocID): ID người dùng từ Firebase Auth.
   - `email`, `fullName`, `phone`, `avatarUrl`: Thông tin cơ bản.
   - `defaultAddress`: Địa chỉ giao hàng mặc định.
   - `savedAddresses`: Danh sách sổ địa chỉ đa điểm kèm tọa độ GPS (`latitude`, `longitude`).
   - `savedHeight`, `savedWeight`: Chiều cao (cm) và cân nặng (kg) phục vụ gợi ý size.
   - `wishlistProductIds`: Mảng ID các sản phẩm khách hàng đã lưu yêu thích.
   - `role`: `"customer"` hoặc `"admin"`.

2. **`categories`:**
   - `id` (DocID): `cat_aothun`, `cat_aokhoac`, `cat_quanjean`, `cat_phukien`, v.v.
   - `name`: Tên hiển thị (Áo thun, Áo khoác, Quần Jeans, Phụ kiện).
   - `iconUrl`: Biểu tượng danh mục.

3. **`products`:**
   - `id` (DocID): Mã sản phẩm (VD: `prod_001`).
   - `name`, `categoryId`, `description`, `price`, `originalPrice`: Thông tin niêm yết.
   - `sizes`: Mảng kích cỡ `["S", "M", "L", "XL"]`.
   - `colors`: Mảng màu sắc `["Đen", "Trắng", "Xanh Navy", "Be"]`.
   - `stock`: Tổng tồn kho hiện tại.
   - `variantStock`: Map phân bổ tồn kho chi tiết theo SKU `${size}_${color}` (VD: `{"M_Đen": 15, "L_Trắng": 8}`).
   - `imageUrls`: Danh sách hình ảnh (hỗ trợ cả URL và chuỗi Base64 Data URI).
   - `soldCount`: Số lượng đã bán thực tế (dùng cho thống kê và sắp xếp bán chạy).
   - `rating`, `reviews`: Điểm trung bình và mảng nhận xét sao từ khách hàng.
   - `isActive`: Trạng thái hiển thị bán trên app (`true`/`false`).

4. **`carts`:**
   - `DocID`: Trùng với `uid` của khách hàng.
   - `items`: Danh sách sản phẩm trong giỏ:
     - `cartItemId`: Ghép chuẩn `${productId}_${size}_${color}` đảm bảo phân tách chính xác từng biến thể.
     - `productId`, `productName`, `imageUrl`, `price`, `size`, `color`, `quantity`.

5. **`orders`:**
   - `orderId` (DocID): Mã đơn sinh tự động (VD: `KUOPX435`).
   - `userId`, `userName`, `phone`, `shippingAddress`: Thông tin nhận hàng.
   - `items`: Mảng món hàng kèm phân loại size, màu và đơn giá tại thời điểm đặt.
   - `subtotal`, `discountAmount`, `shippingFee`, `totalPrice`: Dữ liệu tài chính đơn hàng.
   - `deliveryMethod`: `"DELIVERY"` (Giao tận nơi) hoặc `"PICKUP"` (Nhận tại cửa hàng).
   - `paymentMethod`: `"COD"` (Thanh toán khi nhận) hoặc `"VIETQR"` (Chuyển khoản Napas24/7).
   - `paymentStatus`: `"Pending"`, `"Paid"`, `"Refunded"`.
   - `status`: `"Pending"` -> `"Delivering"` -> `"Delivered"` / `"Cancelled"` / `"ReturnRequested"` / `"Returned"`.
   - `createdAt`, `updatedAt`: Dấu thời gian.

6. **`notifications`:**
   - `id` (DocID), `userId`, `title`, `body`, `type`, `orderId`, `isRead`, `createdAt`.

7. **`chats` & `chats/{uid}/messages`:**
   - Document cha lưu thông tin tóm tắt: `lastMessage`, `lastSenderId`, `updatedAt`, `unreadCountAdmin`, `unreadCountCustomer`.
   - Subcollection `messages`:
     - `senderId`, `senderName`, `text`, `createdAt`, `isRead`.
     - `imageUrl`: Link hoặc Base64 ảnh đính kèm.
     - `attachedProduct`: Dữ liệu thẻ sản phẩm đính kèm (cho phép chat tư vấn trực tiếp về 1 sản phẩm).
     - `attachedOrder`: Dữ liệu thẻ đơn hàng đính kèm (hỗ trợ giải quyết khiếu nại/tra cứu nhanh).

---

## IV. KIẾN TRÚC TẦNG PROVIDER (6 VIEWMODELS)

```
       ┌─────────────────── UI SCREENS (VIEWS) ───────────────────┐
       │   Customer Screens    │    Admin Management Screens      │
       └─────────────────────────────┬────────────────────────────┘
                                     │ Consumer / Selector
       ┌─────────────────────────────▼────────────────────────────┐
       │                       PROVIDERS                          │
       │  • AuthProvider         • ProductProvider  • CartProvider │
       │  • OrderProvider        • ChatProvider     • NotifProvider│
       └─────────────────────────────┬────────────────────────────┘
                                     │ Calls
       ┌─────────────────────────────▼────────────────────────────┐
       │                       SERVICES                           │
       │  • AuthService   • FirestoreService   • SePayService     │
       └─────────────────────────────┬────────────────────────────┘
                                     │
       ┌─────────────────────────────▼────────────────────────────┐
       │            Firebase Firestore & SePay Webhook            │
       └──────────────────────────────────────────────────────────┘
```

1. **`AuthProvider`:** Quản lý phiên đăng nhập, vai trò Admin/Customer, sổ địa chỉ, hồ sơ số đo chiều cao/cân nặng, danh sách sản phẩm yêu thích (Wishlist).
2. **`ProductProvider`:** Lắng nghe danh sách sản phẩm, danh mục thời gian thực, xử lý bộ lọc (danh mục, khoảng giá, màu sắc, size), tìm kiếm tức thời, quản lý CRUD sản phẩm và nhập kho nhanh SKU cho Admin.
3. **`CartProvider`:** Quản lý giỏ hàng cục bộ và đồng bộ Firestore, chọn/bỏ chọn món thanh toán độc lập, áp dụng voucher giảm giá động, kiểm tra giới hạn số lượng theo tồn kho SKU.
4. **`OrderProvider`:** Đặt hàng, quản lý đơn hàng theo người dùng và toàn hệ thống, tự động quét đối soát SePay và tự hủy đơn VietQR quá hạn (Background Sweeper Timer 3s), cập nhật trạng thái đơn (Duyệt giao hàng, Hoàn tất, Yêu cầu Đổi/Trả).
5. **`NotificationProvider`:** Lắng nghe thông báo Firestore thời gian thực, đếm số lượng chưa đọc, đánh dấu đã đọc.
6. **`ChatProvider`:** Quản lý kênh chat khách hàng và hộp thư Admin, lắng nghe tin nhắn thời gian thực, gửi tin nhắn văn bản, hình ảnh, đính kèm thẻ sản phẩm hoặc thẻ đơn hàng.

---

## V. CÁC TÍNH NĂNG NỔI BẬT ĐÃ ĐƯỢC CHUẨN HÓA

### 1. Trợ lý Kích cỡ Thông minh (Smart Size Recommendation Engine)
- Tính toán chỉ số thể trạng dựa trên Chiều cao (cm) và Cân nặng (kg) của khách hàng.
- Tự động gợi ý kích cỡ phù hợp nhất (`S`, `M`, `L`, `XL`, `XXL`) kèm ghi chú phom dáng (Ôm vừa vặn / Thoải mái Lifewear).

### 2. Cổng Thanh toán VietQR & Hệ thống Tự động Đối soát SePay
- Sinh mã QR thanh toán chuẩn ngân hàng Napas24/7 với nội dung chuyển khoản tự động `DH <MÃ_ĐƠN>` và đúng số tiền thanh toán.
- **Tiến trình chạy ngầm độc lập:** Kể cả khi khách hàng đóng hộp thoại thanh toán, hệ thống vẫn duy trì chu kỳ quét đối soát mỗi 5s qua SePay API. Khi nhận được tiền, đơn hàng lập tức chuyển sang `Paid`.
- **Cơ chế Timeout an toàn:** Sau 2 phút (thời gian cấu hình kiểm thử), nếu chưa nhận được thanh toán, đơn hàng tự động chuyển sang `Cancelled` (Đã hủy), tự động hoàn trả số lượng vào kho (`stock` & `variantStock`), và gửi thông báo cho khách hàng.

### 3. Tích hợp Bản đồ OpenStreetMap (100% Free & No API Key)
- Khách hàng có thể tìm kiếm, kéo thả ghim vị trí nhận hàng trực quan trên bản đồ OpenStreetMap bằng GPS thiết bị.
- Bản đồ Showroom hiển thị danh sách các chi nhánh của cửa hàng, tính khoảng cách thực tế và hỗ trợ chỉ đường.

### 4. Báo cáo Kinh doanh (BI Analytics Dashboard) dành cho Admin
- Doanh thu thuần chỉ tính từ các đơn hàng Giao thành công (`Delivered`).
- Thống kê tỷ lệ hoàn tất, đơn chờ duyệt, lượt hủy đơn.
- Danh sách sản phẩm bán chạy nhất được sắp xếp tự động dựa trên `soldCount`.

### 5. Chat CSKH Đa phương tiện & Đính kèm ngữ cảnh (Contextual Attachments)
- Khách hàng và Admin trò chuyện trực tiếp với độ trễ thấp.
- Cho phép đính kèm trực tiếp Thẻ sản phẩm đang xem hoặc Thẻ đơn hàng đang thắc mắc ngay trong khung chat để nhân viên hỗ trợ nhanh chóng nhất.

---

## VI. BỘ KIỂM THỬ TỰ ĐỘNG (AUTOMATED TEST SUITE)

Dự án được bảo vệ bởi **203 bài kiểm thử tự động**, đạt tỷ lệ **100% Passed**:
- `auth_provider_test.dart`: Đăng nhập, phân quyền, sổ địa chỉ, đổi mật khẩu.
- `cart_provider_test.dart`: Thêm giỏ, chọn món, voucher, tính phí ship.
- `product_provider_test.dart`: Bộ lọc, tìm kiếm, nhập kho nhanh SKU.
- `order_provider_test.dart`: Đặt hàng, tính toán tồn kho, luồng thanh toán VietQR & SePay timeout.
- `chat_provider_test.dart`: Gửi nhận tin nhắn, đính kèm sản phẩm, đính kèm đơn hàng.
- `admin_management_test.dart`: Quản trị sản phẩm, danh mục, chi nhánh.
- `shop_admin_bi_test.dart`: Thống kê doanh thu, lọc đơn hàng, KPI metrics.
- `widget_tests`: Giao diện giỏ hàng, bản đồ chi nhánh, chi tiết đơn hàng, wishlist, profile.
