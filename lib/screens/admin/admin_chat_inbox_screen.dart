import 'dart:math';
import '../../core/utils/app_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/message_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../home/product_detail_screen.dart';
import '../orders/order_detail_screen.dart';

/// Màn hình Hộp thư CSKH của Admin (Admin Chat Inbox)
class AdminChatInboxScreen extends StatefulWidget {
  const AdminChatInboxScreen({super.key});

  @override
  State<AdminChatInboxScreen> createState() => _AdminChatInboxScreenState();
}

class _AdminChatInboxScreenState extends State<AdminChatInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().listenAdminChatRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final rooms = chatProvider.adminChatRooms;

    final unreadTotal = chatProvider.unreadAdminTotal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'HỘP THƯ CSKH & TƯ VẤN',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppColors.white,
              ),
            ),
            if (unreadTotal > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadTotal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: rooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hiện chưa có yêu cầu tư vấn nào từ khách hàng',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final room = rooms[index];
                final customerId = room['customerId'] as String? ?? '';
                final userName = room['userName'] as String? ?? 'Khách hàng';
                final lastMessage = room['lastMessage'] as String? ?? '';
                final updatedAt = room['updatedAt'];

                DateTime? date;
                if (updatedAt is Timestamp) {
                  date = updatedAt.toDate();
                } else if (updatedAt is String) {
                  date = DateTime.tryParse(updatedAt);
                }

                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      child: Text(
                        userName.isNotEmpty
                            ? userName.substring(0, 1).toUpperCase()
                            : 'K',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (date != null)
                          Text(
                            AppFormatters.formatTimeOnly(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        lastMessage.isNotEmpty
                            ? lastMessage
                            : 'Bắt đầu cuộc trò chuyện...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((room['unreadByAdmin'] as num?)?.toInt() != null &&
                            (room['unreadByAdmin'] as num) > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${room['unreadByAdmin']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminChatDetailScreen(
                            customerId: customerId,
                            customerName: userName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

/// Màn hình Chat chi tiết dành cho Admin trả lời Khách hàng
class AdminChatDetailScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String? initialOrderId;
  final num? initialOrderTotalPrice;
  final String? initialProductId;
  final String? initialProductName;
  final String? initialProductImageUrl;

  const AdminChatDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.initialOrderId,
    this.initialOrderTotalPrice,
    this.initialProductId,
    this.initialProductName,
    this.initialProductImageUrl,
  });

  @override
  State<AdminChatDetailScreen> createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<AdminChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Đính kèm hiện tại đang chờ gửi
  String? _pendingOrderId;
  num? _pendingOrderTotalPrice;
  String? _pendingProductId;
  String? _pendingProductName;
  String? _pendingProductImageUrl;

  @override
  void initState() {
    super.initState();
    _pendingOrderId = widget.initialOrderId;
    _pendingOrderTotalPrice = widget.initialOrderTotalPrice;
    _pendingProductId = widget.initialProductId;
    _pendingProductName = widget.initialProductName;
    _pendingProductImageUrl = widget.initialProductImageUrl;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().listenMessages(widget.customerId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend({String? customText}) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty && _pendingOrderId == null && _pendingProductId == null) {
      return;
    }

    _textController.clear();

    final orderIdToSend = _pendingOrderId;
    final orderTotalToSend = _pendingOrderTotalPrice;
    final prodIdToSend = _pendingProductId;
    final prodNameToSend = _pendingProductName;
    final prodImageToSend = _pendingProductImageUrl;

    if (mounted) {
      setState(() {
        _pendingOrderId = null;
        _pendingOrderTotalPrice = null;
        _pendingProductId = null;
        _pendingProductName = null;
        _pendingProductImageUrl = null;
      });
    }

    await context.read<ChatProvider>().sendMessage(
          customerId: widget.customerId,
          text: text.isNotEmpty ? text : 'Xin hỗ trợ thông tin mục đính kèm này',
          senderId: 'shop_admin',
          customerName: widget.customerName,
          orderId: orderIdToSend,
          orderTotalPrice: orderTotalToSend,
          productId: prodIdToSend,
          productName: prodNameToSend,
          productImageUrl: prodImageToSend,
        );

    _scrollToBottom();
  }

  void _navigateToOrder(String orderId) {
    final orderProvider = context.read<OrderProvider>();
    OrderModel? matchedOrder;
    for (final o in orderProvider.allOrders) {
      if (o.orderId == orderId) {
        matchedOrder = o;
        break;
      }
    }
    if (matchedOrder == null) {
      for (final o in orderProvider.userOrders) {
        if (o.orderId == orderId) {
          matchedOrder = o;
          break;
        }
      }
    }

    if (matchedOrder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(initialOrder: matchedOrder!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang tải dữ liệu đơn hàng #$orderId...'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _navigateToProduct(String? productId, String? productName) {
    if (productId == null && productName == null) return;
    final productProvider = context.read<ProductProvider>();
    ProductModel? matchedProduct;

    for (final p in productProvider.allProducts) {
      if (p.id == productId ||
          (productName != null && p.name == productName)) {
        matchedProduct = p;
        break;
      }
    }

    if (matchedProduct != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: matchedProduct!.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sản phẩm hiện đang được cập nhật thông tin.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildPendingAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.primaryLight.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(
            _pendingOrderId != null
                ? Icons.receipt_long
                : Icons.shopping_bag_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pendingOrderId != null
                  ? 'Đính kèm đơn hàng #${_pendingOrderId!.substring(0, min(8, _pendingOrderId!.length))} (${AppFormatters.formatCurrency(_pendingOrderTotalPrice ?? 0)})'
                  : 'Đính kèm sản phẩm: ${_pendingProductName ?? "Sản phẩm thời trang"}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _pendingOrderId = null;
                _pendingOrderTotalPrice = null;
                _pendingProductId = null;
                _pendingProductName = null;
                _pendingProductImageUrl = null;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messages;
    final auth = context.watch<AuthProvider>();
    final adminId = auth.userId.isNotEmpty ? auth.userId : 'admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customerName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const Text(
              'Hỗ trợ & tư vấn khách hàng trực tuyến',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Danh sách tin nhắn
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có tin nhắn trong cuộc hội thoại này',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      // Tin nhắn của Admin (shop) gửi đi
                      final isShop = msg.senderId == 'shop_admin' ||
                          msg.senderId == 'admin' ||
                          (msg.senderId == adminId && adminId != widget.customerId);

                      return _buildMessageBubble(msg, isShop);
                    },
                  ),
          ),

          // Thẻ đính kèm chờ gửi (nếu có)
          if (_pendingOrderId != null || _pendingProductId != null)
            _buildPendingAttachmentPreview(),

          // Khung nhập tin nhắn
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Nhập câu trả lời tư vấn...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isShop) {
    return Align(
      alignment: isShop ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isShop ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isShop ? 12 : 2),
            bottomRight: Radius.circular(isShop ? 2 : 12),
          ),
          border: isShop ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isShop ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isShop)
              const Text(
                'TƯ VẤN VIÊN (BẠN)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    widget.customerName.isNotEmpty
                        ? widget.customerName.toUpperCase()
                        : 'KHÁCH HÀNG',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),

            // THẺ ĐÍNH KÈM ĐƠN HÀNG (NẾU CÓ)
            if (msg.hasOrderAttachment) ...[
              InkWell(
                onTap: () => _navigateToOrder(msg.orderId!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isShop
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.ultraLightGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isShop ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 20,
                        color: isShop ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đơn hàng #${msg.orderId!.length > 8 ? msg.orderId!.substring(0, 8) : msg.orderId}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isShop ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            if (msg.orderTotalPrice != null)
                              Text(
                                AppFormatters.formatCurrency(
                                  msg.orderTotalPrice!,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isShop
                                      ? Colors.white70
                                      : AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: isShop ? Colors.white60 : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // THẺ ĐÍNH KÈM SẢN PHẨM (NẾU CÓ)
            if (msg.hasProductAttachment) ...[
              InkWell(
                onTap: () =>
                    _navigateToProduct(msg.productId, msg.productName),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isShop
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.ultraLightGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isShop ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.productImageUrl != null &&
                          msg.productImageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AppImage(
                            imageUrl: msg.productImageUrl!,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 38,
                              height: 38,
                              color: Colors.grey.shade200,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 38,
                              height: 38,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 18),
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.checkroom,
                          size: 22,
                          color: isShop ? Colors.white : AppColors.primary,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          msg.productName ?? 'Sản phẩm thời trang',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isShop ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: isShop ? Colors.white60 : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            Text(
              msg.text,
              style: TextStyle(
                color: isShop ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppFormatters.formatTimeOnly(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isShop ? Colors.white60 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
