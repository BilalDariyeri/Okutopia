import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Image Cache Service for performance optimization
/// Provides improved image loading with caching and error handling
class ImageCacheService {
  static final Map<String, ImageProvider> _imageProviderCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration cacheExpiry = Duration(hours: 24); // 24 hour cache

  static Widget getOptimizedImage(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    Color? color,
    BlendMode? colorBlendMode,
    FilterQuality filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    final int memCacheWidth = cacheWidth ?? (width != null ? (width * 2).round() : 800);
    final int memCacheHeight = cacheHeight ?? (height != null ? (height * 2).round() : 800);
    
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      memCacheWidth: memCacheWidth.clamp(100, 1080),
      memCacheHeight: memCacheHeight.clamp(100, 1080),
      maxWidthDiskCache: memCacheWidth.clamp(100, 1080),
      maxHeightDiskCache: memCacheHeight.clamp(100, 1080),
      placeholder: placeholder != null
          ? (context, url) => placeholder
          : (context, url) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
      errorWidget: errorWidget != null
          ? (context, url, error) {
              debugPrint('❌ Image loading error: $url - $error');
              return errorWidget;
            }
          : (context, url, error) {
              debugPrint('❌ Image loading error: $url - $error');
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  border: Border.all(color: Colors.grey[400] ?? Colors.grey),
                ),
                child: Icon(
                  Icons.broken_image,
                  size: (width ?? height ?? 48) / 2,
                  color: Colors.grey[600],
                ),
              );
            },
    );
  }

  /// Preload image for better user experience
  static Future<void> preloadImage(String url) async {
    try {
      final image = NetworkImage(url);
      final config = ImageConfiguration(
        size: Size.infinite,
        devicePixelRatio: 1.0,
      );
      
      await image.resolve(config);
    } catch (e) {
      // Ignore preload errors
    }
  }

  static Future<void> preloadImages(List<String> urls) async {
    await Future.wait(
      urls.map((url) => preloadImage(url))
    );
  }

  /// Clear expired images from cache
  static void clearExpiredImages() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.isAfter(timestamp.add(cacheExpiry))) {
        expiredKeys.add(key);
      }
    });
    
    expiredKeys.forEach((key) {
      _imageProviderCache.remove(key);
      _cacheTimestamps.remove(key);
    });
    
    // Cache cleared silently
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    int validCount = 0;
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.isAfter(timestamp.add(cacheExpiry))) {
        expiredCount++;
      } else {
        validCount++;
      }
    });
    
    return {
      'totalImages': _imageProviderCache.length,
      'validImages': validCount,
      'expiredImages': expiredCount,
      'cacheSize': _calculateApproximateCacheSize(),
    };
  }

  /// Calculate approximate cache size
  static String _calculateApproximateCacheSize() {
    final imageCount = _imageProviderCache.length;
    final estimatedSize = imageCount * 0.5; // ~0.5MB per image estimate
    return '${estimatedSize.toStringAsFixed(1)}MB';
  }
}

/// Optimized Image Widget with enhanced loading experience
class OptimizedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    Key? key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.low,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ImageCacheService.getOptimizedImage(
      url,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}

