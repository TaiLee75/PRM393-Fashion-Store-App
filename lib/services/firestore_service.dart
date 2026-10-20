import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/mock_data.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/notification_model.dart';
import '../models/message_model.dart';

/// Dịch vụ làm việc trực tiếp với Cloud Firestore cho toàn bộ 7 Collections
class FirestoreService {
  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  // Tên 7 Collections theo đặc tả hệ thống
  static const String colUsers = 'users';
  static const String colCategories = 'categories';
  static const String colProducts = 'products';
  static const String colCarts = 'carts';
  static const String colOrders = 'orders';
  static const String colNotifications = 'notifications';
  static const String colChats = 'chats';

  // ==========================================
  // 1. USERS COLLECTION
  // ==========================================
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection(colUsers).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore
        .collection(colUsers)
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection(colUsers).doc(uid).update(data);
  }

  // ==========================================
  // 2. CATEGORIES COLLECTION
  // ==========================================
  Stream<List<CategoryModel>> streamCategories() {
    return _firestore.collection(colCategories).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<List<CategoryModel>> getCategories() async {
    final snapshot = await _firestore.collection(colCategories).get();
    return snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ==========================================
  // 3. PRODUCTS COLLECTION
  // ==========================================
  Stream<List<ProductModel>> streamProducts() {
    return _firestore.collection(colProducts).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<List<ProductModel>> getProducts({String? categoryId}) async {
    Query query = _firestore.collection(colProducts);
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) =>
            ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<ProductModel?> getProductById(String id) async {
    final doc = await _firestore.collection(colProducts).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ProductModel.fromMap(doc.data()!, doc.id);
  }

  /// Viết đánh giá sản phẩm sử dụng FieldValue.arrayUnion
  Future<void> addProductReview(String productId, ReviewModel review) async {
    final productRef = _firestore.collection(colProducts).doc(productId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(productRef);
      if (!doc.exists) return;

      final data = doc.data()!;
      final currentReviews = (data['reviews'] as List<dynamic>?) ?? [];
      final List<dynamic> updatedReviews = List.from(currentReviews)
        ..add(review.toMap());

      // Tính điểm rating trung bình mới
      double totalRating = 0;
      for (var r in updatedReviews) {
        if (r is Map<String, dynamic>) {
          totalRating += (r['rating'] as num?)?.toDouble() ?? 5.0;
        }
      }
      final double newRating = updatedReviews.isNotEmpty
          ? double.parse((totalRating / updatedReviews.length).toStringAsFixed(1))
          : 5.0;

      transaction.update(productRef, {
        'reviews': FieldValue.arrayUnion([review.toMap()]),
        'rating': newRating,
      });
    });
  }

  // ==========================================
  // 4. CARTS COLLECTION
  // ==========================================
  Stream<List<CartItemModel>> streamCart(String userId) {
    return _firestore.collection(colCarts).doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return [];
      final rawItems = doc.data()!['items'] as List<dynamic>?;
      if (rawItems == null) return [];
      return rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => CartItemModel.fromMap(item))
          .toList();
    });
  }

  Future<void> saveCart(String userId, List<CartItemModel> items) async {
    await _firestore.collection(colCarts).doc(userId).set({
      'items': items.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearCart(String userId) async {
    await _firestore.collection(colCarts).doc(userId).set({
      'items': [],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================
  // 5. ORDERS COLLECTION
  // ==========================================
  Future<String> createOrder(OrderModel order) async {
    final docRef = _firestore.collection(colOrders).doc();
    final newOrderId = docRef.id;

    final orderToSave = order.copyWith(orderId: newOrderId);
    await docRef.set(orderToSave.toMap());

    // Tự động tạo một notification cho người dùng
    await createNotification(NotificationModel(
      id: '',
      userId: order.userId,
      title: 'Đặt hàng thành công!',
      body: 'Đơn hàng #${newOrderId.substring(0, 8)} trị giá ${order.totalPrice} đã được tiếp nhận.',
      createdAt: DateTime.now(),
    ));

    // Xóa giỏ hàng sau khi đặt thành công
    await clearCart(order.userId);

    return newOrderId;
  }

  Stream<List<OrderModel>> streamUserOrders(String userId) {
    return _firestore
        .collection(colOrders)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<OrderModel>> streamAllOrders() {
    return _firestore.collection(colOrders).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    required String userId,
  }) async {
    await _firestore.collection(colOrders).doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Tạo thông báo khi shop cập nhật trạng thái đơn
    String title = 'Cập nhật đơn hàng';
    String body = 'Đơn hàng #$orderId hiện đang ở trạng thái: $status.';
    if (status == 'Delivering') {
      title = 'Đơn hàng đang được giao 🚚';
      body = 'Đơn hàng #$orderId đang trên đường giao đến bạn.';
    } else if (status == 'Delivered') {
      title = 'Giao hàng thành công 🎉';
      body = 'Đơn hàng #$orderId đã được giao thành công. Cảm ơn bạn!';
    }

    await createNotification(NotificationModel(
      id: '',
      userId: userId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    ));
  }

  // ==========================================
  // 6. NOTIFICATIONS COLLECTION
  // ==========================================
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _firestore
        .collection(colNotifications)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> createNotification(NotificationModel notification) async {
    final docRef = _firestore.collection(colNotifications).doc();
    final toSave = notification.copyWith(id: docRef.id);
    await docRef.set(toSave.toMap());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection(colNotifications)
        .doc(notificationId)
        .update({'isRead': true});
  }

  // ==========================================
  // 7. CHATS COLLECTION (Sub-collection messages)
  // ==========================================
  Stream<List<MessageModel>> streamMessages(String customerId) {
    return _firestore
        .collection(colChats)
        .doc(customerId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> sendMessage({
    required String customerId,
    required MessageModel message,
    String? customerName,
  }) async {
    final messagesRef = _firestore
        .collection(colChats)
        .doc(customerId)
        .collection('messages');

    final docRef = messagesRef.doc();
    final toSave = message.copyWith(id: docRef.id);
    await docRef.set(toSave.toMap());

    // Cập nhật document chat cha để hiển thị trên danh sách chat của Admin
    await _firestore.collection(colChats).doc(customerId).set({
      'customerId': customerId,
      'userName': customerName ?? 'Khách hàng',
      'lastMessage': message.text,
      'updatedAt': Timestamp.fromDate(message.createdAt),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> streamAllChats() {
    return _firestore
        .collection(colChats)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ==========================================
  // 🚀 SEED DATA MẪU (Cho nút bấm trên ShopAdminScreen)
  // ==========================================
  Future<void> seedInitialData() async {
    final batch = _firestore.batch();

    // 1. Đẩy 4 Danh mục
    for (final cat in mockCategories) {
      final docRef = _firestore.collection(colCategories).doc(cat['id']);
      batch.set(docRef, {
        'id': cat['id'],
        'name': cat['name'],
        'iconUrl': cat['iconUrl'],
      });
    }

    // 2. Đẩy 8 Sản phẩm
    for (final prod in mockProducts) {
      final docRef = _firestore.collection(colProducts).doc(prod['id']);
      // Chuẩn hóa review nếu có
      final rawReviews = prod['reviews'] as List<dynamic>? ?? [];
      final formattedReviews = rawReviews.map((r) {
        DateTime date = DateTime.now();
        if (r['createdAt'] != null) {
          date = DateTime.tryParse(r['createdAt'].toString()) ?? DateTime.now();
        }
        return {
          'userName': r['userName'] ?? 'Khách hàng',
          'rating': r['rating'] ?? 5,
          'comment': r['comment'] ?? '',
          'createdAt': Timestamp.fromDate(date),
        };
      }).toList();

      batch.set(docRef, {
        'id': prod['id'],
        'name': prod['name'],
        'categoryId': prod['categoryId'],
        'price': prod['price'],
        'description': prod['description'],
        'imageUrls': prod['imageUrls'],
        'sizes': prod['sizes'],
        'colors': prod['colors'],
        'rating': prod['rating'],
        'reviews': formattedReviews,
      });
    }

    await batch.commit();
  }
}
