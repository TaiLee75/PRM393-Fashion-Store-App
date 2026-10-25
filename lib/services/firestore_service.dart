import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/mock_data.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/notification_model.dart';
import '../models/message_model.dart';
import '../models/branch_model.dart';

/// Dịch vụ làm việc trực tiếp với Cloud Firestore cho toàn bộ 7 Collections + Branches
/// Tuân thủ nghiêm ngặt tính toàn vẹn dữ liệu (ACID Transaction) và chuẩn Enterprise
class FirestoreService {
  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  // Tên các Collections theo đặc tả hệ thống
  static const String colUsers = 'users';
  static const String colCategories = 'categories';
  static const String colProducts = 'products';
  static const String colCarts = 'carts';
  static const String colOrders = 'orders';
  static const String colNotifications = 'notifications';
  static const String colChats = 'chats';
  static const String colBranches = 'branches';

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

  Future<String> addCategory(CategoryModel category) async {
    final docRef = category.id.isEmpty
        ? _firestore.collection(colCategories).doc()
        : _firestore.collection(colCategories).doc(category.id);
    final toSave = category.copyWith(id: docRef.id);
    await docRef.set(toSave.toMap());
    return docRef.id;
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _firestore
        .collection(colCategories)
        .doc(category.id)
        .update(category.toMap());
  }

  /// Xóa danh mục kèm điều kiện bảo toàn: Chặn xóa nếu danh mục còn sản phẩm
  Future<void> deleteCategory(String categoryId) async {
    final productCheck = await _firestore
        .collection(colProducts)
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();

    if (productCheck.docs.isNotEmpty) {
      throw Exception(
          'Không thể xóa danh mục này vì vẫn còn sản phẩm đang thuộc danh mục.');
    }

    await _firestore.collection(colCategories).doc(categoryId).delete();
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

  /// Viết/Cập nhật đánh giá sản phẩm (Upsert theo userId + orderId trong Transaction)
  Future<void> addProductReview(String productId, ReviewModel review) async {
    final productRef = _firestore.collection(colProducts).doc(productId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(productRef);
      if (!doc.exists) return;

      final data = doc.data()!;
      final List<dynamic> currentReviews =
          List.from(data['reviews'] as List<dynamic>? ?? []);

      // Tìm xem người dùng đã đánh giá cho đơn hàng/sản phẩm này chưa để cập nhật (Upsert)
      final existingIndex = currentReviews.indexWhere((r) {
        if (r is Map) {
          final uId = r['userId'] as String? ?? '';
          final oId = r['orderId'] as String? ?? '';
          if (review.orderId.isNotEmpty) {
            return uId == review.userId && oId == review.orderId;
          } else if (review.userId.isNotEmpty) {
            return uId == review.userId;
          }
        }
        return false;
      });

      if (existingIndex >= 0) {
        currentReviews[existingIndex] = review.toMap();
      } else {
        currentReviews.add(review.toMap());
      }

      // Tính điểm rating trung bình mới
      double totalRating = 0;
      for (final r in currentReviews) {
        if (r is Map) {
          totalRating += (r['rating'] as num?)?.toDouble() ?? 5.0;
        }
      }
      final double newRating = currentReviews.isNotEmpty
          ? double.parse(
              (totalRating / currentReviews.length).toStringAsFixed(1))
          : 5.0;

      transaction.update(productRef, {
        'reviews': currentReviews,
        'rating': newRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Thêm sản phẩm mới lên Firestore (Dành cho Admin)
  Future<String> addProduct(ProductModel product) async {
    final docRef = product.id.isEmpty
        ? _firestore.collection(colProducts).doc()
        : _firestore.collection(colProducts).doc(product.id);
    final toSave = product.copyWith(id: docRef.id);
    await docRef.set(toSave.toMap());
    return docRef.id;
  }

  /// Cập nhật thông tin sản phẩm (Khóa Bẫy 17: Không ghi đè mất reviews/soldCount)
  Future<void> updateProduct(ProductModel product) async {
    final docRef = _firestore.collection(colProducts).doc(product.id);
    final existingDoc = await docRef.get();

    if (existingDoc.exists && existingDoc.data() != null) {
      final existingData = existingDoc.data()!;
      final Map<String, dynamic> updatedMap = product.toMap();

      // Nếu truyền vào reviews rỗng mà trên Firestore đã có reviews, giữ nguyên reviews và rating
      if (product.reviews.isEmpty && existingData['reviews'] != null) {
        updatedMap['reviews'] = existingData['reviews'];
        updatedMap['rating'] = existingData['rating'] ?? product.rating;
      }
      // Giữ nguyên số lượng đã bán thực tế
      if (product.soldCount == 0 && existingData['soldCount'] != null) {
        updatedMap['soldCount'] = existingData['soldCount'];
      }

      await docRef.update(updatedMap);
    } else {
      await docRef.set(product.toMap());
    }
  }

  /// Xóa sản phẩm khỏi Firestore (Dành cho Admin)
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection(colProducts).doc(productId).delete();
  }

  // ==========================================
  // 4. CARTS COLLECTION
  // ==========================================
  Stream<List<CartItemModel>> streamCart(String userId) {
    return _firestore.collection(colCarts).doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return [];
      final rawItems = doc.data()!['items'] as List<dynamic>?;
      if (rawItems == null) return [];
      final List<CartItemModel> result = [];
      for (final item in rawItems) {
        if (item is Map) {
          result.add(CartItemModel.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      return result;
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
  // 5. ORDERS COLLECTION (ACID TRANSACTION ENGINE)
  // ==========================================

  /// Tạo đơn hàng chuẩn ACID (Khóa Bẫy 6, 9, 21):
  /// - KHÔNG tự động xóa toàn bộ giỏ hàng (để CartProvider chỉ dọn món đã chọn mua).
  /// - Transaction "All Reads Before All Writes": Đọc hết ProductDoc, gom nhóm cùng productId, trừ kho SKU và cộng soldCount an toàn.
  Future<String> createOrder(OrderModel order) async {
    final docRef = _firestore.collection(colOrders).doc();
    final newOrderId = docRef.id;

    // 1. Gom nhóm danh sách CartItemModel theo productId để đọc/ghi duy nhất 1 lần
    final Map<String, List<CartItemModel>> groupedItems = {};
    for (final item in order.items) {
      groupedItems.putIfAbsent(item.productId, () => []).add(item);
    }

    await _firestore.runTransaction((transaction) async {
      // BƯỚC A: ĐỌC TẤT CẢ PRODUCT DOC TRƯỚC (All Reads Before All Writes)
      final Map<String, DocumentSnapshot<Map<String, dynamic>>> productSnapshots =
          {};
      for (final pid in groupedItems.keys) {
        final productDocRef = _firestore.collection(colProducts).doc(pid);
        final snapshot = await transaction.get(productDocRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw Exception('Sản phẩm mã "$pid" không tồn tại trong hệ thống.');
        }
        productSnapshots[pid] = snapshot;
      }

      // BƯỚC B: KIỂM TRA ĐIỀU KIỆN KINH DOANH & TỒN KHO TỪNG SKU
      final Map<String, Map<String, dynamic>> productUpdates = {};

      for (final pid in groupedItems.keys) {
        final snapshot = productSnapshots[pid]!;
        final pData = snapshot.data()!;

        final isActive = pData['isActive'] as bool? ?? true;
        if (!isActive) {
          throw Exception(
              'Sản phẩm "${pData['name']}" hiện đã tạm ngừng kinh doanh.');
        }

        int currentStock = (pData['stock'] as num?)?.toInt() ?? 99;
        final rawVariantStock = pData['variantStock'];
        final Map<String, int> variantStock = {};
        if (rawVariantStock is Map) {
          rawVariantStock.forEach((k, v) {
            if (v is num) variantStock[k.toString()] = v.toInt();
          });
        }

        int totalDeduct = 0;
        final items = groupedItems[pid]!;

        for (final item in items) {
          totalDeduct += item.quantity;
          final skuKey =
              item.color.isNotEmpty ? '${item.size}_${item.color}' : item.size;

          if (variantStock.isNotEmpty) {
            final availableSkuStock = variantStock[skuKey] ?? 0;
            if (availableSkuStock < item.quantity) {
              throw Exception(
                  'Phân loại "${item.productName} (${item.size} - ${item.color})" chỉ còn $availableSkuStock sản phẩm, không đủ số lượng đặt mua ($availableSkuStock < ${item.quantity}).');
            }
            variantStock[skuKey] = availableSkuStock - item.quantity;
          }
        }

        if (currentStock < totalDeduct) {
          throw Exception(
              'Sản phẩm "${pData['name']}" không đủ tổng tồn kho đáp ứng đơn hàng.');
        }

        final currentSold = (pData['soldCount'] as num?)?.toInt() ?? 0;

        productUpdates[pid] = {
          'stock': currentStock - totalDeduct,
          'variantStock': variantStock,
          'soldCount': currentSold + totalDeduct,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      // BƯỚC C: GHI DỮ LIỆU ĐỒNG THỜI (All Writes)
      for (final pid in productUpdates.keys) {
        final productDocRef = _firestore.collection(colProducts).doc(pid);
        transaction.update(productDocRef, productUpdates[pid]!);
      }

      // Ghi đơn hàng mới
      final orderToSave = order.copyWith(orderId: newOrderId);
      transaction.set(docRef, orderToSave.toMap());
    });

    // 2. Tạo thông báo nhận đơn cho khách hàng (Ngoài transaction)
    await createNotification(NotificationModel(
      id: '',
      userId: order.userId,
      title: 'Đặt hàng thành công! 🎉',
      body:
          'Đơn hàng #${newOrderId.substring(0, min(8, newOrderId.length))} trị giá ${order.totalPrice.toInt()}đ đã được tiếp nhận.',
      orderId: newOrderId,
      type: NotificationModel.typeOrderUpdate,
      createdAt: DateTime.now(),
    ));

    return newOrderId;
  }

  /// Hủy đơn hàng trong Transaction (Khóa Bẫy 5, 20, 21):
  /// - Kiểm tra chống hoàn kho kép (Double Restock).
  /// - Hoàn lại tồn kho chi tiết từng SKU và trừ lại soldCount.
  /// - Chuyển paymentStatus sang Refunded (nếu đã Paid hoặc PaymentSubmitted) hoặc Unpaid.
  Future<void> cancelOrder(String orderId, {String? cancelReason}) async {
    final orderDocRef = _firestore.collection(colOrders).doc(orderId);
    String customerUserId = '';

    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderDocRef);
      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw Exception('Đơn hàng không tồn tại.');
      }

      final orderData = orderSnapshot.data()!;
      customerUserId = orderData['userId'] as String? ?? '';
      final currentStatus = orderData['status'] as String? ?? 'Pending';

      // Chống hoàn kho kép
      if (currentStatus == OrderModel.statusCancelled ||
          currentStatus == OrderModel.statusReturned) {
        throw Exception('Đơn hàng đã được xử lý hủy hoặc hoàn trả trước đó.');
      }

      if (currentStatus != OrderModel.statusPending) {
        throw Exception(
            'Chỉ có thể hủy đơn hàng khi đơn còn ở trạng thái Chờ xác nhận (Pending).');
      }

      // Parse danh sách món hàng để hoàn kho
      final rawItems = orderData['items'] as List<dynamic>? ?? [];
      final List<CartItemModel> items = [];
      for (final raw in rawItems) {
        if (raw is Map) {
          items.add(CartItemModel.fromMap(Map<String, dynamic>.from(raw)));
        }
      }

      // Gom nhóm theo productId
      final Map<String, List<CartItemModel>> groupedItems = {};
      for (final item in items) {
        groupedItems.putIfAbsent(item.productId, () => []).add(item);
      }

      // Đọc toàn bộ Product Doc trước
      final Map<String, DocumentSnapshot<Map<String, dynamic>>>
          productSnapshots = {};
      for (final pid in groupedItems.keys) {
        final pRef = _firestore.collection(colProducts).doc(pid);
        final pSnap = await transaction.get(pRef);
        if (pSnap.exists && pSnap.data() != null) {
          productSnapshots[pid] = pSnap;
        }
      }

      // Hoàn lại tồn kho SKU
      for (final pid in productSnapshots.keys) {
        final pSnap = productSnapshots[pid]!;
        final pData = pSnap.data()!;
        int currentStock = (pData['stock'] as num?)?.toInt() ?? 0;
        int currentSold = (pData['soldCount'] as num?)?.toInt() ?? 0;

        final rawVariantStock = pData['variantStock'];
        final Map<String, int> variantStock = {};
        if (rawVariantStock is Map) {
          rawVariantStock.forEach((k, v) {
            if (v is num) variantStock[k.toString()] = v.toInt();
          });
        }

        int totalRestock = 0;
        final pItems = groupedItems[pid]!;
        for (final item in pItems) {
          totalRestock += item.quantity;
          final skuKey =
              item.color.isNotEmpty ? '${item.size}_${item.color}' : item.size;
          if (variantStock.containsKey(skuKey)) {
            variantStock[skuKey] = (variantStock[skuKey] ?? 0) + item.quantity;
          }
        }

        final pRef = _firestore.collection(colProducts).doc(pid);
        transaction.update(pRef, {
          'stock': currentStock + totalRestock,
          'variantStock': variantStock,
          'soldCount': max(0, currentSold - totalRestock),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Xác định trạng thái thanh toán sau khi hủy
      final currentPaymentStatus =
          orderData['paymentStatus'] as String? ?? OrderModel.paymentUnpaid;
      final newPaymentStatus = (currentPaymentStatus == OrderModel.paymentPaid ||
              currentPaymentStatus == OrderModel.paymentSubmitted)
          ? OrderModel.paymentRefunded
          : OrderModel.paymentUnpaid;

      // Cập nhật trạng thái đơn hàng
      transaction.update(orderDocRef, {
        'status': OrderModel.statusCancelled,
        'paymentStatus': newPaymentStatus,
        'cancelReason': cancelReason ?? 'Khách hàng yêu cầu hủy đơn',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (customerUserId.isNotEmpty) {
      await createNotification(NotificationModel(
        id: '',
        userId: customerUserId,
        title: 'Đơn hàng đã hủy ❌',
        body:
            'Đơn hàng #${orderId.substring(0, min(8, orderId.length))} đã được hủy thành công.',
        orderId: orderId,
        type: NotificationModel.typeOrderUpdate,
        createdAt: DateTime.now(),
      ));
    }
  }

  /// Khách hàng gửi yêu cầu Đổi/Trả hàng (Khi đơn đã giao thành công Delivered)
  Future<void> requestReturnOrder(String orderId,
      {required String returnReason}) async {
    await _firestore.collection(colOrders).doc(orderId).update({
      'status': OrderModel.statusReturnRequested,
      'returnReason': returnReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin chấp thuận Đổi/Trả hàng trong Transaction (Khóa Bẫy 5, 20, 21):
  /// - Hoàn lại tồn kho SKU, tự động chuyển paymentStatus sang Refunded.
  Future<void> approveReturnOrder(String orderId) async {
    final orderDocRef = _firestore.collection(colOrders).doc(orderId);
    String customerUserId = '';

    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderDocRef);
      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw Exception('Đơn hàng không tồn tại.');
      }

      final orderData = orderSnapshot.data()!;
      customerUserId = orderData['userId'] as String? ?? '';
      final currentStatus = orderData['status'] as String? ?? '';

      if (currentStatus == OrderModel.statusReturned) {
        throw Exception('Đơn hàng này đã được hoàn trả trước đó.');
      }

      if (currentStatus != OrderModel.statusReturnRequested) {
        throw Exception('Đơn hàng không ở trạng thái yêu cầu đổi trả hàng.');
      }

      // Parse danh sách món hàng để hoàn kho
      final rawItems = orderData['items'] as List<dynamic>? ?? [];
      final List<CartItemModel> items = [];
      for (final raw in rawItems) {
        if (raw is Map) {
          items.add(CartItemModel.fromMap(Map<String, dynamic>.from(raw)));
        }
      }

      final Map<String, List<CartItemModel>> groupedItems = {};
      for (final item in items) {
        groupedItems.putIfAbsent(item.productId, () => []).add(item);
      }

      final Map<String, DocumentSnapshot<Map<String, dynamic>>>
          productSnapshots = {};
      for (final pid in groupedItems.keys) {
        final pRef = _firestore.collection(colProducts).doc(pid);
        final pSnap = await transaction.get(pRef);
        if (pSnap.exists && pSnap.data() != null) {
          productSnapshots[pid] = pSnap;
        }
      }

      // Hoàn lại kho SKU
      for (final pid in productSnapshots.keys) {
        final pSnap = productSnapshots[pid]!;
        final pData = pSnap.data()!;
        int currentStock = (pData['stock'] as num?)?.toInt() ?? 0;
        int currentSold = (pData['soldCount'] as num?)?.toInt() ?? 0;

        final rawVariantStock = pData['variantStock'];
        final Map<String, int> variantStock = {};
        if (rawVariantStock is Map) {
          rawVariantStock.forEach((k, v) {
            if (v is num) variantStock[k.toString()] = v.toInt();
          });
        }

        int totalRestock = 0;
        final pItems = groupedItems[pid]!;
        for (final item in pItems) {
          totalRestock += item.quantity;
          final skuKey =
              item.color.isNotEmpty ? '${item.size}_${item.color}' : item.size;
          if (variantStock.containsKey(skuKey)) {
            variantStock[skuKey] = (variantStock[skuKey] ?? 0) + item.quantity;
          }
        }

        final pRef = _firestore.collection(colProducts).doc(pid);
        transaction.update(pRef, {
          'stock': currentStock + totalRestock,
          'variantStock': variantStock,
          'soldCount': max(0, currentSold - totalRestock),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Cập nhật trạng thái hoàn tiền và hoàn đơn
      transaction.update(orderDocRef, {
        'status': OrderModel.statusReturned,
        'paymentStatus': OrderModel.paymentRefunded,
        'returnedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (customerUserId.isNotEmpty) {
      await createNotification(NotificationModel(
        id: '',
        userId: customerUserId,
        title: 'Đổi/Trả hàng thành công 🔄',
        body:
            'Yêu cầu hoàn trả đơn hàng #${orderId.substring(0, min(8, orderId.length))} đã được duyệt và xử lý hoàn tiền.',
        orderId: orderId,
        type: NotificationModel.typeOrderUpdate,
        createdAt: DateTime.now(),
      ));
    }
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

  /// Cập nhật trạng thái giao hàng (Khóa Bẫy 20: Delivered -> Tự động chuyển paymentStatus = Paid)
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    required String userId,
  }) async {
    final Map<String, dynamic> updateData = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    String title = 'Cập nhật đơn hàng';
    String body = 'Đơn hàng #$orderId hiện đang ở trạng thái: $status.';

    if (status == OrderModel.statusDelivering) {
      title = 'Đơn hàng đang được giao 🚚';
      body = 'Đơn hàng #$orderId đang trên đường giao đến bạn.';
      updateData['deliveringAt'] = FieldValue.serverTimestamp();
    } else if (status == OrderModel.statusDelivered) {
      title = 'Giao hàng thành công 🎉';
      body = 'Đơn hàng #$orderId đã được giao thành công. Cảm ơn bạn!';
      updateData['deliveredAt'] = FieldValue.serverTimestamp();
      // Khóa Bẫy 20: Giao COD thành công coi như đã thu tiền mặt -> Paid
      updateData['paymentStatus'] = OrderModel.paymentPaid;
    }

    await _firestore.collection(colOrders).doc(orderId).update(updateData);

    await createNotification(NotificationModel(
      id: '',
      userId: userId,
      title: title,
      body: body,
      orderId: orderId,
      type: NotificationModel.typeOrderUpdate,
      createdAt: DateTime.now(),
    ));
  }

  /// Chỉnh sửa địa chỉ nhận hàng (Khi đơn còn Pending)
  Future<void> updateOrderShippingAddress({
    required String orderId,
    required String newAddress,
    required String phone,
    required String recipientName,
  }) async {
    final docRef = _firestore.collection(colOrders).doc(orderId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Đơn hàng không tồn tại.');
    final currentStatus = doc.data()?['status'] as String? ?? 'Pending';
    if (currentStatus != OrderModel.statusPending) {
      throw Exception(
          'Chỉ có thể chỉnh sửa thông tin khi đơn còn Chờ xác nhận (Pending).');
    }

    await docRef.update({
      'shippingAddress': newAddress,
      'phone': phone,
      'userName': recipientName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================
  // 6. VIETQR RECONCILIATION METHODS (ĐỐI SOÁT CHUYỂN KHOẢN)
  // ==========================================

  /// Khách hàng bấm "Tôi đã chuyển khoản"
  Future<void> confirmPaymentSubmitted(String orderId,
      {String? transactionRef}) async {
    final Map<String, dynamic> data = {
      'paymentStatus': OrderModel.paymentSubmitted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (transactionRef != null && transactionRef.isNotEmpty) {
      data['transactionRef'] = transactionRef;
    }

    await _firestore.collection(colOrders).doc(orderId).update(data);
  }

  /// Admin duyệt thanh toán VietQR thành công
  Future<void> confirmPaymentPaid(String orderId) async {
    final orderDocRef = _firestore.collection(colOrders).doc(orderId);
    final doc = await orderDocRef.get();
    final customerUserId = doc.data()?['userId'] as String? ?? '';

    await orderDocRef.update({
      'paymentStatus': OrderModel.paymentPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (customerUserId.isNotEmpty) {
      await createNotification(NotificationModel(
        id: '',
        userId: customerUserId,
        title: 'Thanh toán thành công! ✅',
        body:
            'Giao dịch chuyển khoản cho đơn hàng #${orderId.substring(0, min(8, orderId.length))} đã được shop xác nhận.',
        orderId: orderId,
        type: NotificationModel.typeOrderUpdate,
        createdAt: DateTime.now(),
      ));
    }
  }

  /// Admin từ chối thanh toán VietQR (sai mã, thiếu tiền)
  Future<void> rejectPaymentSubmitted(String orderId, {String? reason}) async {
    final orderDocRef = _firestore.collection(colOrders).doc(orderId);
    final doc = await orderDocRef.get();
    final customerUserId = doc.data()?['userId'] as String? ?? '';

    await orderDocRef.update({
      'paymentStatus': OrderModel.paymentUnpaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (customerUserId.isNotEmpty) {
      await createNotification(NotificationModel(
        id: '',
        userId: customerUserId,
        title: 'Chưa nhận được thanh toán ⚠️',
        body: reason ??
            'Shop chưa nhận được thanh toán cho đơn #${orderId.substring(0, min(8, orderId.length))}. Vui lòng kiểm tra lại.',
        orderId: orderId,
        type: NotificationModel.typeOrderUpdate,
        createdAt: DateTime.now(),
      ));
    }
  }

  // ==========================================
  // 7. NOTIFICATIONS COLLECTION
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
  // 8. CHATS COLLECTION (Sub-collection messages)
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
    bool isFromAdmin = false,
  }) async {
    final chatDocRef = _firestore.collection(colChats).doc(customerId);
    final messagesRef = chatDocRef.collection('messages');

    final docRef = messagesRef.doc();
    final toSave = message.copyWith(id: docRef.id);
    await docRef.set(toSave.toMap());

    // Cập nhật document cha kèm bộ đếm tin nhắn chưa đọc
    final updateData = <String, dynamic>{
      'customerId': customerId,
      'userName': customerName ?? 'Khách hàng',
      'lastMessage': message.text,
      'updatedAt': Timestamp.fromDate(message.createdAt),
    };

    if (isFromAdmin) {
      updateData['unreadByCustomer'] = FieldValue.increment(1);
    } else {
      updateData['unreadByAdmin'] = FieldValue.increment(1);
    }

    await chatDocRef.set(updateData, SetOptions(merge: true));
  }

  /// Đánh dấu Admin đã đọc tin nhắn của khách hàng
  Future<void> markChatAsReadByAdmin(String customerId) async {
    await _firestore.collection(colChats).doc(customerId).set({
      'unreadByAdmin': 0,
    }, SetOptions(merge: true));
  }

  /// Đánh dấu Khách hàng đã đọc tin nhắn của Admin
  Future<void> markChatAsReadByCustomer(String customerId) async {
    await _firestore.collection(colChats).doc(customerId).set({
      'unreadByCustomer': 0,
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
  // 9. BRANCHES COLLECTION (Chi nhánh cửa hàng)
  // ==========================================
  Stream<List<BranchModel>> streamBranches() {
    return _firestore.collection(colBranches).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BranchModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<List<BranchModel>> getBranches() async {
    final snapshot = await _firestore.collection(colBranches).get();
    return snapshot.docs
        .map((doc) => BranchModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> addBranch(BranchModel branch) async {
    final docRef = branch.id.isEmpty
        ? _firestore.collection(colBranches).doc()
        : _firestore.collection(colBranches).doc(branch.id);
    final toSave = branch.copyWith(id: docRef.id);
    await docRef.set(toSave.toMap());
    return docRef.id;
  }

  Future<void> updateBranch(BranchModel branch) async {
    await _firestore
        .collection(colBranches)
        .doc(branch.id)
        .update(branch.toMap());
  }

  Future<void> deleteBranch(String branchId) async {
    await _firestore.collection(colBranches).doc(branchId).delete();
  }

  // ==========================================
  // 🚀 SEED DATA MẪU (Khóa Bẫy 18: Nạp đầy đủ thông số mới với merge)
  // ==========================================
  Future<void> seedInitialData() async {
    final batch = _firestore.batch();

    // 1. Đẩy 4 Danh mục
    for (final cat in mockCategories) {
      final docRef = _firestore.collection(colCategories).doc(cat['id']);
      batch.set(
        docRef,
        {
          'id': cat['id'],
          'name': cat['name'],
          'iconUrl': cat['iconUrl'],
        },
        SetOptions(merge: true),
      );
    }

    // 2. Đẩy 8 Sản phẩm mẫu chuẩn Enterprise
    for (final prod in mockProducts) {
      final docRef = _firestore.collection(colProducts).doc(prod['id']);
      final rawReviews = prod['reviews'] as List<dynamic>? ?? [];
      final formattedReviews = rawReviews.map((r) {
        DateTime date = DateTime.now();
        if (r['createdAt'] != null) {
          date = DateTime.tryParse(r['createdAt'].toString()) ?? DateTime.now();
        }
        return {
          'userId': r['userId'] ?? '',
          'userName': r['userName'] ?? 'Khách hàng',
          'rating': r['rating'] ?? 5,
          'comment': r['comment'] ?? '',
          'createdAt': Timestamp.fromDate(date),
          'orderId': r['orderId'] ?? '',
          'variantInfo': r['variantInfo'] ?? '',
          'isVerifiedPurchase': r['isVerifiedPurchase'] ?? true,
        };
      }).toList();

      batch.set(
        docRef,
        {
          'id': prod['id'],
          'name': prod['name'],
          'categoryId': prod['categoryId'],
          'price': prod['price'],
          'originalPrice': prod['originalPrice'],
          'description': prod['description'],
          'imageUrls': prod['imageUrls'],
          'sizes': prod['sizes'],
          'colors': prod['colors'],
          'stock': prod['stock'] ?? 99,
          'variantStock': prod['variantStock'] ?? {},
          'soldCount': prod['soldCount'] ?? 0,
          'isActive': prod['isActive'] ?? true,
          'rating': prod['rating'],
          'reviews': formattedReviews,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    // 3. Đẩy 2 Chi nhánh cửa hàng mẫu
    final defaultBranches = [
      BranchModel(
        id: 'branch_fpt_danang',
        name: 'Chi nhánh 1 - FPT University Da Nang',
        address: 'Khu đô thị FPT City, Ngũ Hành Sơn, Đà Nẵng',
        latitude: 15.9689,
        longitude: 108.2608,
        phone: '0236 730 0999',
        createdAt: DateTime.now(),
      ),
      BranchModel(
        id: 'branch_flagship_bachdang',
        name: 'Chi nhánh 2 - Fashion Flagship Store',
        address: 'Đường Bạch Đằng, Quận Hải Châu, Đà Nẵng',
        latitude: 16.0678,
        longitude: 108.2248,
        phone: '1900 1234',
        createdAt: DateTime.now(),
      ),
    ];

    for (final branch in defaultBranches) {
      final docRef = _firestore.collection(colBranches).doc(branch.id);
      batch.set(docRef, branch.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
  }
}
