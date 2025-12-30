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
          return _cachedToken;
        } else {
          clearCache();
        }
      }
      
      _cachedToken = await _storage.read(key: 'token');
      
      if (_cachedToken != null) {
        _tokenExpiry = DateTime.now().add(cacheExpiry);
      }
      
      return _cachedToken;
    } catch (e) {
      debugPrint('Token read error: $e');
      clearCache();
      return null;
    }
  }

  /// Cache a new token
  static Future<void> cacheToken(String token) async {
    try {
      _cachedToken = token;
      _tokenExpiry = DateTime.now().add(cacheExpiry);
      
      await _storage.write(key: 'token', value: token);
    } catch (e) {
      debugPrint('Token cache error: $e');
    }
  }

  /// Clear token cache
  static void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
  }

  /// Clear both cache and secure storage
  static Future<void> clearAll() async {
    try {
      clearCache();
      await _storage.delete(key: 'token');
    } catch (e) {
      debugPrint('Token clear error: $e');
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

