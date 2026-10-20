# 📋 BẢNG PHÂN CÔNG CÔNG VIỆC (TEAM TASK ASSIGNMENT - PRM393)

Đồ án ứng dụng Mua sắm Thời trang (Fashion Store App) được chia thành các module độc lập cho 5 thành viên. Mỗi thành viên tạo một nhánh riêng (ví dụ: `feature/auth`, `feature/product`...) để code và tạo Pull Request vào `main`.

---

### ⚠️ CÁC LƯU Ý KỸ THUẬT QUAN TRỌNG CHO TOÀN NHÓM
1. **Thiếu file `google-services.json`:** 
   - Thư mục `fashion_store_app/android/app/` hiện chưa có file kết nối Firebase. Nhóm trưởng đã lên Firebase Console tải về, nhưng **tuyệt đối không push file này lên GitHub** (vì lý do bảo mật). Các thành viên khi clone repo về phải xin file này từ nhóm trưởng và tự bỏ vào máy mình.
2. **Khung điều hướng chung (`main_nav_screen.dart`):** 
   - Các thành viên làm màn hình con, nhưng cần một khung chung gồm thanh chuyển tab dưới đáy (Bottom Navigation Bar) để gom tất cả lại. Nhóm trưởng sẽ ôm phần này.
3. **Mẹo Demo - Nút "Khởi tạo dữ liệu mẫu (Seed Data)":**
   - Lần đầu chạy app, Firestore sẽ trống rỗng. Đã tạo sẵn file data mẫu cực nét tại `lib/core/constants/mock_data.dart` (gồm 4 danh mục và 8 sản phẩm thời trang đầy đủ mô tả, giá VND, size, màu, link ảnh Unsplash). Nhóm trưởng sẽ tích hợp hàm đẩy dữ liệu từ file này lên Firestore gắn vào nút bấm trên `shop_admin_screen.dart`. Lúc test app chỉ cần bấm 1 nút là dữ liệu tự động đổ đầy lên Firestore trong 2 giây!

---

### 👤 NHÓM TRƯỞNG (Tech Lead): Khung hệ thống, Backend & Seed Data
- **Nhiệm vụ:**
  - Setup khung project, cấu hình Firebase Auth & Firestore (7 collections) và kiểm tra file `google-services.json`.
  - Viết tầng Service (`services/auth_service.dart`, `services/firestore_service.dart`) và 7 file Models (`lib/models/`).
  - **Code khung điều hướng chính:** `screens/main_nav_screen.dart` (BottomNavigationBar gom toàn bộ app).
  - **Code tính năng Seed Data:** Sử dụng dữ liệu có sẵn tại `lib/core/constants/mock_data.dart` để viết hàm tự động đẩy lên Firestore qua nút bấm trong `shop_admin_screen.dart`.
  - Review code (Pull Request) của các thành viên trước khi gộp vào `main`.

---

### 👤 THÀNH VIÊN 2: Module Xác thực & Trang cá nhân (Auth & Profile)
- **Nhiệm vụ:**
  - Code màn hình Đăng nhập (`login_screen.dart`) hỗ trợ Email/Password và nút **Google Sign-In**.
  - Code màn hình Đăng ký tài khoản (`register_screen.dart`).
  - Code màn hình Thông tin cá nhân & Lịch sử đơn hàng (`profile_screen.dart`, `order_history_screen.dart`).
  - Viết `AuthProvider` quản lý trạng thái đăng nhập.
  - Viết bài Widget Test: `test/login_screen_test.dart`.

---

### 👤 THÀNH VIÊN 3: Module Sản phẩm & Trang chủ (Home & Catalog)
- **Nhiệm vụ:**
  - Code màn hình Danh sách sản phẩm (`product_list_screen.dart`): Hiển thị Banner, danh mục ngang, thanh tìm kiếm thời gian thực và bộ lọc/sắp xếp giá.
  - Code màn hình Chi tiết sản phẩm (`product_detail_screen.dart`): Hiển thị ảnh, chọn Size (`S/M/L/XL`), chọn Màu, số lượng.
  - Tính năng **Viết đánh giá (Review)** bằng `FieldValue.arrayUnion`.
  - Viết `ProductProvider`.

---

### 👤 THÀNH VIÊN 4: Module Giỏ hàng & Thanh toán (Cart & Checkout)
- **Nhiệm vụ:**
  - Code màn hình Giỏ hàng (`cart_screen.dart`): Quản lý danh sách item theo size/màu, tăng giảm số lượng, xóa sản phẩm.
  - Code màn hình Thanh toán (`checkout_screen.dart`): Nhập địa chỉ, ô nhập mã Voucher (`SALE10`, `FREESHIP`), chọn phương thức COD/VietQR.
  - Viết `CartProvider` và `OrderProvider` (bao gồm logic tính tiền tạm tính, chiết khấu và tạo đơn hàng lên Firestore).
  - Viết bài Unit Test: `test/cart_provider_test.dart`.

---

### 👤 THÀNH VIÊN 5: Module Tiện ích (Bản đồ, Chat & Thông báo)
- **Nhiệm vụ:**
  - Code màn hình Bản đồ chi nhánh (`store_map_screen.dart`) dùng thư viện `flutter_map` (OpenStreetMap) và `geolocator`.
  - Code màn hình Nhắn tin tư vấn (`chat_screen.dart`) kết nối Sub-collection `messages` real-time.
  - Code màn hình Thông báo (`notification_screen.dart`).
  - Code màn hình công cụ phụ trợ bảo vệ đồ án (`shop_admin_screen.dart`) giúp chủ shop duyệt đơn và trả lời chat lúc demo.
  - Viết `ChatProvider` và `NotificationProvider`.
