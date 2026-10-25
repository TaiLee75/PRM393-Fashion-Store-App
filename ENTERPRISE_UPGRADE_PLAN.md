# 🏛️ BẢN ĐẶC TẢ TÁI CẤU TRÚC & NÂNG CẤP HỆ THỐNG CHUẨN DOANH NGHIỆP (ENTERPRISE E-COMMERCE ARCHITECTURE SPECIFICATION — V4.1 FORENSIC AUDIT EDITION)
## DỰ ÁN: FASHION MOBILE STORE APP (UNIQLO / COOLMATE MODEL)
**Kiến trúc nền tảng:** MVVM (Model - View - ViewModel) với `Provider` (6 Providers cốt lõi)  
**Cơ sở dữ liệu:** Firebase Authentication & Cloud Firestore (7 Collections chuẩn + `branches`)  
**Triết lý thiết kế của bản V4.1:**
- **Đặt Nghiệp vụ Doanh nghiệp Thực tế (Real-world Fashion E-Commerce Logic) làm trọng tâm tuyệt đối:** Mọi luồng từ Tồn kho SKU (`Size + Màu`), Giỏ hàng chọn lọc (`isSelected`), Mua ngay độc lập (`Direct Buy`), Tách bạch Phí Ship vs Voucher Hàng/Ship, Giao tận nơi vs Nhận tại cửa hàng (`Click & Collect`), Đối soát VietQR 2 bước, Sửa địa chỉ đơn `Pending`, Hủy đơn & Đổi/Trả hàng (`Return/Exchange`), đến Quản trị BI Dashboard đều được thiết kế theo chuẩn vận hành của Uniqlo, Coolmate và Shopee Mall.
- **Khóa chặt 100% Góc chết Liên Phân hệ & Race Conditions (19 Cross-Module Traps Locked):** Đã đối chiếu từng dòng code (Line-by-line Forensic Trace) trên toàn bộ 38 file `.dart` giữa `FirestoreService` $\leftrightarrow$ `6 Providers` $\leftrightarrow$ `IndexedStack Navigation` $\leftrightarrow$ `UI Screens` để triệt tiêu hoàn toàn 19 bẫy logic ngầm, xung đột trạng thái và lỗ hổng bảo mật.
- **Không thỏa hiệp logic vì các file test cũ:** Các bài test đơn giản của phạm vi đồ án cũ sẽ được viết/cập nhật lại ở bước cuối cùng theo chuẩn nghiệp vụ doanh nghiệp mới.

---

## I. CHẨN ĐOÁN TOÀN DIỆN: 26 LỖI NGHIỆP VỤ & LỖ HỔNG KỸ THUẬT TRONG CODE HIỆN TẠI

Qua giải phẫu từng dòng code trong toàn bộ 38 file mã nguồn tại `lib/` và `pubspec.yaml`, dưới đây là danh sách đầy đủ các điểm đứt gãy khiến ứng dụng hiện tại chưa đạt chuẩn doanh nghiệp:

### A. Nhóm Lỗi Đứt gãy Dữ liệu, Điều hướng & Bảo mật Phân quyền (Data, Navigation & Security Bugs)
1. **Collection `carts` chết hoàn toàn & Rò rỉ `StreamSubscription` (`lib/providers/cart_provider.dart` dòng 9 & 39–50):**
   - Biến `final String? userId` bị gán cứng `null` từ `lib/main.dart` (dòng 44) và hàm `loadUserCart(String userId)` không bao giờ gán lại `userId` $\rightarrow$ Hàm `_syncWithFirestore()` (dòng 157) luôn kiểm tra `uid != null` ra `false`, khiến mọi thao tác Thêm/Sửa/Xóa giỏ hàng **chưa bao giờ được lưu lên Firestore `carts/{uid}`**!
   - Hàm `loadUserCart` gọi `.listen()` trực tiếp mà không lưu hay `cancel()` biến `StreamSubscription`, gây rò rỉ listener mỗi lần nạp lại.
2. **Hàm `FirestoreService.createOrder()` (dòng 200) tự ý xóa sạch toàn bộ Giỏ hàng Cloud (`await clearCart(order.userId)`):** Dòng lệnh xóa cứng này nằm ngay trong `FirestoreService.createOrder()`, khiến mọi nỗ lực làm tính năng *"Chọn 1 số món trong giỏ để thanh toán"* hoặc *"Mua ngay 1 món"* đều sẽ bị `FirestoreService` xóa bay toàn bộ các món còn lại trong giỏ hàng!
3. **Lỗi Kiến trúc Điều hướng phá hủy `Consumer<AuthProvider>` gốc ở cả 4 màn hình (`lib/screens/auth/login_screen.dart` dòng 39 & 58, `lib/screens/auth/register_screen.dart` dòng 49, `lib/screens/profile/profile_screen.dart` dòng 430, `lib/screens/cart/checkout_screen.dart` dòng 106 & 150):**
   - Trong `lib/main.dart` đã dùng `Consumer<AuthProvider>` ở `home` để tự động chuyển giữa `LoginScreen` và `MainNavScreen`.
   - Thế nhưng cả 4 màn hình `LoginScreen`, `RegisterScreen`, `ProfileScreen` và `CheckoutScreen` lại gọi `Navigator.pushReplacement` / `Navigator.pushAndRemoveUntil` đè lên route gốc `/`!
   - **Hậu quả:** Khi đăng nhập/đăng ký, `MainNavScreen` bị khởi tạo **2 lần chồng lên nhau** (nhân đôi toàn bộ stream Firestore); và sau lần `pushReplacement` / `pushAndRemoveUntil` đầu tiên, `Consumer<AuthProvider>` ở `main.dart` bị xóa vĩnh viễn khỏi cây Widget!
4. **Xung đột Stream `ChatProvider` do `IndexedStack` trong `MainNavScreen` (`lib/screens/main_nav_screen.dart` dòng 177 & `lib/providers/chat_provider.dart` dòng 10):**
   - `MainNavScreen` dùng `IndexedStack` giữ sống cả 5 tab nên `ChatScreen.initState()` chỉ chạy 1 lần lúc mở app.
   - `ChatProvider` lại dùng chung 1 mảng `_messages` và 1 `_messagesSub` cho cả Khách lẫn Admin. Khi mở `AdminChatDetailScreen` xem tin nhắn của khách khác rồi quay lại Tab 3 (`Tư vấn`), `ChatScreen` bị kẹt cứng ở đoạn chat của khách đó!
5. **Lỗ hổng Leo thang Đặc quyền (Privilege Escalation / Broken Access Control) & Báo lỗi sai trên Trang chủ (`lib/screens/home/product_list_screen.dart` dòng 31 & 334–376):**
   - Dòng 334 kiểm tra `else if (products.isEmpty)` trên `filteredProducts` thay vì `allProducts`. Khi một tài khoản Khách hàng (`customer`) bình thường gõ một từ khóa bất kỳ không khớp (VD: `"zzzz"`) hoặc lọc không có kết quả $\rightarrow$ Màn hình báo sai là *"Chưa có dữ liệu sản phẩm trên Firestore"* và hiện nút **"Mở Admin Tool & Nạp Seed Data"** cho phép khách nhảy thẳng vào `ShopAdminScreen` mà không hề kiểm tra `authProvider.isAdmin`!
6. **Collection `categories` bị bỏ quên ở nhánh Admin & Nguy cơ Crash `DropdownButtonFormField` (`lib/screens/admin/admin_product_list_screen.dart` & `lib/screens/admin/admin_product_form_screen.dart` dòng 228):** Hai màn hình Admin dùng mảng `const _categories` gõ cứng trong code thay vì lấy từ `productProvider.categories` (Firestore collection `categories`), Admin không có chức năng Thêm/Sửa/Xóa danh mục, và nếu `categoryId` của sản phẩm không nằm trong danh sách `items` của `DropdownButtonFormField` sẽ gây crash đỏ màn hình (`AssertionError`).
7. **Hàm `FirestoreService.seedInitialData()` (dòng 411–422) ghi thiếu trường & Ghi đè mất dữ liệu thực tế:** Khi chạy `seedInitialData()`, `batch.set()` chỉ ghi thủ công 10 trường cũ (bỏ sót `originalPrice`, `stock`, `variantStock`, `soldCount`, `isActive`, `openHours`) và không dùng `SetOptions(merge: true)`, khiến nếu bấm Seed Data lại sẽ làm toàn bộ kho hàng về 0 (Hết hàng) và xóa mất các đánh giá mới.
8. **Lỗi `NOT_FOUND` khi đổi quyền Admin hoặc cập nhật Profile (`lib/providers/auth_provider.dart` & `lib/services/firestore_service.dart`):** Khi một tài khoản Firebase Auth đăng nhập nhưng document `users/{uid}` chưa tồn tại (hoặc sau khi xóa DB), `_userModel` bị `null` vĩnh viễn hoặc văng lỗi `cloud_firestore/not-found`.
9. **Bẫy xóa sạch giỏ hàng Cloud khi Đăng xuất & Rò rỉ dữ liệu chéo giữa 2 tài khoản (`lib/screens/profile/profile_screen.dart` dòng 427):**
   - Khi Đăng xuất, `ProfileScreen` dòng 427 gọi `cartProvider.clearCart()` (hàm này gọi `_syncWithFirestore()` xóa trắng giỏ hàng lưu trên Cloud của khách!).
   - Ngược lại, `OrderProvider`, `NotificationProvider`, `ChatProvider` lại không hề được hủy `StreamSubscription` hay dọn bộ nhớ RAM khi Đăng xuất, làm tài khoản đăng nhập sau nhìn thấy đơn hàng/thông báo/tin nhắn của tài khoản trước!

### B. Nhóm Lỗi Nghiệp vụ Kho vận, Mua sắm & Giỏ hàng (Retail & Merchandising Gaps)
10. **Không có Tồn kho theo Biến thể SKU (`Size + Màu`) và Tồn kho tổng (`lib/models/product_model.dart`):** Bán quần áo nhưng không quản lý số lượng tồn của từng cặp `Size_Màu` (VD: *Size L - Đen* hết hàng nhưng *Size S - Trắng* còn hàng). Khách đặt 9.999 cái vẫn được, đặt xong kho không trừ, hủy đơn kho không hoàn.
11. **Lỗi mất biến thể `FreeSize`, Màu sắc & Ghi đè mất `reviews`/`imageUrls` khi Admin lưu sản phẩm (`lib/providers/product_provider.dart` dòng 199 & `lib/screens/admin/admin_product_form_screen.dart` dòng 39–144):**
    - Trong `mock_data.dart`, sản phẩm Phụ kiện (`Nón`, `Thắt lưng`) có size `"FreeSize"` và các sản phẩm có màu `"Xanh rêu"`, `"Xanh đậm"`, `"Xanh nhạt"`, `"Xanh navy"`.
    - Nhưng `ProductProvider.availableSizes` chỉ trả về `['S', 'M', 'L', 'XL']` (khách không lọc được `FreeSize`), còn `AdminProductFormScreen` dùng `['S', 'M', 'L', 'XL', 'XXL']` (thiếu `'FreeSize'`), chỉ có 1 ô nhập URL ảnh (làm mất sạch các ảnh thứ 2, 3 khi sửa sản phẩm), và `updateProduct()` ghi đè cả mảng `reviews` cũ trong snapshot lúc mở form lên Firestore!
12. **Thiếu Giá niêm yết (`originalPrice`) & Trợ lý Chọn Size (`Size Guide`) (`lib/screens/home/product_detail_screen.dart`):** Không có giá gốc gạch ngang kèm `% Giảm giá`; bảng size mới chỉ là bảng tĩnh, chưa có công cụ **Gợi ý Size tự động theo Chiều cao & Cân nặng**.
13. **Giỏ hàng "Cưỡng bức", Thiếu luồng "Mua ngay" độc lập & Không đồng bộ Giá/Tồn kho mới nhất (`lib/screens/cart/cart_screen.dart` & `lib/screens/cart/checkout_screen.dart`):**
    - Trong `CartScreen` không có Checkbox chọn từng món để thanh toán, không đổi được Size/Màu ngay trong giỏ, không có thanh tiến trình Freeship.
    - Hàng lưu trong giỏ từ hôm trước nếu hôm nay Admin đổi giá, hết hàng hoặc ngừng kinh doanh (`isActive == false`) thì giỏ hàng không biết để cập nhật/chặn thanh toán.
    - Trang chi tiết sản phẩm thiếu nút **"MUA NGAY"**.
14. **Lỗi kẹt từ khóa tìm kiếm & Banner chết trên Trang chủ (`lib/screens/home/product_list_screen.dart`):**
    - Khi bấm nút `"Xóa tất cả"` bộ lọc (dòng 184), hàm `productProvider.resetFilters()` không xóa `_searchQuery` và **không gọi `_searchController.clear()`**, làm chữ cũ vẫn kẹt trong ô `TextField`.
    - Banner khuyến mãi đầu trang (`LIFEWEAR 2026 - Mã SALE10 • FREESHIP`) có icon mũi tên `>` (dòng 254) nhưng không gắn sự kiện bấm.

### C. Nhóm Lỗi Tài chính, Bản đồ, Đơn hàng & Quản trị (Order, Finance, Map & Admin Gaps)
15. **Sai lệch công thức Voucher `FREESHIP` & Bỏ quên `AppConstants.vouchers` (`lib/providers/cart_provider.dart` & `lib/core/constants/app_constants.dart`):** Mã `FREESHIP` trong `CartProvider` trừ thẳng `30.000đ` vào tiền hàng ngay cả khi chưa có phí ship hoặc khi khách chọn nhận tại cửa hàng (`0đ` phí ship).
16. **Bản đồ `StoreMapScreen` trả về địa chỉ Chi nhánh hoặc tọa độ thô (`lib/screens/map/store_map_screen.dart` dòng 28–35 & 128–136):** Khi mở từ `CheckoutScreen` (`isPickerMode: true`), địa chỉ mặc định lại lấy địa chỉ của Chi nhánh cửa hàng số 1, nếu khách bấm vào thẻ chi nhánh thì địa chỉ giao hàng nhà riêng bị gán thành tên Chi nhánh, và khi chạm lên bản đồ chỉ trả về chuỗi tọa độ số `"15.9689, 108.2608"` thay vì tên đường/phường/quận thực tế (thiếu Reverse Geocoding & ô nhập bổ sung Số nhà/Tòa nhà).
17. **Nút `"Xem / Mở mã QR thanh toán"` trong cả `OrderHistoryScreen` (dòng 441) lẫn `OrderDetailScreen` (dòng 460) hiện ra cả khi đơn Đã Hủy, Đã Giao hoặc Đã Thanh Toán, và `VietQrPaymentDialog` (dòng 66) gán cứng tiêu đề:**
    - Cả 2 màn hình đều chỉ kiểm tra `if (order.paymentMethod == 'VIETQR')` mà không kiểm tra `status` và `paymentStatus`, khiến đơn đã hủy hoặc đã trả tiền vẫn hiện nút bắt quét QR.
    - `VietQrPaymentDialog` luôn hiện tiêu đề `"ĐẶT HÀNG THÀNH CÔNG!"` và nút `"XEM ĐƠN HÀNG CỦA TÔI"` ngay cả khi mở lại từ trong `OrderDetailScreen`.
18. **`OrderDetailScreen` (dòng 23) chỉ tìm đơn trong `orderProvider.userOrders`, làm đơ UI khi Admin mở xem và duyệt đơn của khách khác:**
    - Dòng 23 viết `orderProvider.userOrders.firstWhere(...)` mà không tìm trong `orderProvider.allOrders`. Khi Admin mở `OrderDetailScreen` từ `ShopAdminScreen` để duyệt đơn hoặc xác nhận thanh toán cho khách B, màn hình không bao giờ cập nhật trạng thái mới theo thời gian thực!
    - Ngoài ra nút cuối trang `OrderDetailScreen` (dòng 70) luôn mở `ChatScreen` của khách thay vì mở `AdminChatDetailScreen` tới `order.userId` khi người đang xem là Admin.
19. **Đơn hàng 1 chiều, thiếu Sửa đơn, Hủy đơn, Đổi/Trả hàng, Hoàn tiền & Mua lại:**
    - Khách không thể **Sửa địa chỉ/SĐT** khi đơn đang `Pending`, không thể **Hủy đơn (`Cancelled`)**, không thể **Yêu cầu Đổi/Trả hàng (`ReturnRequested` $\rightarrow$ `Returned`)** khi mặc không vừa/hàng lỗi, và không có nút **Mua lại (`Re-order`)**.
    - Timeline đơn hàng thiếu mốc thời gian của các bước `deliveringAt`, `deliveredAt`, `cancelledAt`, `returnedAt`.
20. **Đánh giá sản phẩm (`Reviews`) không xác thực người mua & dùng `FieldValue.arrayUnion` sai cách (`lib/services/firestore_service.dart` dòng 122):** Ai chưa mua hàng cũng spam được đánh giá; dùng `arrayUnion` với `createdAt: DateTime.now()` khiến không thể cập nhật hay chống trùng đánh giá của cùng 1 đơn hàng.
21. **Thiếu Unread Badge trong Chat & lỗi dò chuỗi Notification:**
    - Hộp thư Admin không hiển thị số tin nhắn chưa đọc (`unreadByAdmin`); Khách không nhận được thông báo khi Shop trả lời tin nhắn.
    - `NotificationScreen` dò đơn hàng bằng `String.contains(shortId)` trên mảng `userOrders` chưa được tải khi vừa mở app.
22. **Khiếm khuyết ở Phân hệ Admin (`lib/screens/admin/`):**
    - `ShopAdminScreen`: Thẻ duyệt đơn không hiện danh sách sản phẩm/size/màu, không bấm vào xem `OrderDetailScreen` được; Dashboard không có cảnh báo hàng sắp hết kho (`Low Stock Alert`) hay Top bán chạy.
    - `AdminBranchManagementScreen`: Thiếu chức năng **Sửa chi nhánh (`updateBranch`)** và bắt Admin tự gõ tọa độ Vĩ độ/Kinh độ bằng tay thay vì chọn trên Bản đồ.
23. **Thiếu Quên mật khẩu & Đổi mật khẩu an toàn (`Re-authentication`):** `LoginScreen` thiếu Quên mật khẩu; `ProfileScreen` thiếu Đổi mật khẩu có xác thực lại (`reauthenticateWithCredential`).

---

## II. NÂNG CẤP THIẾT KẾ CƠ SỞ DỮ LIỆU (7 FIRESTORE COLLECTIONS + `branches`)

Giữ nguyên cấu trúc **7 Collections bắt buộc** (`users`, `categories`, `products`, `carts`, `orders`, `notifications`, `chats`) và collection `branches` theo đúng Rulebook của dự án, đồng thời chuẩn hóa Schema bên trong từng Document (mọi trường mới đều có fallback mặc định an toàn trong `fromMap()`):

### 1. Collection `users` (`lib/models/user_model.dart`)
| Trường (Field) | Kiểu dữ liệu | Ý nghĩa nghiệp vụ chuẩn doanh nghiệp |
| :--- | :--- | :--- |
| `uid`, `email`, `fullName`, `phone`, `avatarUrl`, `defaultAddress`, `role`, `createdAt` | Giữ nguyên | Hồ sơ người dùng & phân quyền (`customer` / `admin`). Hiển thị và cho phép đổi `avatarUrl` thật trên UI. |
| **`savedAddresses`** | `List<Map<String, dynamic>>` | **Sổ địa chỉ nhận hàng** (gồm `id`, `label` [Nhà riêng/Công ty], `recipientName`, `phone`, `address`, `isDefault`). Giúp khách chọn 1 chạm khi Checkout. |
| **`wishlistProductIds`** | `List<String>` | Danh sách ID sản phẩm yêu thích (Wishlist) đồng bộ Cloud xuyên thiết bị. |
| **`bodyMeasurements`** | `Map<String, num>?` | Lưu chiều cao (`heightCm`) & cân nặng (`weightKg`) của khách để tự động gợi ý Size quần áo trên mọi sản phẩm. |

### 2. Collection `categories` (`lib/models/category_model.dart`)
| Trường (Field) | Kiểu dữ liệu | Ý nghĩa nghiệp vụ chuẩn doanh nghiệp |
| :--- | :--- | :--- |
| `id`, `name`, `iconUrl` | Giữ nguyên | Danh mục sản phẩm. Kết nối động 100% từ Firestore lên Trang chủ, Bộ lọc và trang Quản trị Admin (hỗ trợ Admin Thêm / Sửa / Xóa danh mục). |

### 3. Collection `products` (`lib/models/product_model.dart`)
| Trường (Field) | Kiểu dữ liệu | Ý nghĩa nghiệp vụ chuẩn doanh nghiệp |
| :--- | :--- | :--- |
| `id`, `name`, `categoryId`, `price`, `description`, `imageUrls`, `sizes`, `colors`, `rating` | Giữ nguyên | Thông tin sản phẩm cốt lõi (`price` là giá bán thực tế hiện tại). |
| **`originalPrice`** | `num?` | **Giá niêm yết (Giá gốc trước khuyến mãi)**. Nếu `originalPrice > price` $\rightarrow$ tự động tính và hiển thị Badge **`-X%`** cùng giá gốc gạch ngang. |
| **`stock`** | `int` | **Tổng tồn kho khả dụng** của sản phẩm (bằng tổng tồn kho của tất cả biến thể SKU). |
| **`variantStock`** | `Map<String, int>` | **Tồn kho chi tiết theo từng SKU (`"${size}_${color}"`)**, ví dụ: `{"S_Trắng": 10, "M_Đen": 15, "L_Đen": 0}`. Khóa chính xác từng Size/Màu hết hàng và trừ/hoàn kho chuẩn xác tới từng biến thể. |
| **`soldCount`** | `int` | **Số lượng đã bán thực tế**. Tăng khi đặt đơn, giảm khi hủy/hoàn đơn. Dùng để xếp hạng **"Bán chạy nhất (Best Seller)"**. |
| **`isActive`** | `bool` | Trạng thái **Đang kinh doanh (`true`) / Ngừng kinh doanh (`false`)**. Chỉ hiển thị sản phẩm `isActive == true` trên `filteredProducts` của Khách hàng; hiển thị toàn bộ trên `allProducts` của Admin. |
| **`reviews`** | `List<ReviewModel>` | Nằm trong `lib/models/product_model.dart`. Mỗi `ReviewModel` bổ sung: `userId`, `variantInfo` (VD: `"Phân loại: Size L, Màu Đen"`), `isVerifiedPurchase` (`true`), `orderId`. |

### 4. Collection `carts` (`lib/models/cart_item_model.dart`)
| Trường (Field) | Kiểu dữ liệu | Ý nghĩa nghiệp vụ chuẩn doanh nghiệp |
| :--- | :--- | :--- |
| `items` (`cartItemId`, `productId`, `productName`, `imageUrl`, `price`, `size`, `color`, `quantity`) | Giữ nguyên | Danh sách sản phẩm trong giỏ (`cartItemId = "${productId}_${size}_${color}"`). |
| **`isSelected`** | `bool` | Trạng thái **được tích chọn để thanh toán** trong giỏ hàng (Mặc định `true`). Cho phép khách để nhiều món trong giỏ nhưng chỉ tích chọn một số món để đặt mua. |

### 5. Collection `orders` (`lib/models/order_model.dart`)
| Trường (Field) | Kiểu dữ liệu | Ý nghĩa nghiệp vụ chuẩn doanh nghiệp |
| :--- | :--- | :--- |
| `orderId`, `userId`, `userName`, `phone`, `shippingAddress`, `items`, `subtotal`, `voucherCode`, `discountAmount`, `totalPrice`, `paymentMethod`, `createdAt` | Giữ nguyên | Thông tin đơn hàng cốt lõi. |
| **`shippingFee`** | `num` | Phí vận chuyển gốc (`30.000đ` cho Giao tận nơi dưới `499.000đ`; `0đ` nếu đơn $\ge 499.000\text{đ}$ hoặc Nhận tại cửa hàng). |
| **`productDiscount`** | `num` | Tiền giảm giá trực tiếp trên tiền hàng (từ mã `SALE10`, `UNIQLO50K`, `VIP100K`). |
| **`shippingDiscount`** | `num` | Tiền giảm giá phí vận chuyển (từ mã `FREESHIP`, tối đa bằng `shippingFee`). Tổng `discountAmount = productDiscount + shippingDiscount`. |
| **`deliveryMethod`** | `String` | `"DELIVERY"` (Giao tận nơi) hoặc `"PICKUP"` (Nhận tại cửa hàng - Click & Collect). |
| **`pickupBranchName`** | `String` | Tên & địa chỉ chi nhánh nhận hàng (khi `deliveryMethod == "PICKUP"`). |
| **`note`** | `String` | Ghi chú của khách hàng cho đơn hàng (VD: *"Giao giờ hành chính, gọi trước khi giao"*). |
| **`status`** | `String` | Máy trạng thái vận hành 6 bước chuẩn doanh nghiệp:<br>• `"Pending"` (Chờ xác nhận)<br>• `"Delivering"` (Đang giao hàng)<br>• `"Delivered"` (Đã giao thành công)<br>• **`"Cancelled"` (Đã hủy)**<br>• **`"ReturnRequested"` (Yêu cầu Đổi/Trả hàng)**<br>• **`"Returned"` (Đã hoàn trả & hoàn kho)** |
| **`paymentStatus`** | `String` | Máy trạng thái dòng tiền độc lập:<br>• `"Unpaid"` (Chưa thanh toán)<br>• `"PaymentSubmitted"` (Khách báo đã chuyển khoản VietQR - Chờ đối soát)<br>• `"Paid"` (Đã thu tiền / Đã đối soát thành công)<br>• **`"Refunded"` (Đã hoàn tiền cho khách khi đơn `Paid` bị Hủy hoặc Hoàn trả)** |
| **`cancelReason` / `cancelledBy`** | `String` | Lý do hủy đơn & người thực hiện hủy (`"customer"` hoặc `"admin"`). |
| **`returnReason`** | `String` | Lý do khách yêu cầu Đổi/Trả hàng sau khi nhận. |
| **`deliveringAt`, `deliveredAt`, `cancelledAt`, `returnedAt`** | `DateTime?` | Các mốc thời gian thực tế của từng chặng để hiển thị trên **Order Tracking Timeline**. |

### 6. Collection `notifications` (`lib/models/notification_model.dart`)
| Trường (Field) | Kiểu dữ liệu | Ý nghĩa nghiệp vụ chuẩn doanh nghiệp |
| :--- | :--- | :--- |
| `id`, `userId`, `title`, `body`, `isRead`, `createdAt` | Giữ nguyên | Thông báo thời gian thực theo từng người dùng. |
| **`orderId`** | `String` | Khóa ngoại liên kết trực tiếp tới đơn hàng (Deep-linking 100% chính xác). |
| **`type`** | `String` | Phân loại: `"order"` (Cập nhật đơn hàng), `"payment"` (Xác nhận thanh toán), `"chat"` (Shop phản hồi tin nhắn tư vấn). |

### 7. Collection `chats` & Sub-collection `messages` (`lib/models/message_model.dart`)
| Trường (Field) | Kiểu dữ liệu | Ý nghĩa nghiệp vụ chuẩn doanh nghiệp |
| :--- | :--- | :--- |
| Document `chats/{customerId}` | Mở rộng | Bổ sung **`unreadByAdmin`** (`int` - số tin nhắn khách gửi mà Admin chưa đọc) và **`unreadByCustomer`** (`int` - số tin nhắn Admin trả lời mà khách chưa đọc). |
| Sub-collection `messages` | Mở rộng | Bổ sung **`orderId`** (`String`) và **`productName`** (`String`) để hiển thị **Thẻ đính kèm Đơn hàng / Sản phẩm** trực quan ngay trong bong bóng chat. |

---

## III. ĐẶC TẢ CHI TIẾT 12 PHÂN HỆ NÂNG CẤP LOGIC & NGHIỆP VỤ DOANH NGHIỆP

---

### 📦 PHÂN HỆ 1: QUẢN LÝ TỒN KHO ĐA BIẾN THỂ (SKU VARIANT INVENTORY) & ĐỊNH GIÁ THỜI TRANG
**File tác động:** `lib/models/product_model.dart`, `lib/core/constants/mock_data.dart`, `lib/services/firestore_service.dart`, `lib/providers/product_provider.dart`, `lib/screens/home/product_detail_screen.dart`, `lib/screens/admin/admin_product_form_screen.dart`

1. **Tồn kho theo từng SKU (`Size + Màu`) và Tồn kho tổng:**
   - Mỗi sản phẩm lưu `variantStock` (VD: `{"S_Trắng": 12, "M_Trắng": 8, "L_Đen": 0}`). Tổng `stock` tự động bằng tổng các biến thể (hoặc dùng `stock` chung nếu sản phẩm không chia biến thể).
   - Trên `ProductDetailScreen`:
     - Khi khách chọn `Size` và `Màu`, hiển thị chính xác: **"Kho còn: 8 sản phẩm (Size M - Màu Trắng)"** kèm **"Đã bán: 24"**.
     - **Kẹp số lượng thông minh khi chuyển đổi Size/Màu:** Nếu khách đang chọn `_quantity = 5` ở phân loại còn 10 cái, sau đó bấm sang phân loại chỉ còn `2` cái, tự động hạ `_quantity` về `2` (`min(_quantity, currentVariantStock)`). Khi bấm `"THÊM VÀO GIỎ"`, kiểm tra tổng `existingQtyInCart + _quantity <= currentVariantStock`, nếu vượt quá thì cảnh báo rõ ràng!
     - Nếu một cặp `Size + Màu` có tồn kho `= 0`, hiển thị nhãn **"Hết hàng phân loại này"**, làm mờ chip và khóa nút Thêm vào giỏ / Mua ngay.
2. **Trừ kho & Hoàn kho tự động bằng Transaction/Batch (`FirestoreService`):**
   - **Khi Đặt hàng (`createOrder`):** Kiểm tra tồn kho thực tế trên Firestore; trừ `stock` và `variantStock["${size}_${color}"]`, đồng thời cộng `soldCount`.
   - **Khi Hủy đơn (`cancelOrder`) hoặc Duyệt Hoàn trả (`approveReturnOrder`):** Cộng trả lại `stock`, `variantStock["${size}_${color}"]` và trừ `soldCount`.
3. **Giá gốc (`originalPrice`) & Huy hiệu Giảm giá (`% OFF`):**
   - Hỗ trợ nhập `originalPrice` trong `AdminProductFormScreen` và cập nhật toàn bộ 8 sản phẩm trong `mock_data.dart`.
   - Hiển thị giá gốc gạch ngang và badge đỏ **`-20%`** trên cả thẻ sản phẩm ngoài trang chủ (`ProductListScreen`) lẫn trang chi tiết (`ProductDetailScreen`).
4. **Đồng bộ Sản phẩm Real-time (`streamProducts`) & Sửa hàm `seedInitialData()`:**
   - Kết nối `FirestoreService.streamProducts()` vào `ProductProvider` để tự động cập nhật giá, tồn kho, đánh giá theo thời gian thực.
   - Sửa `FirestoreService.seedInitialData()` dùng `SetOptions(merge: true)` để khi Admin bấm **"BẤM NẠP SEED DATA NGAY"** sẽ luôn cập nhật/ghi đè chuẩn xác dữ liệu mẫu mới lên Firestore.

---

### 📏 PHÂN HỆ 2: TRỢ LÝ CHỌN SIZE THÔNG MINH (SMART SIZE GUIDE & FIT FINDER)
**File tác động:** `lib/screens/home/product_detail_screen.dart`, `lib/models/user_model.dart`, `lib/providers/auth_provider.dart`

1. **Bảng Quy đổi Kích cỡ & Gợi ý Size tự động (Chuẩn Uniqlo / Coolmate):**
   - Nâng cấp hàm `_showSizeChartModal` trên `ProductDetailScreen` thành BottomSheet chuyên nghiệp gồm 2 phần:
     - **Phần 1 — Công cụ Gợi ý Size tự động theo số đo:** Cho phép kéo thanh trượt chọn **Chiều cao (`145cm - 195cm`)** và **Cân nặng (`40kg - 100kg`)** cùng kiểu dáng mong muốn (*Mặc ôm vừa Regular / Mặc rộng Oversize*). Thuật toán tự động tính toán và đề xuất: **"Gợi ý chuẩn nhất cho bạn: Size L"** kèm nút **"Chọn ngay Size L & Lưu số đo"**.
     - **Phần 2 — Bảng thông số kích thước chuẩn:** Bảng quy chuẩn chi tiết cho `S`, `M`, `L`, `XL`, `FreeSize`.

---

### 🛒 PHÂN HỆ 3: ĐỒNG BỘ GIỎ HÀNG CLOUD 2 CHIỀU, CHỌN LỌC THANH TOÁN, HỢP NHẤT PHÂN LOẠI & LUỒNG "MUA NGAY" ĐỘC LẬP
**File tác động:** `lib/main.dart`, `lib/screens/main_nav_screen.dart`, `lib/services/firestore_service.dart`, `lib/providers/cart_provider.dart`, `lib/models/cart_item_model.dart`, `lib/screens/cart/cart_screen.dart`, `lib/screens/cart/checkout_screen.dart`, `lib/screens/home/product_detail_screen.dart`

1. **Khôi phục đồng bộ Cloud Firestore `carts/{uid}`, Chống giật ngược số lượng & Chuẩn hóa Điều hướng Phiên (`AuthGate`):**
   - **Bảo vệ `Consumer<AuthProvider>` gốc tuyệt đối:** Trong `lib/main.dart`, gắn `MainNavScreen(key: ValueKey(auth.userId))`. Cung cấp phương thức `MainNavScreen.switchToTab(BuildContext context, int tabIndex)` (thực hiện `Navigator.of(context).popUntil((route) => route.isFirst)` và đổi `_currentIndex = tabIndex`). Loại bỏ hoàn toàn việc gọi `Navigator.pushReplacement` / `Navigator.pushAndRemoveUntil` ở `LoginScreen`, `RegisterScreen`, `ProfileScreen`, và `CheckoutScreen` (dòng 106 & 150)!
   - **Xóa bỏ lệnh `await clearCart(order.userId)` khỏi `FirestoreService.createOrder()` (dòng 200):** Tuyệt đối không để `FirestoreService.createOrder()` tự ý xóa toàn bộ document `carts/{userId}` trên Cloud.
   - **Chống Race Condition trong `CartProvider.loadUserCart(uid)`:**
     - Gán `_userId = uid`, hủy subscription cũ. Ở snapshot đầu tiên từ Firestore, nếu Cloud trống mà trên RAM đang có hàng thì đẩy lên Cloud; khi người dùng thao tác tăng/giảm số lượng cục bộ, kiểm soát cờ đồng bộ để snapshot cũ không làm số lượng trên UI bị giật ngược.
     - Khi Đăng xuất (`ProfileScreen`): Gọi `unloadCartOnLogout()` chỉ xóa RAM trên máy, **giữ nguyên 100% giỏ hàng trên Cloud Firestore** cho lần đăng nhập sau; đồng thời gọi `clearSession()` cho `OrderProvider`, `NotificationProvider`, `ChatProvider`.
2. **Giỏ hàng Thông minh, Đối chiếu Giá/Tồn kho Live & Hợp nhất khi Đổi Size/Màu (`updateItemVariant`):**
   - **Checkbox chọn từng sản phẩm & "Chọn tất cả":** Khách tích chọn những món muốn mua hôm nay. `subtotal` trong giỏ chỉ tính trên các món được tích chọn (`selectedItems`).
   - **Đồng bộ Giá hiện hành & Kiểm tra Tồn kho / Ngừng kinh doanh ngay tại Giỏ hàng:**
     - Đối chiếu từng món trong giỏ với `ProductProvider.allProducts`: Tự động cập nhật `price` nếu sản phẩm vừa được giảm giá; nếu phân loại trong giỏ đã hết hàng (`variantStock == 0`) hoặc sản phẩm ngừng bán (`isActive == false`), hiển thị nhãn **"Hết hàng / Ngừng bán"**, tự động bỏ tích chọn (`isSelected = false`) và chặn thanh toán món đó cho tới khi khách đổi sang phân loại khác còn hàng.
   - **Đổi nhanh Size / Màu ngay trong Giỏ hàng (Chống trùng khóa `cartItemId`):**
     - Khi khách chạm vào nhãn `"Size: M | Màu: Trắng"` trên một dòng trong giỏ để đổi sang `newSize`, `newColor`:
     - Hàm `updateItemVariant(oldCartItemId, newSize, newColor, maxVariantStock)` tạo khóa mới `newCartItemId = "${productId}_${newSize}_${newColor}"`.
     - **Nếu `newCartItemId` đã tồn tại ở một dòng khác trong giỏ hàng:** Tự động **cộng dồn `quantity` của dòng cũ vào dòng đã tồn tại** (kẹp trần `min(existingQty + oldQty, maxVariantStock)`), sau đó **xóa dòng cũ đi** để tuyệt đối không sinh ra 2 dòng trùng `cartItemId`!
   - **Thanh tiến trình Miễn phí Vận chuyển (Free Shipping Progress Bar):** Đầu màn hình giỏ hàng hiển thị thanh tiến trình trực quan (*"🚚 Mua thêm X đ để được MIỄN PHÍ VẬN CHUYỂN"* hoặc *"🎉 Đã đủ điều kiện MIỄN PHÍ VẬN CHUYỂN"*).
3. **Tách biệt hoàn toàn luồng "Mua ngay" (`Buy Now`) và Tính toán Tổng tiền theo đúng `checkoutItems`:**
   - Trên `ProductDetailScreen`, dưới đáy màn hình có 2 nút song song: **"THÊM VÀO GIỎ"** và **"MUA NGAY"**.
   - Khi bấm **"MUA NGAY"**: Truyền trực tiếp `List<CartItemModel> directBuyItems` sang `CheckoutScreen(directBuyItems: [item])`.
   - **Quy tắc bắt buộc tại `CheckoutScreen` (Tránh bẫy lấy nhầm tiền của giỏ hàng):**
     - Màn hình `CheckoutScreen` xác định danh sách thanh toán thực tế: `final checkoutItems = widget.directBuyItems ?? cartProvider.selectedItems;`.
     - Toàn bộ các chỉ số `checkoutSubtotal`, `shippingFee`, `productDiscount`, `shippingDiscount` và `finalTotalPrice` tại `CheckoutScreen` **bắt buộc phải được tính toán dựa trên `checkoutItems`** (thông qua hàm `cartProvider.calculateOrderPricing(items: checkoutItems, deliveryMethod: _deliveryMethod, voucherCode: _appliedVoucher)`), tuyệt đối không đọc nhầm `cartProvider.subtotal` của các món đồ cũ trong giỏ!
     - Khi đặt đơn thành công:
       - Nếu `widget.directBuyItems != null` (luồng Mua ngay): **Giữ nguyên 100% các món đang nằm trong `CartProvider`**, không xóa giỏ hàng.
       - Nếu `widget.directBuyItems == null` (luồng Giỏ hàng): Gọi `cartProvider.removePurchasedItems()` chỉ xóa đúng những món đã tích chọn (`selectedItems`), giữ nguyên các món chưa tích chọn trên cả RAM và Firestore.

---

### 🎟️ PHÂN HỆ 4: CÔNG CỤ TÍNH PHÍ VẬN CHUYỂN & KHO VOUCHER THÔNG MINH (CHỐNG BẪY `FREESHIP -0đ`)
**File tác động:** `lib/core/constants/app_constants.dart`, `lib/providers/cart_provider.dart`, `lib/screens/cart/cart_screen.dart`, `lib/screens/cart/checkout_screen.dart`, `lib/models/order_model.dart`

1. **Quy tắc Phí Vận chuyển (`shippingFee`) minh bạch:**
   - **Nhận tại cửa hàng (`PICKUP` - Click & Collect):** Miễn phí 100% (`shippingFee = 0đ`) với mọi giá trị đơn hàng.
   - **Giao hàng tận nơi (`DELIVERY`):**
     - Đơn hàng có `subtotal >= 499.000đ`: Miễn phí vận chuyển (`shippingFee = 0đ`).
     - Đơn hàng có `subtotal < 499.000đ`: Phí vận chuyển tiêu chuẩn `shippingFee = 30.000đ`.
2. **Hệ thống Kho Voucher chuẩn hóa trong `AppConstants.vouchers` & Chặn bẫy `FREESHIP (-0đ)`:**
   - Danh mục Voucher trong **BottomSheet Kho Voucher**:
     - `FREESHIP`: Miễn phí vận chuyển tối đa `30.000đ` cho đơn từ `199.000đ` (Áp dụng cho đơn đang có `shippingFee > 0`, giảm `shippingDiscount = min(shippingFee, 30000)`).
     - `SALE10`: Giảm `10%` tiền hàng (tối đa `50.000đ`) cho đơn từ `200.000đ`.
     - `UNIQLO50K`: Giảm trực tiếp `50.000đ` tiền hàng cho đơn từ `499.000đ`.
     - `VIP100K`: Giảm trực tiếp `100.000đ` tiền hàng cho đơn từ `999.000đ`.
   - **Cơ chế Chống bẫy `FREESHIP (-0đ)`:**
     - Nếu đơn hàng hiện tại đã được miễn phí vận chuyển (`shippingFee == 0` do `subtotal >= 499.000đ` hoặc khách chọn Nhận tại cửa hàng `PICKUP`), khi khách bấm chọn hoặc nhập mã `FREESHIP`:
       - Hệ thống **chặn áp dụng mã `FREESHIP` vô nghĩa** và hiển thị thông báo thông minh: *"🎉 Đơn hàng của bạn đã được Miễn phí vận chuyển (0đ)! Hãy chọn mã giảm giá tiền hàng (SALE10 / UNIQLO50K) để được giảm thêm tiền mặt."*
     - Tương tự, nếu ở Giỏ hàng khách đang áp mã `FREESHIP` (khi `subtotal = 300.000đ`), nhưng sang `CheckoutScreen` khách chuyển sang tab **"Nhận tại cửa hàng (`PICKUP`)"** làm `shippingFee` về `0đ`, hệ thống sẽ tự động gỡ mã `FREESHIP` và gợi ý chuyển sang mã `SALE10` để trên hóa đơn không bao giờ xuất hiện dòng `"Voucher: FREESHIP (-0đ)"`!
3. **Bảng kê Chi tiết Thanh toán (Financial Breakdown) tại `CheckoutScreen` và `OrderDetailScreen`:**
   - Hiển thị rõ 5 dòng chuẩn hóa đơn thương mại điện tử:
     1. Tổng tiền hàng (`subtotal`)
     2. Phí vận chuyển (`+shippingFee` hoặc `"Miễn phí"`)
     3. Giảm giá vận chuyển (`-shippingDiscount`, nếu `> 0`)
     4. Voucher giảm giá sản phẩm (`-productDiscount`, nếu `> 0`)
     5. **Tổng thanh toán (`totalPrice`)** = `(subtotal - productDiscount) + (shippingFee - shippingDiscount)`.

---

### 🗺️ PHÂN HỆ 5: GIAO NHẬN ĐA KÊNH (HOME DELIVERY VS. CLICK & COLLECT), SỔ ĐỊA CHỈ & REVERSE GEOCODING BẢN ĐỒ
**File tác động:** `pubspec.yaml`, `lib/screens/cart/checkout_screen.dart`, `lib/screens/map/store_map_screen.dart`, `lib/screens/profile/edit_profile_screen.dart`

1. **Lựa chọn Hình thức Nhận hàng tại `CheckoutScreen`:**
   - **Tùy chọn 1: Giao hàng tận nơi (`DELIVERY`)**
     - Cho phép chọn nhanh từ **Sổ địa chỉ đã lưu (`savedAddresses`)**, nhập mới, hoặc bấm **"Chọn trên Bản đồ"**.
     - Có ô nhập **Ghi chú giao hàng (`note`)** (VD: *"Giao giờ hành chính, gửi bảo vệ"*).
   - **Tùy chọn 2: Nhận tại cửa hàng (`PICKUP` - Miễn phí vận chuyển)**
     - Hiển thị danh sách các Chi nhánh cửa hàng từ collection `branches` kèm địa chỉ, hotline và khoảng cách. Khách chọn chi nhánh nào sẽ lưu `pickupBranchName` vào đơn hàng.
2. **OpenStreetMap Nominatim Reverse Geocoding thực tế & Chống gán nhầm địa chỉ Chi nhánh (`StoreMapScreen`):**
   - Khi ở chế độ `isPickerMode: true`, khởi tạo tâm bản đồ tại vị trí người dùng (hoặc vị trí trung tâm mặc định), **tuyệt đối không gán sẵn tên Chi nhánh cửa hàng vào `_selectedAddressName`**.
   - Mỗi khi khách chạm ghim điểm trên bản đồ hoặc bấm lấy GPS hiện tại, gọi HTTP GET tới **OpenStreetMap Nominatim Reverse Geocoding API** (`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=...&lon=...&accept-language=vi`) kèm HTTP Header bắt buộc `'User-Agent': 'FashionStoreAppPRM393/1.0'` để tự động phân giải ra **Số nhà, Tên đường, Phường/Xã, Quận/Huyện, Tỉnh/Thành phố** thực tế.
   - Trong lúc đang tải Reverse Geocoding (`_isReverseGeocoding == true`), khóa tạm thời nút xác nhận vị trí và cung cấp thêm ô nhập bổ sung *"Số nhà / Tầng / Tòa nhà"* ngay trên thẻ đáy bản đồ để khách tinh chỉnh trước khi bấm xác nhận.
   - Hiển thị khoảng cách (`km`) từ vị trí GPS của khách tới từng chi nhánh cửa hàng và sắp xếp chi nhánh gần nhất lên đầu.

---

### 🔄 PHÂN HỆ 6: MÁY TRẠNG THÁI ĐƠN HÀNG TOÀN DIỆN (SỬA ĐƠN, HỦY ĐƠN, ĐỐI SOÁT VIETQR, ĐỔI/TRẢ HÀNG, HOÀN TIỀN `REFUNDED` & MUA LẠI AN TOÀN)
**File tác động:** `lib/models/order_model.dart`, `lib/providers/order_provider.dart`, `lib/services/firestore_service.dart`, `lib/screens/orders/order_history_screen.dart`, `lib/screens/orders/order_detail_screen.dart`, `lib/screens/cart/widgets/vietqr_dialog.dart`

1. **Tách biệt Trạng thái Thanh toán (`paymentStatus`), Khóa nút VietQR ở cả 2 màn hình & Tự động Hoàn tiền (`Refunded`):**
   - Khi tạo đơn `VIETQR`: `paymentStatus = 'Unpaid'`.
   - Chuẩn hóa `VietQrPaymentDialog` (`lib/screens/cart/widgets/vietqr_dialog.dart`):
     - Nhận tham số `isFromCheckout` (`bool`): Nếu mở từ `CheckoutScreen` thì hiển thị tiêu đề `"ĐẶT HÀNG THÀNH CÔNG!"`; nếu mở lại từ `OrderHistoryScreen` / `OrderDetailScreen` thì hiển thị tiêu đề `"THANH TOÁN ĐƠN HÀNG VIETQR"`.
     - Nút **"TÔI ĐÃ CHUYỂN KHOẢN"** $\rightarrow$ Cập nhật `paymentStatus = 'PaymentSubmitted'` (Khách báo đã CK, chờ Shop đối soát) và gửi thông báo.
     - Nút **"THANH TOÁN SAU / ĐÓNG"** $\rightarrow$ Giữ `paymentStatus = 'Unpaid'`.
   - **Khóa chặt điều kiện hiển thị nút `"MỞ / XEM MÃ QR THANH TOÁN"` tại CẢ `OrderHistoryScreen` (dòng 441) LẪN `OrderDetailScreen` (dòng 460):**
     - Chỉ hiển thị nút mở mã QR khi `order.paymentMethod == 'VIETQR' && order.status == 'Pending' && order.paymentStatus == 'Unpaid'`.
     - Nếu `paymentStatus == 'PaymentSubmitted'`: Hiển thị nhãn **"⏳ Đã báo chuyển khoản — Đang chờ Shop đối soát"**.
     - Nếu `paymentStatus == 'Paid'`: Hiển thị nhãn **"✅ Đã thanh toán thành công"** (khóa hoàn toàn nút mở QR).
     - Nếu `paymentStatus == 'Refunded'`: Hiển thị nhãn **"💸 Đã hoàn tiền cho khách"**.
   - **Quy tắc Tự động Chuyển `paymentStatus = 'Refunded'` khi Hủy hoặc Hoàn trả:**
     - Khi thực hiện Hủy đơn (`cancelOrder` $\rightarrow$ `status = 'Cancelled'`) hoặc khi Admin duyệt Hoàn trả hàng (`approveReturnOrder` $\rightarrow$ `status = 'Returned'`):
       - Nếu đơn hàng đang có `paymentStatus == 'Paid'` $\rightarrow$ **Tự động chuyển `paymentStatus = 'Refunded'`**.
       - Nếu đơn hàng đang có `paymentStatus == 'PaymentSubmitted'` $\rightarrow$ Đưa về `'Unpaid'`.
2. **Sửa lỗi `OrderDetailScreen` (dòng 23 & 70) để hoạt động Real-time cho cả Khách hàng lẫn Admin:**
   - Khi tra cứu đơn hàng live trong `OrderDetailScreen`, tìm trong cả `orderProvider.userOrders` **VÀ `orderProvider.allOrders`** để khi Admin mở xem đơn của khách khác và bấm duyệt đơn / xác nhận thu tiền VietQR / duyệt hoàn trả, giao diện `OrderDetailScreen` cập nhật tức thì!
   - Nút liên hệ ở cuối `OrderDetailScreen` (dòng 70): Nếu người đang xem là Khách (`!authProvider.isAdmin` hoặc `order.userId == authProvider.userId`) thì mở `ChatScreen` gửi kèm thẻ đơn hàng cho Shop; nếu người đang xem là Admin đang kiểm tra đơn của khách khác thì hiển thị **"NHẮN TIN CHO KHÁCH HÀNG NÀY"** và mở `AdminChatDetailScreen(customerId: order.userId, customerName: order.userName)`.
3. **Quyền của Khách hàng theo từng trạng thái đơn (`OrderDetailScreen` & `OrderHistoryScreen`):**
   - **Khi `status == 'Pending'` (Chờ xác nhận):**
     - **Đổi thông tin nhận hàng:** Nút **"Sửa địa chỉ / SĐT nhận hàng"** cho phép cập nhật lại `userName`, `phone`, `shippingAddress`, `note` ngay trên đơn hàng mà không cần hủy đơn.
     - **Hủy đơn hàng (`Cancelled`):** Nút **"Hủy đơn hàng"** kèm hộp thoại chọn lý do hủy $\rightarrow$ Tự động hoàn lại tồn kho SKU (`stock` & `variantStock`) ngay lập tức.
   - **Khi `status == 'Delivering'` (Đang giao hàng):**
     - Khách có thể bấm **"Đã nhận được hàng"** để xác nhận hoàn tất đơn (`Delivered`).
   - **Khi `status == 'Delivered'` (Đã giao thành công):**
     - Nút **"Đánh giá sản phẩm"** (Verified Purchase Review).
     - Nút **"Yêu cầu Đổi / Trả hàng (`ReturnRequested`)"**: Cho phép khách chọn lý do (*Mặc không vừa - Muốn đổi size, Sản phẩm lỗi/hư hỏng, Giao sai mẫu*) để gửi yêu cầu về cho Shop.
     - Nút **"Mua lại đơn này (`Re-order`)"**.
   - **Khi `status == 'Cancelled'` hoặc `'Returned'`:**
     - Hiển thị rõ lý do hủy / lý do hoàn trả, trạng thái hoàn tiền (`Refunded` nếu đã thanh toán), thời gian xử lý và nút **"Mua lại đơn này (`Re-order`)"**.
   - **Logic "Mua lại đơn này (`reOrder`)" an toàn:**
     - Khi khách bấm Mua lại từ đơn cũ, đối chiếu từng món trong `order.items` với `ProductProvider.allProducts` hiện tại: lấy **giá bán hiện hành (`product.price`)**, kiểm tra `product.isActive == true` và `variantStock > 0` (kẹp số lượng theo tồn kho thực tế), bỏ qua các món đã ngừng bán/hết hàng và thông báo rõ cho khách.
4. **Timeline Theo dõi Đơn hàng Đa mốc thời gian:**
   - Hiển thị đầy đủ dấu thời gian thực tế cho từng chặng: `Thời gian đặt đơn (createdAt)`, `Thời gian xuất kho giao hàng (deliveringAt)`, `Thời gian giao thành công (deliveredAt)`, hoặc `Thời gian hủy/hoàn đơn (cancelledAt / returnedAt)`.

---

### 🏷️ PHÂN HỆ 7: KẾT NỐI ĐỘNG COLLECTION `categories` & NÂNG CẤP TRANG CHỦ, YÊU THÍCH (WISHLIST)
**File tác động:** `lib/screens/home/product_list_screen.dart`, `lib/screens/home/product_detail_screen.dart`, `lib/screens/profile/profile_screen.dart`, `lib/providers/product_provider.dart`, `lib/providers/auth_provider.dart`

1. **Kích hoạt Collection `categories` sống 100% & Đồng bộ Bộ lọc `availableSizes`:**
   - Thay thế toàn bộ các mảng danh mục gõ cứng (`const _categories`) trong `AdminProductListScreen` và `AdminProductFormScreen` bằng danh sách lấy động từ `productProvider.categories` (Firestore collection `categories`), kèm cơ chế kiểm tra `effectiveCategoryId` an toàn để không bao giờ văng lỗi `DropdownButtonFormField AssertionError`.
   - Trong `ProductProvider.availableSizes`: Trả về đầy đủ `['S', 'M', 'L', 'XL', 'FreeSize']` (hoặc tổng hợp động từ `_products`) và chỉ lọc các sản phẩm đang kinh doanh (`p.isActive == true`) trong `filteredProducts` dành cho Khách hàng.
2. **Vá lỗ hổng Phân quyền & Sửa lỗi Trạng thái Rỗng trên Trang chủ (`ProductListScreen`):**
   - Phân biệt rõ:
     - **Kho dữ liệu Firestore trống (`allProducts.isEmpty`):** Chỉ hiển thị nút mở `ShopAdminScreen` nạp Seed Data nếu `authProvider.isAdmin == true` (Khách hàng thường tuyệt đối không được phép thấy hay mở trang Admin).
     - **Lọc / Tìm kiếm không khớp (`filteredProducts.isEmpty`):** Hiển thị giao diện *"Không tìm thấy sản phẩm nào phù hợp với bộ lọc"* kèm nút **"Xóa bộ lọc & Tìm lại"** (đồng thời gọi `_searchController.clear()` để xóa sạch chữ kẹt trong ô tìm kiếm).
   - Bấm vào **Banner Khuyến mãi đầu trang chủ** sẽ mở BottomSheet Chương trình Ưu đãi & Kho Voucher (cho phép lưu mã hoặc lọc ngay các sản phẩm Đang giảm giá).
3. **Sắp xếp, Lọc Sản phẩm & Hiển thị Nhãn Hết hàng ngay trên Thẻ Sản phẩm:**
   - `"Phổ biến / Bán chạy"` (`popular`): Sắp xếp theo `soldCount` giảm dần (kết hợp `rating`).
   - `"Giá thấp đến cao"` (`price_asc`), `"Giá cao đến thấp"` (`price_desc`), và lọc nhanh `"Đang giảm giá"`.
   - Trên mỗi thẻ sản phẩm ở Trang chủ (`ProductListScreen`): Hiển thị rõ huy hiệu **`-X%`**, giá gốc gạch ngang (`originalPrice`), lượt bán (`Đã bán X`), nút thả tim Wishlist, và lớp phủ **"HẾT HÀNG"** nếu `product.stock == 0`.
4. **Hệ thống Yêu thích (Wishlist) & Sản phẩm Tương tự:**
   - Nút thả tim (Wishlist) ngay trên góc từng thẻ sản phẩm ở Trang chủ, trên AppBar của `ProductDetailScreen`, và màn hình xem **Danh sách Yêu thích** truy cập từ `ProfileScreen`.
   - Cuối trang `ProductDetailScreen` có mục **"SẢN PHẨM TƯƠNG TỰ / GỢI Ý PHỐI ĐỒ"** cùng danh mục.

---

### ⭐ PHÂN HỆ 8: ĐÁNH GIÁ SẢN PHẨM XÁC THỰC MUA HÀNG (`VERIFIED PURCHASE REVIEWS`)
**File tác động:** `lib/services/firestore_service.dart`, `lib/screens/home/product_detail_screen.dart`, `lib/screens/orders/order_detail_screen.dart`, `lib/models/product_model.dart`

1. **Chặn Spam Đánh giá & Sửa lỗi `FieldValue.arrayUnion` trong `FirestoreService.addProductReview`:**
   - Chỉ khách hàng có đơn hàng ở trạng thái `Delivered` chứa sản phẩm đó (kiểm tra trong `OrderProvider.userOrders`) mới được gửi đánh giá.
   - Trong Transaction của `FirestoreService.addProductReview`: Thay vì dùng `FieldValue.arrayUnion` (vốn luôn tạo trùng lặp do khác `createdAt`), kiểm tra trực tiếp trong mảng `currentReviews`: nếu người dùng (`userId`) đã đánh giá sản phẩm đó trong đơn hàng (`orderId`), cập nhật lại đánh giá đó trong mảng `updatedReviews` rồi ghi `'reviews': updatedReviews` cùng điểm trung bình `'rating': newRating` mới.
2. **Hiển thị Phân loại Đã mua & Thống kê Sao:**
   - Trên mỗi đánh giá hiển thị huy hiệu xanh **"✓ Đã mua hàng"** kèm dòng **"Phân loại hàng: Size L, Màu Đen"**.
   - Hiển thị biểu đồ phân bổ số sao (`5 sao`, `4 sao`, `3 sao`, `2 sao`, `1 sao`) phía trên danh sách đánh giá.

---

### 💬 PHÂN HỆ 9: HỆ THỐNG CSKH REAL-TIME — TÁCH 2 STREAM ĐỘC LẬP, UNREAD BADGE, ĐÍNH KÈM ĐƠN HÀNG & QUICK REPLIES
**File tác động:** `lib/providers/chat_provider.dart`, `lib/services/firestore_service.dart`, `lib/screens/chat/chat_screen.dart`, `lib/screens/admin/admin_chat_inbox_screen.dart`, `lib/screens/main_nav_screen.dart`

1. **Tách độc lập 2 Kênh Stream trong `ChatProvider` (Khắc phục xung đột với `IndexedStack`):**
   - Trong `ChatProvider`, quản lý tách biệt:
     - `messages` & `_customerMessagesSub`: Dành riêng cho `ChatScreen` của khách hàng đang đăng nhập.
     - `adminActiveMessages` & `_adminActiveMessagesSub`: Dành riêng cho `AdminChatDetailScreen` khi Admin mở xem và trả lời từng khách hàng.
   - Nhờ đó, việc Admin mở trả lời nhiều khách hàng khác nhau trong `AdminChatInboxScreen` tuyệt đối không làm đứt hay ghi đè luồng chat cá nhân ở `MainNavScreen`.
2. **Bộ đếm Tin nhắn Chưa đọc (`Unread Badge`):**
   - Lưu `unreadByAdmin` và `unreadByCustomer` trên document `chats/{customerId}` dựa theo `isFromAdmin = (senderId == 'shop_admin' || senderId == 'admin')` (hoạt động chính xác cả khi demo chuyển đổi qua lại vai trò Customer $\leftrightarrow$ Admin trên cùng 1 tài khoản).
   - Khi Khách gửi tin nhắn: Tăng `unreadByAdmin`, hiển thị **Huy hiệu số tin chưa đọc màu đỏ** ngay trên từng dòng hội thoại trong `AdminChatInboxScreen`.
   - Khi Admin trả lời: Tăng `unreadByCustomer`, tự động tạo Notification báo cho khách, và hiển thị **Badge đỏ trên tab "Tư Vấn"** ở thanh điều hướng dưới cùng (`MainNavScreen`).
   - Khi Khách chuyển sang Tab 3 (`Tư Vấn`) hoặc Admin mở phòng chat của khách: Tự động reset bộ đếm chưa đọc tương ứng về `0`.
3. **Đính kèm Thẻ Đơn hàng (`Order Card`) & Thẻ Sản phẩm (`Product Card`) vào Chat:**
   - Khi bấm **"Liên hệ Shop về đơn hàng này"** từ `OrderDetailScreen`, hoặc bấm **"Chat tư vấn mẫu này"** từ `ProductDetailScreen`, tự động đính kèm thẻ thông tin Đơn hàng / Sản phẩm vào khung chat để gửi cho tư vấn viên chỉ bằng 1 chạm.
   - Bổ sung thanh **Gợi ý câu hỏi nhanh (Quick Reply Chips)** cho cả Khách và Admin.

---

### 🔔 PHÂN HỆ 10: TRUNG TÂM THÔNG BÁO ĐA LUỒNG & ĐIỀU HƯỚNG SÂU (DEEP-LINKING)
**File tác động:** `lib/models/notification_model.dart`, `lib/providers/notification_provider.dart`, `lib/screens/notifications/notification_screen.dart`, `lib/screens/main_nav_screen.dart`

1. **Khởi tạo Sớm, Định dạng Tiền tệ Chuẩn & Deep-Linking 100% Chính xác:**
   - Lắng nghe `orderProvider.listenUserOrders(uid)` và `chatProvider` ngay khi vào `MainNavScreen`.
   - Chuẩn hóa nội dung thông báo trong `FirestoreService` (dùng `AppFormatters.formatVND(order.totalPrice)` và kiểm tra an toàn độ dài mã đơn trước khi cắt chuỗi `substring`).
   - Mỗi `NotificationModel` lưu trực tiếp `orderId` và `type` (`order`, `payment`, `chat`).
   - Khi bấm vào thông báo:
     - Nếu `type == 'order'` hoặc `'payment'`: Mở trực tiếp `OrderDetailScreen` của đúng `orderId` đó (nếu chưa có trong RAM thì tải trực tiếp từ Firestore bằng `getOrderById`).
     - Nếu `type == 'chat'`: Chuyển thẳng tới màn hình `ChatScreen` với Shop.
2. **Quản lý Thông báo Tiện lợi:**
   - Thêm nút **"Đọc tất cả" (`markAllAsRead`)** trên AppBar của `NotificationScreen` và bộ lọc nhanh (*Tất cả / Chưa đọc*).

---

### 📊 PHÂN HỆ 11: TRUNG TÂM ĐIỀU HÀNH ADMIN (BI DASHBOARD CHUẨN TÀI CHÍNH, DUYỆT ĐƠN CHI TIẾT, QUẢN LÝ KHO, DANH MỤC & CHI NHÁNH)
**File tác động:** `lib/screens/admin/shop_admin_screen.dart`, `lib/screens/admin/admin_product_list_screen.dart`, `lib/screens/admin/admin_product_form_screen.dart`, `lib/screens/admin/admin_branch_management_screen.dart`

1. **Nâng cấp Tab Tổng Quan Admin (`ShopAdminScreen` - Business Intelligence Dashboard):**
   - **Bộ lọc thời gian thống kê:** *Hôm nay / 7 ngày qua / 30 ngày qua / Toàn thời gian*.
   - **Công thức Chỉ số Tài chính Chính xác Tuyệt đối (Chống lệch số liệu khi Hoàn trả/Hủy):**
     - **Doanh thu thực thu (Net Revenue) & Giá trị đơn trung bình (AOV):** Chỉ tính tổng `totalPrice` của các đơn hàng có `status == 'Delivered'` (tuyệt đối không cộng các đơn đã chuyển sang `'Returned'` hay `'Cancelled'`).
     - Hiển thị tách biệt các thẻ KPI: Số đơn Chờ xử lý (`Pending`), Đang giao (`Delivering`), Hoàn tất (`Delivered`), Đã hủy (`Cancelled`), và Yêu cầu Đổi/Trả (`ReturnRequested` / `Returned`).
   - **Cảnh báo Tồn kho thấp / Hết hàng (Inventory Alert Widget):** Liệt kê ngay các sản phẩm có `stock <= 5` hoặc có biến thể bị hết hàng kèm nút **"Nhập kho nhanh (+Stock)"**.
   - **Bảng xếp hạng Top Sản phẩm Bán chạy nhất (Best Sellers):** Hiển thị Top 5 sản phẩm có lượt bán (`soldCount`) và doanh thu cao nhất.
2. **Nâng cấp Tab Duyệt Đơn Hàng Admin (`ShopAdminScreen`):**
   - Hiển thị **danh sách chi tiết từng sản phẩm (Ảnh, Tên, Size, Màu, Số lượng)**, hình thức nhận hàng (`Giao tận nơi` / `Nhận tại cửa hàng`), ghi chú của khách (`note`), và trạng thái thanh toán (`paymentStatus`) ngay trên thẻ đơn hàng.
   - Chạm vào bất kỳ đơn hàng nào để mở `OrderDetailScreen` (hỗ trợ đầy đủ quyền Admin).
   - Bộ nút điều khiển đầy đủ theo trạng thái: **Xác nhận đã thu tiền VietQR**, **Duyệt giao hàng**, **Hoàn tất đơn**, **Hủy đơn (kèm lý do & hoàn kho)**, **Xử lý Yêu cầu Đổi/Trả hàng (`Approve / Reject Return` $\rightarrow$ tự động hoàn kho SKU + chuyển `paymentStatus = 'Refunded'`)**.
3. **Nâng cấp Quản lý Kho Sản phẩm & Danh mục (`AdminProductListScreen` & `AdminProductFormScreen`):**
   - Hiển thị rõ `Tồn kho: X | Đã bán: Y` và trạng thái `Đang bán / Ngừng bán` trên từng thẻ sản phẩm của Admin.
   - Thêm nút **"Nhập kho nhanh (Quick Restock)"** và **"Quản lý Danh mục (`categories`)"** (Thêm / Sửa / Xóa danh mục).
   - Trong `AdminProductFormScreen`:
     - Hỗ trợ đầy đủ cả biến thể `'FreeSize'` (cho phụ kiện), đồng bộ toàn bộ màu sắc có sẵn và cho phép Admin **thêm Màu sắc / Size tùy chỉnh**.
     - Quản lý **nhiều URL hình ảnh (`imageUrls`)**, nhập **Giá bán (`price`)**, **Giá gốc (`originalPrice`)**, **Tồn kho theo biến thể SKU (`variantStock`)** và bật/tắt `isActive`.
     - **Chống ghi đè mất `reviews` và `soldCount` khi Admin sửa sản phẩm (`FirestoreService.updateProduct`):** Khi Admin lưu chỉnh sửa thông tin sản phẩm, không ghi đè mảng `reviews`, `rating`, `soldCount` bằng dữ liệu cũ lúc mở form, mà giữ nguyên `reviews`, `rating`, `soldCount` mới nhất trên Firestore.
4. **Nâng cấp Quản lý Chi nhánh (`AdminBranchManagementScreen`):**
   - Bổ sung chức năng **Chỉnh sửa chi nhánh (`updateBranch`)** đang bị thiếu.
   - Bổ sung nút **"Ghim vị trí trên Bản đồ OpenStreetMap"** ngay trong form Thêm/Sửa chi nhánh để tự động lấy Vĩ độ (`lat`), Kinh độ (`lng`) và Địa chỉ thay vì bắt Admin gõ tọa độ thập phân bằng tay.

---

### 🔐 PHÂN HỆ 12: BẢO MẬT TÀI KHOẢN, QUÊN MẬT KHẨU, ĐỔI MẬT KHẨU (`RE-AUTH`) & HỒ SƠ CÁ NHÂN TOÀN DIỆN
**File tác động:** `lib/screens/auth/login_screen.dart`, `lib/screens/auth/register_screen.dart`, `lib/screens/profile/profile_screen.dart`, `lib/screens/profile/edit_profile_screen.dart`, `lib/services/auth_service.dart`, `lib/providers/auth_provider.dart`

1. **Chuẩn hóa Xác thực & Đổi Mật khẩu An toàn (`LoginScreen`, `RegisterScreen`, `ProfileScreen`, `AuthService`):**
   - Tích hợp `AppValidators.validateEmail`, `AppValidators.validatePassword`, `AppValidators.validatePhone` đồng bộ.
   - Bổ sung luồng **"Quên mật khẩu?" (`sendPasswordResetEmail`)** qua hộp thoại nhập email khôi phục ngay tại `LoginScreen`.
   - **Quy trình "Đổi mật khẩu" chống lỗi `requires-recent-login` tại `ProfileScreen`:**
     - Kiểm tra phương thức đăng nhập `user.providerData.any((p) => p.providerId == 'password')`: Nếu tài khoản đăng nhập bằng Google OAuth (không dùng mật khẩu), ẩn mục Đổi mật khẩu hoặc hiển thị nhãn *"Tài khoản liên kết Google OAuth"*.
     - Với tài khoản Email/Password: Hộp thoại Đổi mật khẩu bắt buộc có **3 trường**: `Mật khẩu hiện tại`, `Mật khẩu mới`, và `Xác nhận mật khẩu mới`.
     - Khi bấm Lưu, `AuthService.changePassword(currentPassword, newPassword)` bắt buộc gọi `user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: currentPassword))` thành công trước rồi mới gọi `user.updatePassword(newPassword)` để không bao giờ bị văng lỗi `[firebase_auth/requires-recent-login]`.
   - Trong `AuthProvider._fetchUserProfile(uid)`: Đảm bảo tự động khởi tạo document `UserModel` nếu chưa có và dùng `SetOptions(merge: true)` trong mọi thao tác lưu để không bao giờ bị lỗi `NOT_FOUND`.
2. **Nâng cấp Hồ sơ Cá nhân (`ProfileScreen` & `EditProfileScreen`):**
   - Hiển thị ảnh đại diện thật từ `avatarUrl` (cho phép chọn từ bộ Avatar mẫu hoặc dán URL ảnh trong `EditProfileScreen`).
   - Cho phép chọn địa chỉ mặc định từ **Bản đồ OpenStreetMap (Reverse Geocoding)** và quản lý **Sổ địa chỉ nhận hàng (`savedAddresses`)** cũng như **Số đo cơ thể (`Chiều cao / Cân nặng`)**.
   - Bổ sung thanh tóm tắt nhanh trạng thái đơn hàng trên `ProfileScreen` (*Chờ xác nhận, Đang giao, Đã giao, Đổi/Trả, Yêu thích*) chuẩn giao diện tài khoản của Uniqlo / Shopee.

---

## IV. BẢNG KHÓA CHẶT 19 GÓC CHẾT & BẪY CODE LIÊN PHÂN HỆ (19 CROSS-MODULE LOCKS)

| Mã Bẫy | Vị trí File & Dòng Code | Mô tả Góc chết / Bẫy xung đột | Cơ chế Khóa chặn đã chốt trong V4.1 |
| :--- | :--- | :--- | :--- |
| **Bẫy 1** | `checkout_screen.dart` (dòng 68–80) | Bấm **"MUA NGAY"** (`directBuyItems`) nhưng `CheckoutScreen` lại đọc `cartProvider.subtotal` của đống đồ cũ trong giỏ. | Mọi phép tính `subtotal`, `shippingFee`, `productDiscount`, `shippingDiscount`, `totalPrice` ở `CheckoutScreen` bắt buộc tính từ `checkoutItems = widget.directBuyItems ?? cartProvider.selectedItems`. |
| **Bẫy 2** | `cart_provider.dart` | Đổi Size/Màu ngay trong Giỏ hàng làm sinh ra 2 dòng có cùng khóa `cartItemId = "${productId}_${size}_${color}"`. | Hàm `updateItemVariant()` nếu thấy `newCartItemId` đã tồn tại ở dòng khác thì cộng dồn `quantity` (kẹp trần `maxVariantStock`) vào dòng đó rồi xóa dòng cũ. |
| **Bẫy 3** | `cart_provider.dart` & `checkout_screen.dart` | Đơn $\ge 499.000\text{đ}$ hoặc chọn `PICKUP` đã có `shippingFee = 0đ` mà áp mã `FREESHIP` sẽ hiện `"FREESHIP (-0đ)"`. | Chặn áp mã `FREESHIP` khi `shippingFee == 0` (hoặc tự động gỡ khi chuyển sang `PICKUP`) và gợi ý khách chọn mã giảm tiền hàng (`SALE10`, `UNIQLO50K`). |
| **Bẫy 4** | `auth_service.dart` & `profile_screen.dart` | Gọi thẳng `user.updatePassword()` bị Firebase quăng lỗi `requires-recent-login`; hoặc tài khoản Google OAuth không có mật khẩu. | Kiểm tra `providerId == 'password'`; bắt buộc nhập `Mật khẩu hiện tại` để gọi `reauthenticateWithCredential()` trước khi `updatePassword()`. |
| **Bẫy 5** | `firestore_service.dart` & `shop_admin_screen.dart` | Đơn đã thanh toán (`Paid`) khi bị Hủy (`Cancelled`) hoặc Hoàn trả (`Returned`) không đổi sang `'Refunded'` và làm sai lệch Doanh thu thực. | Tự động chuyển `paymentStatus` từ `'Paid'` sang `'Refunded'` (và `'PaymentSubmitted'` về `'Unpaid'`) khi Hủy/Hoàn trả. KPI Doanh thu thực & AOV chỉ cộng đơn `status == 'Delivered'`. |
| **Bẫy 6** | `firestore_service.dart` (dòng 200) | Hàm `FirestoreService.createOrder()` gọi cứng `await clearCart(order.userId)` xóa trắng giỏ hàng trên Cloud ngay cả khi Mua ngay hoặc mua 1 phần giỏ. | Xóa bỏ lệnh `await clearCart(order.userId)` khỏi `FirestoreService.createOrder()`. Giao quyền xóa các món đã chọn (`removePurchasedItems`) cho `CartProvider` khi `directBuyItems == null`. |
| **Bẫy 7** | `main_nav_screen.dart` (dòng 177) & `chat_provider.dart` | `IndexedStack` giữ sống `ChatScreen` (Tab 3), nhưng `ChatProvider` dùng chung 1 `_messagesSub` nên khi Admin mở chat khách B xong quay lại Tab 3 sẽ bị kẹt ở đoạn chat của khách B. | Tách 2 luồng độc lập trong `ChatProvider`: `messages` (`_customerMessagesSub`) cho Tab 3 và `adminActiveMessages` (`_adminActiveMessagesSub`) cho `AdminChatDetailScreen`. |
| **Bẫy 8** | `order_history_screen.dart` (dòng 441) & `order_detail_screen.dart` (dòng 460) | Cả 2 màn hình đều hiện nút mở mã QR khi `order.paymentMethod == 'VIETQR'` ngay cả khi đơn đã Hủy, đã Giao hoặc đã Thanh toán; `VietQrPaymentDialog` gán cứng tiêu đề `"ĐẶT HÀNG THÀNH CÔNG!"`. | Chỉ hiện nút mở QR ở cả 2 màn hình khi `paymentMethod == 'VIETQR' && status == 'Pending' && paymentStatus == 'Unpaid'`. Thêm cờ `isFromCheckout` vào `VietQrPaymentDialog`. |
| **Bẫy 9** | `product_detail_screen.dart`, `cart_screen.dart`, `order_detail_screen.dart` | Chọn `_quantity = 5` ở Size M rồi đổi sang Size L (còn 2 cái) làm lố tồn kho; đồ ngâm trong giỏ hoặc bấm `Mua lại` (`reOrder`) bị lệch giá mới hoặc đã hết hàng / ngừng bán (`isActive == false`). | Tự động kẹp `_quantity = min(_quantity, currentVariantStock)` khi đổi Size/Màu; đối chiếu live `ProductProvider` ở Giỏ hàng & khi `reOrder` để cập nhật giá mới và tự bỏ chọn món hết hàng/ngừng KD. |
| **Bẫy 10** | `firestore_service.dart` (dòng 122) | `addProductReview` dùng `FieldValue.arrayUnion` với `createdAt: DateTime.now()` khiến mỗi lần đánh giá luôn tạo phần tử mới và tính sai trung bình `rating`. | Upsert trực tiếp theo `userId` + `orderId` trên mảng `updatedReviews` trong Transaction và ghi đè `'reviews': updatedReviews`. |
| **Bẫy 11** | `login_screen.dart`, `register_screen.dart` (dòng 49), `profile_screen.dart` (dòng 430), `checkout_screen.dart` (dòng 106 & 150) | Cả 4 màn hình đều gọi `pushReplacement` / `pushAndRemoveUntil` làm nổ `Consumer<AuthProvider>` gốc ở `main.dart` và nhân đôi `MainNavScreen`. | Xóa toàn bộ `pushReplacement` / `pushAndRemoveUntil` về `MainNavScreen`/`LoginScreen`; dùng `Navigator.popUntil((route) => route.isFirst)` và `MainNavScreen.switchToTab(context, tabIndex)`. |
| **Bẫy 12** | `product_provider.dart` (dòng 199) & `admin_product_form_screen.dart` (dòng 39) | Thiếu kích cỡ `'FreeSize'` cho phụ kiện (`cat_phukien`), thiếu lọc `isActive == true` cho khách hàng, và nguy cơ crash `DropdownButtonFormField` nếu `categoryId` lệch. | Bổ sung `'FreeSize'` vào cả `ProductProvider` lẫn `AdminProductFormScreen`; lọc `p.isActive` ở `filteredProducts`; kiểm tra an toàn `effectiveCategoryId` trước khi truyền vào Dropdown. |
| **Bẫy 13** | `cart_provider.dart` (dòng 9, 39–50, 157) & `profile_screen.dart` (dòng 427) | `this.userId` luôn `null` ở `main.dart` làm `_syncWithFirestore()` chết hoàn toàn; nhưng ở `ProfileScreen` lúc Đăng xuất lại gọi `clearCart()` (nếu sync sống lại sẽ xóa sạch giỏ hàng Cloud của khách!). | Đổi sang biến động `_activeUserId` cập nhật trong `loadUserCart(uid)` kèm quản lý `_cartSub`. Khi Đăng xuất chỉ gọi `unloadCartOnLogout()` (xóa RAM cục bộ, **không** xóa Cloud `carts/{uid}`). |
| **Bẫy 14** | `product_list_screen.dart` (dòng 31 & 334–376) | Kiểm tra `filteredProducts.isEmpty` nhưng lại báo *"Chưa có dữ liệu trên Firestore"* và hiện nút mở thẳng `ShopAdminScreen` cho cả tài khoản `customer`! | Tách rõ `allProducts.isEmpty` (chỉ Admin mới thấy nút mở `ShopAdminScreen`) và `filteredProducts.isEmpty` (hiện nút *"Xóa bộ lọc & Tìm lại"*). |
| **Bẫy 15** | `order_provider.dart`, `notification_provider.dart`, `chat_provider.dart` | Khi Đăng xuất / Đổi tài khoản, các stream và dữ liệu trong RAM của User A không được hủy, gây rò rỉ dữ liệu sang User B. | Bổ sung `resetSession()` cho toàn bộ Providers khi Đăng xuất và gắn `ValueKey(auth.userId)` cho `MainNavScreen`. |
| **Bẫy 16** | `order_detail_screen.dart` (dòng 23 & 70) | Dòng 23 chỉ tìm đơn trong `orderProvider.userOrders`, khiến khi Admin mở xem đơn của khách khác từ `ShopAdminScreen` và bấm duyệt đơn thì UI đứng im không cập nhật. | Tra cứu đơn hàng live trong cả `orderProvider.userOrders` và `orderProvider.allOrders`; đổi nút liên hệ cuối trang theo vai trò Khách / Admin. |
| **Bẫy 17** | `admin_product_form_screen.dart` (dòng 60 & 127) & `firestore_service.dart` (dòng 139) | Admin sửa sản phẩm làm mất các ảnh thứ 2, 3 trong `imageUrls` và ghi đè mất các `reviews`, `rating`, `soldCount` mới phát sinh. | Bảo toàn danh sách `imageUrls` (hỗ trợ nhiều ảnh) và giữ nguyên `reviews`, `rating`, `soldCount` mới nhất trên Firestore khi Admin cập nhật thông tin sản phẩm. |
| **Bẫy 18** | `firestore_service.dart` (dòng 411–422) | Hàm `seedInitialData()` chỉ ghi thủ công 10 trường cũ, bỏ sót `originalPrice`, `stock`, `variantStock`, `soldCount`, `isActive`, làm kho hàng về 0 nếu bấm Seed Data. | Cập nhật `mock_data.dart` và `seedInitialData()` nạp đầy đủ 100% trường mới với `SetOptions(merge: true)`. |
| **Bẫy 19** | `store_map_screen.dart` (dòng 28–35 & 128–136) | Mở bản đồ chọn địa chỉ giao hàng (`isPickerMode: true`) nhưng mặc định gán tên Chi nhánh cửa hàng hoặc trả về tọa độ số khi Nominatim đang tải. | Khóa nút xác nhận trong lúc đang phân giải Reverse Geocoding, không gán tên chi nhánh vào địa chỉ nhà khách, và thêm ô nhập bổ sung Số nhà/Tầng ngay trên thẻ đáy bản đồ. |
| **Bẫy 20** | `firestore_service.dart` & `order_provider.dart` | Đơn `COD` khi giao thành công (`Delivered`) không tự đổi `paymentStatus = 'Paid'`, dẫn tới khi khách trả hàng (`Returned`) không chuyển sang `'Refunded'`; thiếu hàm `rejectPaymentSubmitted` khi Admin từ chối báo CK VietQR. | Khi đơn chuyển sang `'Delivered'`, tự động cập nhật `paymentStatus = 'Paid'`. Bổ sung `rejectPaymentSubmitted` (đưa về `'Unpaid'` + báo khách quét lại), hỗ trợ VietQR 3-Tier Reconciliation (Realtime Stream Auto-Dismiss + Sandbox Demo Mode) và hiện nút mở QR khi `(status == 'Pending' || status == 'Delivering') && paymentStatus == 'Unpaid'`. |
| **Bẫy 21** | `firestore_service.dart` (`createOrder`, `cancelOrder`, `approveReturnOrder`) | Vòng lặp đọc-ghi xen kẽ trong Firestore Transaction gây crash `all reads before all writes`; mua 2 Size/Màu của cùng 1 `productId` làm dòng thứ 2 ghi đè mất lần trừ kho dòng thứ 1; bấm đúp nút Hủy/Hoàn trả gây Hoàn kho kép (`Double Restock`). | Thực hiện toàn bộ `transaction.get()` trước toàn bộ `transaction.update()`, gom nhóm thay đổi kho theo từng `productId` duy nhất trong RAM trước khi ghi, và kiểm tra `currentStatus == 'Cancelled' || currentStatus == 'Returned'` ngay trong Transaction để chống hoàn kho kép. |
| **Bẫy 22** | `test/*_test.dart` vs `ProductProvider`, `VietQrPaymentDialog`, `OrderDetailScreen`, `CheckoutScreen` | Môi trường Widget/Unit Test không gọi `Firebase.initializeApp()` và nhiều bài test chỉ bọc 1 Provider đơn lẻ (`OrderProvider`), nếu gọi thẳng `FirebaseFirestore.instance` hoặc `context.watch<AuthProvider>()` sẽ crash `[core/no-app]` và `ProviderNotFoundException`. | Giữ `getCategories()`/`getProducts()` trong `ProductProvider.loadData()` kèm `try/catch` cho stream; kiểm tra `try/catch` khi lắng nghe Firestore trong `VietQrPaymentDialog` & fallback `AppConstants.storeBranches`; dùng nullable lookup `Provider.of<AuthProvider?>(context)` ở các màn hình dùng chung. |
| **Bẫy 23** | `pubspec.yaml`, `analysis_options.yaml` & `store_map_screen.dart` | `pubspec.yaml` không khai báo gói `http` trực tiếp (nếu `import 'package:http/http.dart'` sẽ bị `flutter analyze` báo lỗi `depend_on_referenced_packages`); dùng `context` sau `await` bị `flutter_lints 4.0` báo `use_build_context_synchronously`. | Dùng `dart:io` (`HttpClient`) + `dart:convert` cho Nominatim Reverse Geocoding (không cần thêm package ngoài); luôn kiểm tra `if (!mounted) return;` / `if (!context.mounted) return;` sau mọi `await`. |

---

## V. LỘ TRÌNH TRIỂN KHAI KỸ THUẬT (4 GIAI ĐOẠN KHÉP KÍN)

| Giai đoạn | Hạng mục thực hiện | Kết quả đầu ra |
| :--- | :--- | :--- |
| **Giai đoạn 1: Nền tảng Data Models, Constants & Firestore Service** | Nâng cấp 7 Models (`UserModel`, `CategoryModel`, `ProductModel`, `CartItemModel`, `OrderModel`, `NotificationModel`, `MessageModel`), `AppConstants.vouchers`, `mock_data.dart` và `FirestoreService` (Xóa `clearCart` khỏi `createOrder`, Transaction trừ/hoàn kho SKU, `seedInitialData` đầy đủ trường + merge, Reverse Geocoding, Order State Machine + auto `Refunded`, Review upsert, Unread Chat Counters, `updateProduct` bảo toàn `reviews`/`soldCount`). | Tầng dữ liệu đạt chuẩn ACID & đầy đủ trường nghiệp vụ. |
| **Giai đoạn 2: Tầng State Management (6 Providers)** | Tái cấu trúc `AuthProvider` (reset/re-auth change password), `ProductProvider` (real-time stream + dynamic categories + `isActive` filter + `FreeSize`), `CartProvider` (`_activeUserId` Cloud sync chống giật + `unloadCartOnLogout` + chọn lọc món + merge variant + hàm tính giá độc lập cho `checkoutItems`), `OrderProvider` (6 trạng thái + đối soát thanh toán + `resetSession`), `NotificationProvider` (`resetSession`), `ChatProvider` (Tách 2 stream Khách/Admin độc lập + Unread badge + `resetSession`). | 6 Providers vận hành trơn tru, không rò rỉ bộ nhớ hay ghi đè trạng thái. |
| **Giai đoạn 3: Trải nghiệm Khách hàng (Customer UI Flows)** | Nâng cấp `main.dart` & `MainNavScreen.switchToTab`, `ProductListScreen` (Vá lỗi leo thang quyền Admin + Badge giảm giá/hết hàng), `ProductDetailScreen` (Size Guide, SKU Stock clamp, Buy Now, Wishlist), `CartScreen` (Checkbox, Live price/stock sync, Freeship bar, Đổi phân loại chống trùng key), `CheckoutScreen` (Tính chuẩn trên `checkoutItems`, Delivery vs Pickup, Sổ địa chỉ), `StoreMapScreen` (Reverse Geocoding + ô nhập Số nhà), `OrderHistoryScreen` & `OrderDetailScreen` (Khóa nút QR ở cả 2 màn hình, hỗ trợ cả Admin/Customer live update, Sửa địa chỉ, Hủy/Đổi trả/Mua lại an toàn), `ChatScreen`, `NotificationScreen`, `ProfileScreen`, `EditProfileScreen`. | Luồng mua sắm khép kín chuẩn Uniqlo / Coolmate. |
| **Giai đoạn 4: Phân hệ Quản trị (Admin Portal) & Cập nhật Kiểm thử** | Nâng cấp `ShopAdminScreen` (BI Dashboard tính chuẩn Net Revenue `Delivered`, Low-stock alert, Duyệt đơn chi tiết, Xử lý Đổi/Trả), `AdminProductListScreen` (Quick Restock, CRUD Danh mục), `AdminProductFormScreen` (Multi-image, SKU Stock, `FreeSize` & Custom Color, Original Price, Safe Category Dropdown), `AdminBranchManagementScreen` (Edit + Map Picker), `AdminChatInboxScreen` (Unread badge + kênh stream Admin riêng), và cập nhật đồng bộ các file test trong `test/`. | Hệ thống hoàn chỉnh 100% cả Khách hàng lẫn Quản trị viên. |
