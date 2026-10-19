# 🛍️ PRM393 - Mobile Application Development (Flutter)
## Đề tài: Ứng dụng Mua sắm Thời trang Trực tuyến (Fashion Mobile Store App)
**Trường Đại học FPT - Đồ án cuối kỳ môn PRM393**

---

---

### 🚀 Tech Stack & Architecture
- **Framework:** Flutter SDK & Dart
- **State Management:** Provider (`ChangeNotifier`) theo mô hình MVVM
- **Backend / Database:** Firebase (Authentication, Cloud Firestore)
- **Map & Location:** OpenStreetMap (`flutter_map`, `geolocator`)

---

### 📂 Cấu trúc thư mục dự án
Tham khảo file đặc tả chi tiết `Requirement_FashionApp_PRM393.md` nằm tại thư mục gốc của repository này.

```text
lib/
├── core/         # Constants, App Colors, Formatters
├── models/       # 7 Dart Models khớp với Firestore Collections
├── services/     # FirebaseAuth & Cloud Firestore Services
├── providers/    # 6 ViewModels (State Management)
└── screens/      # Toàn bộ các màn hình giao diện của app
⚙️ Hướng dẫn chạy dự án cho thành viên nhóm
Clone repository này về máy:

Bash
git clone https://github.com/TaiLee75/PRM393-Fashion-Store-App.git
Xin file google-services.json từ nhóm trưởng và bỏ vào thư mục: android/app/

Cài đặt các thư viện phụ thuộc:

Bash
flutter pub get
Chạy ứng dụng trên máy ảo hoặc thiết bị thật:

Bash
flutter run