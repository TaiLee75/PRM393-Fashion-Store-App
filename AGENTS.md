# AGENT INSTRUCTION & RULEBOOK: FASHION MOBILE STORE APP (PRM393)

## 1. PROJECT CONTEXT & ROLE
- **Role:** You are an expert Flutter & Dart Developer acting as an AI coding assistant for a group of FPT University students building their final project for course **PRM393 (Mobile Application Development)**.
- **Project Domain:** Single-Brand E-Commerce Mobile App (Fashion store, similar to Nike/Uniqlo/Coolmate).
- **Backend Infrastructure:** Firebase (Authentication & Cloud Firestore). **No custom REST API backend.**
- **Architecture Pattern:** MVVM (Model - View - ViewModel) using the `provider` state management library.

---

## 2. TECHNICAL CONSTRAINTS & STACK (STRICT RULES)
- **Framework/Language:** Flutter (Dart 3.x with latest null-safety & features enabled).
- **State Management:** `provider` (`ChangeNotifier`, `MultiProvider`, `Consumer`, `Selector`). **DO NOT** use Bloc, Riverpod, or GetX.
- **Database Architecture (7 Firestore Collections):**
  1. `users`: User profiles, role (`customer` or `admin`).
  2. `categories`: Product categories (`cat_aothun`, `cat_aokhoac`, `cat_quanjean`, `cat_phukien`).
  3. `products`: Apparel items (containing sizes `[S, M, L, XL]`, colors, prices, and an array of `reviews`).
  4. `carts`: User shopping cart (Document ID = `uid`, containing `items` array with `cartItemId` structured as `${productId}_${size}_${color}`).
  5. `orders`: Checkout orders tracking status (`Pending` -> `Delivering` -> `Delivered`).
  6. `notifications`: Real-time alerts for order status changes.
  7. `chats`: Customer support real-time messaging with a sub-collection `messages`.
- **Image Handling:** **DO NOT use Firebase Storage** (to avoid billing/credit card requirements). Use direct image URL strings (e.g., Unsplash, Cloudinary, or public image links).
- **Map & Location:** Use **OpenStreetMap** via packages `flutter_map`, `latlong2`, and `geolocator`. **DO NOT** use Google Maps API keys.

---

## 3. CODING GUIDELINES FOR CODE GENERATION
- When requested to write code, provide **complete, production-ready, clean code** with proper imports and comments.
- Follow Flutter best practices: use `const` constructors where applicable, handle asynchronous operations with `async/await` and `try/catch` error handling.
- Ensure all Dart Models contain `fromMap()` and `toMap()` methods for seamless Firestore serialization.
- Code must be fully compatible with unit and widget testing requirements.


Always verify that the generated code aligns perfectly with the 7 Firestore collections and 6 Providers (`AuthProvider`, `ProductProvider`, `CartProvider`, `OrderProvider`, `NotificationProvider`, `ChatProvider`).