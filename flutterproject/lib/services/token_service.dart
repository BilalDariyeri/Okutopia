import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token caching service for performance optimization
/// Eliminates redundant disk I/O operations by caching tokens in memory
class TokenService {
  static String? _cachedToken;
  static DateTime? _tokenExpiry;
  static const Duration cacheExpiry = Duration(hours: 1);
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Get cached token, fetch from storage if expired
  static Future<String?> getToken() async {
    try {
      // Check cache first
      if (_cachedToken != null && _tokenExpiry != null) {
        if (DateTime.now().isBefore(_tokenExpiry!)) {
          debugPrint('✅ Token cache\'den alındı');
          return _cachedToken;
        } else {
          debugPrint('⏰ Token cache süresi dolmuş, yeniden alınıyor');
          clearCache();
        }
      }
      
      // Cache miss - fetch from secure storage
      debugPrint('📂 Token disk\'ten okunuyor');
      _cachedToken = await _storage.read(key: 'token');
      
      if (_cachedToken != null) {
        // Set cache expiry (assuming 1 hour validity)
        _tokenExpiry = DateTime.now().add(cacheExpiry);
        debugPrint('🔑 Token cache\'lendi, expiry: ${_tokenExpiry}');
      } else {
        debugPrint('❌ Token bulunamadı');
      }
      
      return _cachedToken;
    } catch (e) {
      debugPrint('❌ Token okuma hatası: $e');
      clearCache();
      return null;
    }
  }

  /// Cache a new token
  static Future<void> cacheToken(String token) async {
    try {
      _cachedToken = token;
      _tokenExpiry = DateTime.now().add(cacheExpiry);
      
      // Also save to secure storage
      await _storage.write(key: 'token', value: token);
      
      debugPrint('✅ Token cache\'lendi');
    } catch (e) {
      debugPrint('❌ Token cache hatası: $e');
    }
  }

  /// Clear token cache
  static void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
    debugPrint('🧹 Token cache temizlendi');
  }

  /// Clear both cache and secure storage
  static Future<void> clearAll() async {
    try {
      clearCache();
      await _storage.delete(key: 'token');
      debugPrint('🗑️  Token tamamen temizlendi');
    } catch (e) {
      debugPrint('❌ Token temizleme hatası: $e');
    }
  }

  /// Check if token is available in cache
  static bool get hasToken => _cachedToken != null;
  
  /// Check if token is expired
  static bool get isExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  /// Get cache status for debugging
  static Map<String, dynamic> getCacheStatus() {
    return {
      'hasToken': hasToken,
      'isExpired': isExpired,
      'expiryTime': _tokenExpiry?.toIso8601String(),
      'cachedAt': _tokenExpiry != null 
          ? _tokenExpiry!.subtract(cacheExpiry).toIso8601String() 
          : null,
    };
  }
}

