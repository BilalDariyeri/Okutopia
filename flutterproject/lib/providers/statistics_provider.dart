import 'package:flutter/foundation.dart';
import '../services/statistics_service.dart';
import '../services/current_session_service.dart';
import '../services/cache_service.dart';
import '../utils/app_logger.dart';

/// Zero-Loading UI için Statistics Provider
/// Cache-first stratejisi ile anında istatistik gösterimi sağlar
class StatisticsProvider with ChangeNotifier {
  final StatisticsService _statisticsService = StatisticsService();
  final CurrentSessionService _sessionService = CurrentSessionService();
  final CacheService _cacheService = CacheService();

  // Cache'lenmiş veriler
  Map<String, Map<String, dynamic>> _cachedStatistics = {};
  Map<String, List<SessionActivity>> _cachedSessionActivities = {};
  Map<String, Duration> _cachedSessionDurations = {};
  Map<String, DateTime?> _cachedSessionStartTimes = {};

  // Loading durumları (sadece background refresh için)
  Map<String, bool> _isRefreshing = {};

  /// İstatistikleri yükle (Cache-First)
  Future<void> loadStatistics(String studentId, {bool forceRefresh = false}) async {
    final cacheKey = CacheService.statisticsKey(studentId);
    
    // 1. Cache'den kontrol et
    if (!forceRefresh) {
      final cached = _cachedStatistics[studentId];
      if (cached != null) {
        notifyListeners();
        AppLogger.debug('Statistics loaded from cache: $studentId');
        
        // Arka planda refresh
        _refreshStatisticsInBackground(studentId);
        return;
      }
    }

    // 2. API'den çek
    try {
      _isRefreshing[studentId] = true;
      notifyListeners();

      final stats = await _statisticsService.getStudentStatistics(studentId);
      final sessionActivities = _sessionService.getSessionActivities(studentId);
      final sessionDuration = _sessionService.getSessionTotalDuration(studentId);
      final sessionStartTime = _sessionService.getSessionStartTime(studentId);

      _cachedStatistics[studentId] = stats;
      _cachedSessionActivities[studentId] = sessionActivities;
      _cachedSessionDurations[studentId] = sessionDuration;
      _cachedSessionStartTimes[studentId] = sessionStartTime;

      // Cache'e kaydet
      await _cacheService.set(cacheKey, {
        'statistics': stats,
        'sessionActivities': sessionActivities.map((a) => {
          'activityId': a.activityId,
          'activityTitle': a.activityTitle,
          'durationSeconds': a.durationSeconds,
          'completedAt': a.completedAt.toIso8601String(),
          'successStatus': a.successStatus,
          'isCompleted': a.isCompleted,
          'correctAnswerCount': a.correctAnswerCount,
        }).toList(),
        'sessionDuration': sessionDuration.inSeconds,
        'sessionStartTime': sessionStartTime?.toIso8601String(),
      });

      _isRefreshing[studentId] = false;
      notifyListeners();
    } catch (e) {
      _isRefreshing[studentId] = false;
      AppLogger.error('Load statistics error: $studentId', e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshStatisticsInBackground(String studentId) async {
    try {
      final stats = await _statisticsService.getStudentStatistics(studentId);
      final sessionActivities = _sessionService.getSessionActivities(studentId);
      final sessionDuration = _sessionService.getSessionTotalDuration(studentId);
      final sessionStartTime = _sessionService.getSessionStartTime(studentId);

      _cachedStatistics[studentId] = stats;
      _cachedSessionActivities[studentId] = sessionActivities;
      _cachedSessionDurations[studentId] = sessionDuration;
      _cachedSessionStartTimes[studentId] = sessionStartTime;

      await _cacheService.set(
        CacheService.statisticsKey(studentId),
        {
          'statistics': stats,
          'sessionActivities': sessionActivities.map((a) => {
            'activityId': a.activityId,
            'activityTitle': a.activityTitle,
            'durationSeconds': a.durationSeconds,
            'completedAt': a.completedAt.toIso8601String(),
            'successStatus': a.successStatus,
            'isCompleted': a.isCompleted,
            'correctAnswerCount': a.correctAnswerCount,
          }).toList(),
          'sessionDuration': sessionDuration.inSeconds,
          'sessionStartTime': sessionStartTime?.toIso8601String(),
        },
      );

      notifyListeners();
    } catch (e) {
      AppLogger.debug('Background refresh statistics failed: $e');
    }
  }

  // Getters
  Map<String, dynamic>? getStatistics(String studentId) => _cachedStatistics[studentId];
  List<SessionActivity>? getSessionActivities(String studentId) => _cachedSessionActivities[studentId];
  Duration? getSessionDuration(String studentId) => _cachedSessionDurations[studentId];
  DateTime? getSessionStartTime(String studentId) => _cachedSessionStartTimes[studentId];
  bool isRefreshing(String studentId) => _isRefreshing[studentId] ?? false;

  /// Cache'i temizle
  void clearCache(String? studentId) {
    if (studentId != null) {
      _cachedStatistics.remove(studentId);
      _cachedSessionActivities.remove(studentId);
      _cachedSessionDurations.remove(studentId);
      _cachedSessionStartTimes.remove(studentId);
    } else {
      _cachedStatistics.clear();
      _cachedSessionActivities.clear();
      _cachedSessionDurations.clear();
      _cachedSessionStartTimes.clear();
    }
    notifyListeners();
  }
}

