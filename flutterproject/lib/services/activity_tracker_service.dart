import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'current_session_service.dart';

/// Etkinlik bazlı süre takibi servisi
/// Her etkinlik için ne kadar süre geçirildiğini takip eder
class ActivityTrackerService {
  final CurrentSessionService _sessionService = CurrentSessionService();
  static const String _prefsKey = 'activity_tracking_data';
  static ActivityTrackerService? _instance;
  
  ActivityTrackerService._internal();
  
  factory ActivityTrackerService() {
    _instance ??= ActivityTrackerService._internal();
    return _instance!;
  }

  /// Etkinlik başladığında çağrılır
  Future<void> startActivity({
    required String studentId,
    required String activityId,
    required String activityTitle,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackingData = await _getTrackingData(prefs);
      
      final key = '$studentId\_$activityId';
      final now = DateTime.now().toIso8601String();
      
      trackingData[key] = {
        'studentId': studentId,
        'activityId': activityId,
        'activityTitle': activityTitle,
        'startTime': now,
        'endTime': null,
        'duration': 0, // Saniye cinsinden
      };
      
      await _saveTrackingData(prefs, trackingData);
      debugPrint('✅ Aktivite başlatıldı: $activityTitle');
    } catch (e) {
      debugPrint('❌ Aktivite başlatma hatası: $e');
    }
  }

  /// Etkinlik bittiğinde çağrılır
  Future<void> endActivity({
    required String studentId,
    required String activityId,
    String? successStatus,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackingData = await _getTrackingData(prefs);
      
      final key = '$studentId\_$activityId';
      final activityData = trackingData[key];
      
      if (activityData != null && activityData['endTime'] == null) {
        final startTime = DateTime.parse(activityData['startTime']);
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime).inSeconds;
        
        trackingData[key] = {
          ...activityData,
          'endTime': endTime.toIso8601String(),
          'duration': duration,
        };
        
        await _saveTrackingData(prefs, trackingData);
        
        // Oturum servisine de ekle
        _sessionService.addActivity(
          studentId: studentId,
          activityId: activityId,
          activityTitle: activityData['activityTitle'] ?? 'Bilinmeyen Aktivite',
          durationSeconds: duration,
          successStatus: successStatus,
        );
        
        debugPrint('✅ Aktivite tamamlandı: ${activityData['activityTitle']} - Süre: $duration s');
      }
    } catch (e) {
      debugPrint('❌ Aktivite bitirme hatası: $e');
    }
  }

  /// Öğrencinin bugünkü aktivite sürelerini getir
  Future<Map<String, ActivityDuration>> getTodayActivityDurations(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackingData = await _getTrackingData(prefs);
      
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      final Map<String, ActivityDuration> durations = {};
      
      trackingData.forEach((key, value) {
        if (key.startsWith('$studentId\_')) {
          final startTime = DateTime.parse(value['startTime']);
          
          // Bugünkü aktiviteleri filtrele
          if (startTime.isAfter(todayStart) || startTime.isAtSameMomentAs(todayStart)) {
            final activityId = value['activityId'];
            final activityTitle = value['activityTitle'] ?? 'Bilinmeyen Aktivite';
            final duration = value['duration'] ?? 0;
            
            if (durations.containsKey(activityId)) {
              // Aynı aktivite için süreleri topla
              durations[activityId] = ActivityDuration(
                activityId: activityId,
                activityTitle: activityTitle,
                duration: durations[activityId]!.duration + (duration as int),
              );
            } else {
              durations[activityId] = ActivityDuration(
                activityId: activityId,
                activityTitle: activityTitle,
                duration: duration as int,
              );
            }
          }
        }
      });
      
      return durations;
    } catch (e) {
      debugPrint('❌ Aktivite süreleri getirme hatası: $e');
      return {};
    }
  }

  /// Öğrencinin bugünkü toplam süresini getir
  Future<Duration> getTodayTotalDuration(String studentId) async {
    try {
      final durations = await getTodayActivityDurations(studentId);
      int totalSeconds = 0;
      
      durations.forEach((key, value) {
        totalSeconds += value.duration;
      });
      
      return Duration(seconds: totalSeconds);
    } catch (e) {
      debugPrint('❌ Toplam süre hesaplama hatası: $e');
      return Duration.zero;
    }
  }

  /// Tracking verilerini temizle (opsiyonel)
  Future<void> clearTrackingData(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackingData = await _getTrackingData(prefs);
      
      trackingData.removeWhere((key, value) => key.startsWith('$studentId\_'));
      
      await _saveTrackingData(prefs, trackingData);
      debugPrint('✅ Tracking verileri temizlendi: $studentId');
    } catch (e) {
      debugPrint('❌ Tracking temizleme hatası: $e');
    }
  }

  Future<Map<String, dynamic>> _getTrackingData(SharedPreferences prefs) async {
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null) return {};
    
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('❌ Tracking data parse hatası: $e');
      return {};
    }
  }

  Future<void> _saveTrackingData(SharedPreferences prefs, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      await prefs.setString(_prefsKey, jsonString);
    } catch (e) {
      debugPrint('❌ Tracking data kaydetme hatası: $e');
    }
  }
}

/// Aktivite süre modeli
class ActivityDuration {
  final String activityId;
  final String activityTitle;
  final int duration; // Saniye cinsinden

  ActivityDuration({
    required this.activityId,
    required this.activityTitle,
    required this.duration,
  });

  Duration get durationDuration => Duration(seconds: duration);
  
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '$hours s $minutes dk $seconds sn';
    } else if (minutes > 0) {
      return '$minutes dk $seconds sn';
    } else {
      return '$seconds sn';
    }
  }
}

