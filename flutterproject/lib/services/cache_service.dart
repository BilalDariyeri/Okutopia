import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Zero-Loading UI için Cache Service
/// Verileri bellekte ve diskte tutarak anında gösterim sağlar
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Memory cache (RAM)
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache expiration süreleri (dakika cinsinden)
  static const int _defaultExpirationMinutes = 5;
  static const int _studentListExpirationMinutes = 10;
  static const int _statisticsExpirationMinutes = 2;
  static const int _contentExpirationMinutes = 30; // İçerik daha az değişir

  /// Veriyi cache'den al (memory-first)
  T? get<T>(String key) {
    // Önce memory'den kontrol et
    if (_memoryCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && !_isExpired(key, timestamp)) {
        AppLogger.debug('Cache hit (memory): $key');
        return _memoryCache[key] as T?;
      } else {
        // Expired, temizle
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    
    return null;
  }

  /// Veriyi cache'e kaydet (memory + disk) - Performans için disk cache geciktirildi
  Future<void> set<T>(String key, T value, {int? expirationMinutes}) async {
    try {
      // Memory cache'e kaydet (anında)
      _memoryCache[key] = value;
      _cacheTimestamps[key] = DateTime.now();
      
      // Disk cache'e kaydet (arka planda, UI thread'i bloklamamak için)
      Future.microtask(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final jsonValue = jsonEncode(value);
          await prefs.setString('cache_$key', jsonValue);
          await prefs.setString('cache_time_$key', DateTime.now().toIso8601String());
        } catch (e) {
          AppLogger.error('Cache set error: $key', e);
        }
      });
    } catch (e) {
      AppLogger.error('Cache set error: $key', e);
    }
  }

  /// Cache'den sil
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_$key');
      await prefs.remove('cache_time_$key');
    } catch (e) {
      AppLogger.error('Cache remove error: $key', e);
    }
  }

  /// Tüm cache'i temizle
  Future<void> clear() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.error('Cache clear error', e);
    }
  }

  /// Cache'in expire olup olmadığını kontrol et
  bool _isExpired(String key, DateTime timestamp) {
    int expirationMinutes = _defaultExpirationMinutes;
    
    // Key'e göre expiration süresi belirle
    if (key.startsWith('students_')) {
      expirationMinutes = _studentListExpirationMinutes;
    } else if (key.startsWith('statistics_')) {
      expirationMinutes = _statisticsExpirationMinutes;
    } else if (key.startsWith('content_')) {
      expirationMinutes = _contentExpirationMinutes;
    }
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inMinutes > expirationMinutes;
  }

  /// Disk'ten cache'i yükle (app başlangıcında)
  Future<T?> loadFromDisk<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonValue = prefs.getString('cache_$key');
      final timeString = prefs.getString('cache_time_$key');
      
      if (jsonValue != null && timeString != null) {
        final timestamp = DateTime.parse(timeString);
        if (!_isExpired(key, timestamp)) {
          final value = jsonDecode(jsonValue) as T;
          // Memory cache'e de yükle
          _memoryCache[key] = value;
          _cacheTimestamps[key] = timestamp;
          AppLogger.debug('Cache loaded from disk: $key');
          return value;
        } else {
          // Expired, disk'ten sil
          await prefs.remove('cache_$key');
          await prefs.remove('cache_time_$key');
        }
      }
    } catch (e) {
      AppLogger.error('Cache load from disk error: $key', e);
    }
    
    return null;
  }

  /// Cache key'leri oluştur
  static String studentListKey(String teacherId) => 'students_$teacherId';
  static String statisticsKey(String studentId) => 'statistics_$studentId';
  static String categoriesKey() => 'content_categories';
  static String groupsKey(String categoryId) => 'content_groups_$categoryId';
  static String lessonsKey(String groupId) => 'content_lessons_$groupId';
  static String activitiesKey(String lessonId) => 'content_activities_$lessonId';
}

