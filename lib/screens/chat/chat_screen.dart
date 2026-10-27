import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
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

/// Màn hình Nhắn tin tư vấn trực tuyến (Real-time Chat với Shop) chuẩn Enterprise
class ChatScreen extends StatefulWidget {
  final bool isStandalone;
  final String? initialOrderId;
  final num? initialOrderTotalPrice;
  final String? initialProductId;
  final String? initialProductName;
  final String? initialProductImageUrl;

  const ChatScreen({
    super.key,
    this.isStandalone = false,
    this.initialOrderId,
    this.initialOrderTotalPrice,
    this.initialProductId,
    this.initialProductName,
    this.initialProductImageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // Đính kèm hiện tại đang chờ gửi
  String? _pendingOrderId;
  num? _pendingOrderTotalPrice;
  String? _pendingProductId;
  String? _pendingProductName;
  String? _pendingProductImageUrl;

  // Danh sách câu hỏi gợi ý nhanh (Quick Replies)
  static const List<String> _quickReplies = [
    'Tư vấn chọn size theo chiều cao & cân nặng',
    'Kiểm tra tiến độ đơn hàng',
    'Chính sách đổi trả sản phẩm trong 7 ngày',
    'Hỗ trợ thanh toán VietQR Napas247',
    'Chất liệu áo và cách giặt ủi',
  ];

  @override
  void initState() {
    super.initState();
    _pendingOrderId = widget.initialOrderId;
    _pendingOrderTotalPrice = widget.initialOrderTotalPrice;
    _pendingProductId = widget.initialProductId;
    _pendingProductName = widget.initialProductName;
    _pendingProductImageUrl = widget.initialProductImageUrl;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final customerId =
          auth.userId.isNotEmpty ? auth.userId : 'guest_customer';
      context.read<ChatProvider>().listenMessages(customerId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage({String? customText}) async {
    final text = (customText ?? _messageController.text).trim();
    if (text.isEmpty && _pendingOrderId == null && _pendingProductId == null) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final customerId =
        auth.userId.isNotEmpty ? auth.userId : 'guest_customer';

    _messageController.clear();

    final orderIdToSend = _pendingOrderId;
    final orderTotalToSend = _pendingOrderTotalPrice;
    final prodIdToSend = _pendingProductId;
    final prodNameToSend = _pendingProductName;
    final prodImageToSend = _pendingProductImageUrl;

    // Reset attachments
    if (mounted) {
      setState(() {
        _pendingOrderId = null;
        _pendingOrderTotalPrice = null;
        _pendingProductId = null;
        _pendingProductName = null;
        _pendingProductImageUrl = null;
      });
    }

    await chatProvider.sendMessage(
      customerId: customerId,
      text: text.isNotEmpty ? text : 'Xin hỗ trợ thông tin mục đính kèm này',
      senderId: customerId,
      customerName: auth.userFullName.isNotEmpty
          ? auth.userFullName
          : 'Khách hàng',
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

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messages;

    final chatContent = Column(
      children: [
        // 1. BANNER THÔNG TIN TƯ VẤN LIFELONG CARE
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.ultraLightGrey,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              Icon(Icons.support_agent, size: 22, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tư vấn viên Lifewear sẵn sàng giải đáp về form dáng, bảng chọn size và vận chuyển toàn quốc.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. DANH SÁCH TIN NHẮN REALTIME
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: Colors.grey[350],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Bắt đầu cuộc trò chuyện với Shop',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Bạn có thể gửi câu hỏi hoặc chọn các chủ đề gợi ý nhanh bên dưới để được phản hồi tức thì!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    final isShop = msg.senderId == 'shop_admin' ||
                        msg.senderId == 'admin';
                    final isMe = !isShop;
                    return _buildMessageBubble(msg, isMe, isShop);
                  },
                ),
        ),

        // 3. THẺ ĐÍNH KÈM CHỜ GỬI (NẾU CÓ)
        if (_pendingOrderId != null || _pendingProductId != null)
          _buildPendingAttachmentPreview(),

        // 4. THANH CÂU HỎI GỢI Ý NHANH (QUICK REPLIES)
        _buildQuickRepliesBar(),

        // 5. Ô NHẬP TIN NHẮN & NÚT GỬI
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendMessage(),
                    decoration: InputDecoration(
                      hintText:
                          'Nhập câu hỏi (VD: Mình 1m72 65kg mặc size nào?)...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.grey,
                      ),
                      filled: true,
                      fillColor: AppColors.ultraLightGrey,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  tooltip: 'Gửi tin nhắn',
                  onPressed: () => _handleSendMessage(),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: widget.isStandalone
          ? AppBar(
              title: const Text(
                'TƯ VẤN KHÁCH HÀNG',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.textPrimary,
                ),
              ),
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.textPrimary,
              elevation: 0.5,
            )
          : null,
      body: chatContent,
    );
  }

  /// Xem trước đính kèm chờ gửi
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

  /// Thanh câu hỏi gợi ý nhanh (Quick Replies)
  Widget _buildQuickRepliesBar() {
    return Container(
      height: 42,
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final reply = _quickReplies[index];
          return InkWell(
            onTap: () {
              _messageController.text = reply;
              _handleSendMessage(customText: reply);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.ultraLightGrey,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reply,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bong bóng tin nhắn kèm thẻ Order / Product đính kèm
  Widget _buildMessageBubble(MessageModel msg, bool isMe, bool isShop) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.black : AppColors.ultraLightGrey,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
          border: isMe ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Tiêu đề người gửi
            if (isShop)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'TƯ VẤN VIÊN (SHOP)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'BẠN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
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
                    color: isMe ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMe ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 20,
                        color: isMe ? Colors.white : AppColors.primary,
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
                                color: isMe ? Colors.white : AppColors.textPrimary,
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
                                  color: isMe
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
                        color: isMe ? Colors.white60 : Colors.grey,
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
                    color: isMe ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMe ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.productImageUrl != null &&
                          msg.productImageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
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
                          color: isMe ? Colors.white : AppColors.primary,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          msg.productName ?? 'Sản phẩm thời trang',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: isMe ? Colors.white60 : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Nội dung tin nhắn văn bản
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),

            // Thời gian gửi
            Text(
              AppFormatters.formatTime(msg.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white60 : AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
