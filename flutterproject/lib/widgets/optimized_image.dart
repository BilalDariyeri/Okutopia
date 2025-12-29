import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCacheWidth = cacheWidth ?? (screenWidth * 1.2).round().clamp(300, 500);
    final maxCacheHeight = cacheHeight ?? 500;

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: maxCacheWidth,
      memCacheHeight: maxCacheHeight,
      maxWidthDiskCache: maxCacheWidth,
      maxHeightDiskCache: maxCacheHeight,
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4FC3F7),
                    ),
                  ),
                ),
              ),
      errorWidget: errorWidget != null
          ? (context, url, error) {
              // Görüntü kodlama hatasını yakala
              debugPrint('❌ Image error: $url - $error');
              return errorWidget!;
            }
          : (context, url, error) {
              // Görüntü kodlama hatasını yakala
              debugPrint('❌ Image error: $url - $error');
              return const Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 64,
                  color: Colors.grey,
                ),
              );
            },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

