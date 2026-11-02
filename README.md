# 🛍️ PRM393 - Fashion Store Mobile App (Lifewear Store)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Provider](https://img.shields.io/badge/State%20Management-Provider%20(MVVM)-E50019)](https://pub.dev/packages/provider)
[![Tests](https://img.shields.io/badge/Unit%20%26%20Widget%20Tests-203%20Passing%20(100%25)-4CAF50?logo=checkmarx&logoColor=white)](test/)
[![University](https://img.shields.io/badge/FPT%20University-PRM393-orange)](https://fpt.edu.vn)

Ứng dụng mua sắm thời trang trực tuyến chuẩn thương mại dành cho thương hiệu thời trang tối giản (Lifewear Single-Brand E-Commerce), phát triển bằng **Flutter & Firebase** theo kiến trúc **MVVM (Model - View - ViewModel)**.

---

## 🌟 TÍNH NĂNG NỔI BẬT

- **Thanh toán VietQR & Đối soát SePay tự động:** Sinh mã QR Napas24/7 theo đơn hàng; hệ thống chạy ngầm tự động đối soát giao dịch thời gian thực qua SePay và tự hủy đơn/hoàn tồn kho sau 2 phút nếu quá hạn thanh toán.
- **Bản đồ OpenStreetMap (100% Miễn phí):** Tích hợp tìm kiếm, định vị GPS và ghim địa chỉ nhận hàng trên bản đồ vệ tinh; tìm kiếm và xem danh sách chi nhánh showroom không cần API Key Google Maps.
- **Trợ lý đề xuất Size chuẩn:** Tự động tính toán thể trạng và gợi ý kích cỡ phù hợp (`S`, `M`, `L`, `XL`, `XXL`) theo chiều cao & cân nặng của người dùng.
- **Tư vấn trực tuyến thời gian thực (Realtime Chat):** Khách hàng chat trực tiếp với Admin, gửi hình ảnh và đính kèm thẻ sản phẩm hoặc thẻ đơn hàng trực tiếp vào cuộc trò chuyện.
- **Cổng Quản trị Shop Admin chuyên sâu:** Thống kê doanh thu thuần (BI Dashboard), phê duyệt đơn hàng đa trạng thái, quản lý kho theo từng SKU biến thể (Kích cỡ x Màu sắc) và quản lý hệ thống chi nhánh.

---

## 🔑 TÀI KHOẢN TRẢI NGHIỆM NHANH (DEMO ACCOUNTS)

Trên màn hình Đăng nhập của ứng dụng đã tích hợp sẵn tính năng **Đăng nhập 1 chạm**:

| Vai trò | Email đăng nhập | Mật khẩu | Nút bấm 1 chạm trên App |
| :--- | :--- | :--- | :--- |
| 👑 **Quản trị viên (Admin)** | `admin@fashionstore.com` | `Admin@123456` | Bấm nút **👑 Admin** |
| 👤 **Khách hàng (Customer)** | `customer@fashionstore.com` | `Customer@123456` | Bấm nút **👤 Khách hàng** |

---

## 🚀 HƯỚNG DẪN CÀI ĐẶT DÀNH CHO THÀNH VIÊN NHÓM

### 1. Yêu cầu môi trường
- **Flutter SDK:** `>= 3.19.0`
- **Dart SDK:** `>= 3.3.0`
- **Android SDK:** Hỗ trợ Android 7.0 (API level 24) trở lên

### 2. Các bước cài đặt từ GitHub

**Bước 1: Clone mã nguồn về máy**
```bash
git clone https://github.com/TaiLee75/PRM393-Fashion-Store-App.git
cd PRM393-Fashion-Store-App
```

**Bước 2: Cấu hình file Firebase (`google-services.json`)**
> ⚠️ **LƯU Ý QUAN TRỌNG:** Vì lý do bảo mật, file cấu hình dịch vụ Firebase không được lưu trữ công khai trên GitHub.  
> Thành viên trong nhóm vui lòng **liên hệ nhóm trưởng để nhận file `google-services.json`** và đặt vào đúng đường dẫn sau:
> ```text
> android/app/google-services.json
> ```

**Bước 3: Tải các thư viện phụ thuộc**
```bash
flutter pub get
```

**Bước 4: Chạy kiểm thử tự động (Verification)**
```bash
# Kiểm tra phân tích tĩnh (đạt 0 lỗi, 0 cảnh báo)
flutter analyze

# Chạy toàn bộ 203 bài Unit Test & Widget Test
flutter test --no-pub
```

**Bước 5: Khởi chạy ứng dụng**
```bash
flutter run
```

---

## 📂 CẤU TRÚC MÃ NGUỒN (`lib/`)

```text
lib/
├── core/             # Hằng số, Bảng màu (AppColors), Tiện ích xác thực & AppImage
│   ├── constants/    # app_colors.dart, app_constants.dart
│   └── utils/        # app_image.dart, app_validators.dart, size_recommender.dart
├── models/           # 7 Dart Models khớp 100% với Firestore Collections
│   ├── user_model.dart, product_model.dart, cart_item_model.dart
│   ├── order_model.dart, category_model.dart, chat_model.dart, branch_model.dart
├── services/         # Tầng giao tiếp dữ liệu bên ngoài
│   ├── auth_service.dart, firestore_service.dart, sepay_service.dart
├── providers/        # 6 ViewModels xử lý State Management (MVVM)
│   ├── auth_provider.dart, product_provider.dart, cart_provider.dart
│   ├── order_provider.dart, notification_provider.dart, chat_provider.dart
└── screens/          # Toàn bộ giao diện người dùng
    ├── auth/         # Đăng nhập, Đăng ký, Quên mật khẩu
    ├── home/         # Trang chủ, Banner, Danh mục, Sản phẩm nổi bật
    ├── products/     # Danh sách lọc, Chi tiết sản phẩm, Trợ lý kích cỡ
    ├── cart/         # Giỏ hàng, Áp voucher, Thanh toán COD/VietQR
    ├── orders/       # Danh sách đơn hàng, Chi tiết tiến trình giao hàng
    ├── chat/         # Nhắn tin hỗ trợ khách hàng kèm đính kèm sản phẩm/đơn
    ├── map/          # Bản đồ showroom & Ghim vị trí OSM
    ├── profile/      # Hồ sơ cá nhân, Sổ địa chỉ, Sản phẩm yêu thích
    └── admin/        # Trung tâm quản trị: BI Dashboard, Duyệt đơn, Kho hàng, Chi nhánh
```

---

## 📖 TÀI LIỆU KỸ THUẬT CHI TIẾT

Để xem toàn bộ đặc tả cơ sở dữ liệu 7 Collections, luồng xử lý chi tiết của 6 Providers và mô tả từng nghiệp vụ, vui lòng tham khảo file:  
👉 [**`PROJECT_DOCUMENTATION.md`**](PROJECT_DOCUMENTATION.md)
