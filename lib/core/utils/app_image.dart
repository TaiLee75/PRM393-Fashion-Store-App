import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Component hiển thị ảnh đa năng hỗ trợ cả URL mạng lẫn chuỗi Base64 Data URI
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    final cleanUrl = imageUrl.trim();

    if (cleanUrl.startsWith('data:image')) {
      try {
        final base64String = cleanUrl.split(',').last;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, err, _) =>
              errorWidget?.call(ctx, cleanUrl, err) ??
              Container(
                width: width,
                height: height,
                color: AppColors.ultraLightGrey,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
        );
      } catch (err) {
        imageWidget = errorWidget?.call(context, cleanUrl, err) ??
            Container(
              width: width,
              height: height,
              color: AppColors.ultraLightGrey,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
      }
    } else if (cleanUrl.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: cleanUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder ??
            (_, __) => Container(
                  width: width,
                  height: height,
                  color: AppColors.ultraLightGrey,
                ),
        errorWidget: errorWidget ??
            (_, __, ___) => Container(
                  width: width,
                  height: height,
                  color: AppColors.ultraLightGrey,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: Colors.grey),
                ),
      );
    } else {
      imageWidget = Container(
        width: width,
        height: height,
        color: AppColors.ultraLightGrey,
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }
    return imageWidget;
  }
}
