# 📋 BẢNG KẾ HOẠCH & PHÂN CÔNG CÔNG VIỆC DỰ ÁN CUỐI KỲ (PRM393)
## ĐỀ TÀI: ỨNG DỤNG MUA SẮM THỜI TRANG TRỰC TUYẾN (FASHION MOBILE STORE APP)
**Hệ thống:** Mobile App Flutter (Dart 3.x) | **Backend:** Firebase (Auth, Cloud Firestore) | **Kiến trúc:** MVVM (Provider)

---

### 📌 QUY CHUẨN KỸ THUẬT & QUY TRÌNH LÀM VIỆC DÀNH CHO TOÀN NHÓM
1. **Quản lý Source Code & Nhánh Git:**
   - **Tuyệt đối không push trực tiếp lên nhánh `main`.**
   - Mỗi thành viên khi làm module của mình phải tạo nhánh tính năng riêng: `feature/<tên-module>` (ví dụ: `feature/admin-portal`, `feature/auth-profile`, `feature/product-catalog`, `feature/cart-checkout`, `feature/order-chat`).
   - Sau khi hoàn thành và tự test chạy lệnh `flutter test` đạt **100% All tests passed** và `flutter analyze` **No issues found**, mới được tạo **Pull Request (PR)** vào `main` để Nhóm trưởng review và merge.
2. **Quy chuẩn Kiến trúc (Strict Rules):**
   - Tuân thủ mô hình **MVVM**: Views (UI Screens) $\leftrightarrow$ ViewModels (`ChangeNotifier` Provider) $\leftrightarrow$ Data Layer (`Services` & `Models`).
   - Sử dụng đúng 7 Collections Firestore: `users`, `categories`, `products`, `carts`, `orders`, `notifications`, `chats` (và `branches` bổ sung).
   - Không sử dụng Firebase Storage (dùng link ảnh Unsplash/Cloudinary).
   - Bản đồ sử dụng OpenStreetMap (`flutter_map`, `latlong2`, `geolocator`), không dùng Google Maps API key có tính phí.
3. **Quy chuẩn Validation & Bắt lỗi Nghiệp vụ:**
   - Mọi Form nhập liệu đều phải có `validator` chặt chẽ (Email Regex, SĐT 10 số Việt Nam, mật khẩu $\ge 6$ ký tự, giá tiền $> 0$).
   - Mọi tác vụ bất đồng bộ gọi Firebase đều phải bọc `try/catch` và hiển thị thông báo SnackBar/Dialog tiếng Việt rõ ràng.

---

### 📊 TIẾN ĐỘ TỔNG THỂ & PHÂN CÔNG CHI TIẾT 5 THÀNH VIÊN

---

### 👤 1. NHÓM TRƯỞNG (Tech Lead): Khung hệ thống, Backend & Admin Management Portal
- **Nhánh phụ trách:** `feature/system-foundation` & `feature/admin-portal`
- **Nhiệm vụ chi tiết:**
  - [x] **Setup Hạ tầng & Cấu hình:** Khởi tạo Flutter project, cấu hình Firebase Auth & Firestore, liên kết `google-services.json`, cấp quyền trong `AndroidManifest.xml` và `build.gradle.kts`.
  - [x] **Xây dựng Tầng Core:** Khởi tạo bảng màu Uniqlo Lifewear ([app_colors.dart](file:///e:/FBT_UNIVERSITY/FBT_UNIVERSITY_KI_8/PRM393/fashion_store_app/lib/core/constants/app_colors.dart)), bộ định dạng tiền tệ VNĐ và thời gian ([formatters.dart](file:///e:/FBT_UNIVERSITY/FBT_UNIVERSITY_KI_8/PRM393/fashion_store_app/lib/core/utils/formatters.dart)).
  - [x] **Xây dựng 7 Dart Models:** `UserModel`, `CategoryModel`, `ProductModel` (kèm `ReviewModel`), `CartItemModel`, `OrderModel`, `NotificationModel`, `MessageModel` có đủ `fromMap()`, `toMap()`, `copyWith()`.
  - [x] **Xây dựng Services Layer:** `AuthService` và `FirestoreService` (kèm hàm nạp **Seed Data** tự động nạp 4 danh mục và 8 sản phẩm mẫu Unsplash).
  - [x] **Khung điều hướng chính:** `main_nav_screen.dart` (BottomNavigationBar gom toàn bộ 5 tab của app) và bọc `MultiProvider` tại `main.dart`.
  - [ ] **Hệ thống Quản trị Shop Admin Portal (`screens/admin/`):**
    - [ ] `admin_dashboard_screen.dart`: Thống kê KPI doanh thu, số đơn hàng mới, tổng số sản phẩm, đơn đang giao.
    - [ ] `admin_product_list_screen.dart`: Danh sách quản lý sản phẩm kho hàng có tìm kiếm và bộ lọc.
    - [ ] `admin_product_form_screen.dart`: Màn hình Thêm mới & Chỉnh sửa sản phẩm (Upload ảnh URL, Tên, Giá, Mô tả, Checkbox chọn Size `[S, M, L, XL]`, Checkbox chọn Màu sắc).
    - [ ] Chức năng Xóa sản phẩm khỏi Firestore kèm Dialog xác nhận an toàn.
    - [ ] `admin_branch_management_screen.dart`: Quản lý danh sách chi nhánh (Thêm chi nhánh mới bằng ghim tọa độ trên Map, sửa địa chỉ, xóa chi nhánh).
    - [ ] `admin_chat_inbox_screen.dart`: Hộp thư CSKH của Admin (Xem danh sách các khách đang cần tư vấn và mở khung chat phản hồi thời gian thực với tư cách Shop).
  - [x] Review code (Pull Request) của các thành viên trước khi merge vào `main`.

---

### 👤 2. THÀNH VIÊN 2: Module Xác thực, Bảo mật & Trang cá nhân (Auth & Profile)
- **Nhánh phụ trách:** `feature/auth-profile`
- **Nhiệm vụ chi tiết:**
  - [x] **Màn hình Đăng nhập (`screens/auth/login_screen.dart`):**
    - Form nhập Email và Mật khẩu có ẩn/hiện password.
    - Nút bấm đăng nhập Email/Password và nút Đăng nhập tài khoản Google (OAuth 2.0).
    - Tự động chuyển hướng vào `MainNavScreen` khi đăng nhập thành công.
  - [x] **Màn hình Đăng ký tài khoản (`screens/auth/register_screen.dart`):**
    - Form nhập Họ tên, Email, Mật khẩu và Xác nhận mật khẩu.
    - Lưu thông tin user vào Firebase Auth và tự động tạo Document tại collection `users`.
  - [x] **Validation Xác thực Chặt chẽ (`core/utils/app_validators.dart`):**
    - Email Regex RFC chuẩn (báo lỗi nếu thiếu `@` hoặc sai định dạng domain).
    - Mật khẩu tối thiểu 6 ký tự.
    - Kiểm tra mật khẩu xác nhận phải trùng khớp tuyệt đối.
  - [ ] **Trang cá nhân & Chỉnh sửa hồ sơ (`screens/profile/`):**
    - [x] `profile_screen.dart`: Hiển thị Avatar, Họ tên, Email, Vai trò (`Customer` hoặc `Admin`), danh sách menu tiện ích và nút Đăng xuất (kèm lệnh `cartProvider.clearCart()`).
    - [ ] `edit_profile_screen.dart`: Màn hình cho phép khách cập nhật Họ tên, Số điện thoại (kiểm tra Regex đúng 10 chữ số VN bắt đầu bằng `0`), và Địa chỉ nhận hàng mặc định lưu vào Firestore.
  - [x] **Viết bài Widget Test Bắt buộc:** `test/login_screen_test.dart` (Kiểm thử trực tiếp trên màn hình `LoginScreen` thật).

---

### 👤 3. THÀNH VIÊN 3: Module Sản phẩm, Bộ sưu tập & Đánh giá (Catalog & Reviews)
- **Nhánh phụ trách:** `feature/product-catalog`
- **Nhiệm vụ chi tiết:**
  - [x] **Màn hình Danh sách sản phẩm (`screens/home/product_list_screen.dart`):**
    - Banner quảng cáo thời trang phong cách Uniqlo Lifewear.
    - Thanh chọn danh mục ngang (`Tất cả`, `Áo Thun & Polo`, `Áo Khoác`, `Quần Jean`, `Phụ Kiện`).
    - Thanh tìm kiếm sản phẩm theo tên và mô tả thời gian thực (Real-time Instant Search).
    - Bộ lọc sắp xếp sản phẩm theo: Phổ biến, Giá thấp đến cao, Giá cao đến thấp, Đánh giá cao nhất.
  - [ ] **Nâng cấp Bộ lọc Sản phẩm Nâng cao (Filter Modal):**
    - Lọc sản phẩm theo khoảng giá tùy chọn (VD: dưới 200k, 200k - 400k, trên 400k).
    - Lọc theo kích cỡ (Size S, M, L, XL) và lọc theo màu sắc.
  - [x] **Màn hình Chi tiết sản phẩm (`screens/home/product_detail_screen.dart`):**
    - Gallery ảnh sản phẩm Unsplash đa góc độ kèm chỉ số trang `1/3`.
    - Lựa chọn Màu sắc, Kích cỡ (`S/M/L/XL`), Số lượng sản phẩm kèm nút cộng/trừ.
    - Hiển thị mô tả chất liệu, phom dáng và xuất xứ.
  - [ ] **Bảng Quy đổi Kích cỡ (Size Chart Guide Modal):**
    - Bổ sung nút "Bảng quy đổi kích cỡ" cạnh mục chọn size.
    - Bấm vào mở BottomSheet hiển thị bảng thông số chiều cao & cân nặng chuẩn tương ứng từng size (S, M, L, XL) giúp khách tự tin chọn size.
  - [x] **Tính năng Viết đánh giá (Reviews):**
    - Hiển thị danh sách đánh giá kèm số sao và thời gian tương đối ("Vừa xong", "2 ngày trước").
    - Nút "Viết đánh giá" mở Dialog chấm điểm từ 1 đến 5 sao + ô nhập bình luận.
    - Ghi nhận đánh giá trực tiếp bằng `FieldValue.arrayUnion` lên Firestore và tự động tính lại điểm trung bình (`rating`).
  - [x] **Quản lý trạng thái:** Hoàn thiện `ProductProvider`.

---

### 👤 4. THÀNH VIÊN 4: Module Giỏ hàng, Voucher & Thanh toán (Cart & Billing)
- **Nhánh phụ trách:** `feature/cart-checkout`
- **Nhiệm vụ chi tiết:**
  - [x] **Màn hình Giỏ hàng (`screens/cart/cart_screen.dart`):**
    - Hiển thị danh sách sản phẩm phân tách độc lập theo `cartItemId = "${productId}_${size}_${color}"`.
    - Bộ tăng/giảm số lượng món và nút xóa sản phẩm khỏi giỏ.
    - Tự động đồng bộ giỏ hàng với Firestore collection `carts`.
    - Trạng thái giỏ hàng rỗng có hình minh họa thân thiện.
  - [x] **Hệ thống Mã giảm giá (Vouchers Engine):**
    - Ô nhập mã Voucher kèm nút "Áp dụng".
    - Xử lý mã `SALE10` (chiết khấu 10% tổng đơn) và `FREESHIP` (giảm thẳng 30.000 VNĐ).
    - Tự động tính toán tức thì `subtotal`, `discountAmount`, `totalPrice`.
  - [x] **Màn hình Thanh toán (`screens/cart/checkout_screen.dart`):**
    - Tự động điền Họ tên, SĐT và Địa chỉ mặc định của người dùng.
    - Nút mở OpenStreetMap ghim chọn vị trí nhận hàng tự động điền về ô địa chỉ.
    - Lựa chọn phương thức thanh toán: `COD` (Thanh toán khi nhận hàng) hoặc `VIETQR` (Chuyển khoản).
    - Bấm "Xác nhận đặt hàng" $\rightarrow$ tạo đơn hàng trên collection `orders`, dọn sạch giỏ hàng (`clearCart()`) và tự động kích hoạt thông báo.
  - [ ] **Cổng Thanh toán VietQR Động Chuẩn Ngân Hàng:**
    - Khi chọn `VIETQR`, app tự động gọi API sinh mã QR thật từ VietQR Napas247 (`https://img.vietqr.io/image/<BANK_ID>-<ACCOUNT_NO>-compact2.png?amount=<TIỀN>&addInfo=<MÃ_ĐƠN>`).
    - Giảng viên và khách có thể mở ứng dụng ngân hàng bất kỳ để quét mã thanh toán thật lúc demo.
  - [x] **Viết bài Unit Test Bắt buộc:** `test/cart_provider_test.dart` (Kiểm thử trực tiếp class `CartProvider` thật qua 5 test case tính tiền, áp voucher và reset giỏ hàng).

---

### 👤 5. THÀNH VIÊN 5: Module Tiện ích (Bản đồ, Chat, Đơn hàng & Thông báo)
- **Nhánh phụ trách:** `feature/utilities-orders`
- **Nhiệm vụ chi tiết:**
  - [x] **Màn hình Bản đồ Chi nhánh (`screens/map/store_map_screen.dart`):**
    - Sử dụng `flutter_map` (OpenStreetMap) kết hợp `latlong2`.
    - Hiển thị vị trí các chi nhánh cửa hàng kèm marker nổi bật.
    - Tích hợp `geolocator` lấy vị trí GPS hiện tại của người dùng.
    - Chế độ Picker Mode: Chạm chọn tọa độ bất kỳ trên bản đồ để xác nhận vị trí giao hàng.
  - [ ] **Chuyển Chi nhánh sang Firestore Collection `branches`:**
    - Thay thế dữ liệu hằng số tĩnh bằng luồng dữ liệu thời gian thực từ Firestore để đồng bộ với tính năng Thêm/Sửa/Xóa chi nhánh của Admin.
  - [x] **Màn hình Lịch sử Đơn hàng (`screens/orders/order_history_screen.dart`):**
    - Lắng nghe danh sách đơn hàng của người dùng thời gian thực theo thứ tự mới nhất.
    - Hiển thị mã đơn, ngày giờ, danh sách món, trạng thái đơn (`Chờ xác nhận`, `Đang giao hàng`, `Đã giao`).
  - [ ] **Màn hình Chi tiết Đơn hàng (`screens/orders/order_detail_screen.dart`):**
    - Bấm vào đơn hàng để xem chi tiết hóa đơn.
    - Thanh tiến trình trực quan (Timeline Stepper 3 bước: `Đặt hàng thành công` $\rightarrow$ `Đang giao hàng` $\rightarrow$ `Đã giao`).
    - Chi tiết địa chỉ giao hàng, SĐT người nhận, phương thức thanh toán và tóm tắt tiền.
  - [x] **Kênh Tư vấn Trực tuyến Khách hàng (`screens/chat/chat_screen.dart`):**
    - Chat thời gian thực với Shop tư vấn chiều cao/cân nặng để chọn size.
    - Giao diện bong bóng tin nhắn (Message Bubbles) phân biệt người gửi và hiển thị giờ gửi.
  - [x] **Màn hình Thông báo Người dùng (`screens/notifications/notification_screen.dart`):**
    - Lắng nghe real-time collection `notifications`.
    - Tự động nhận thông báo khi Đặt hàng thành công và khi Shop cập nhật trạng thái đơn hàng.
    - Huy hiệu đỏ (Badge) hiển thị số lượng thông báo chưa đọc trên AppBar.
    - Chạm vào thông báo để đánh dấu đã xem (`isRead = true`).

---

### 🎯 CHECKLIST 7 MỤC CHUẨN BỊ BÁO CÁO KỸ THUẬT (.PDF) & BẢO VỆ ĐỒ ÁN
1. **Trang Bìa & Thông tin Nhóm:** Tên đề tài, Logo FPTU, Bảng thành viên (MSSV, Họ tên, Email, Vai trò phân công).
2. **Case Study:** Giới thiệu bài toán thương hiệu thời trang Uniqlo Lifewear, lý do cần ứng dụng di động để tăng trải nghiệm khách hàng.
3. **Phân tích Nghiệp vụ & Thiết kế Hệ thống:**
   - 10 Functional Requirements & Non-functional Requirements.
   - Sơ đồ kiến trúc MVVM + Provider.
   - Sơ đồ luồng màn hình (UI Flow Navigation).
   - Sơ đồ thiết kế CSDL Cloud Firestore (7 collections).
4. **Minh chứng Kỹ thuật & Kiểm thử:**
   - Ảnh chụp lệnh `flutter test` xanh màu **`All tests passed!`** (Cả Unit Test và Widget Test).
   - Ảnh chụp lệnh xuất bản file `flutter build apk --release` và màn hình app chạy ở chế độ Release trên điện thoại thật.
5. **Minh chứng Giao diện & Tính năng Demo:**
   - Ảnh chụp chi tiết từng màn hình app đang hoạt động thực tế.
   - Minh chứng tính năng Seed Data 2 giây và duyệt đơn hàng real-time.
6. **Tổng kết & Đánh giá:** Ưu điểm, hạn chế và định hướng phát triển tương lai.
7. **Bảng đánh giá phần trăm đóng góp:** Bảng % đóng góp công bằng của 5 thành viên (Tổng mỗi hàng là 100%).
