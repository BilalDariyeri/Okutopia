import 'package:flutter/foundation.dart';

/// Mevcut oturum için aktivite takibi servisi
/// Öğrenci giriş yaptığından beri yapılan aktiviteleri hafızada tutar
class CurrentSessionService {
  static CurrentSessionService? _instance;
  
  CurrentSessionService._internal();
  
  factory CurrentSessionService() {
    _instance ??= CurrentSessionService._internal();
    return _instance!;
  }

  // Oturum verileri: studentId -> List<SessionActivity>
  final Map<String, List<SessionActivity>> _sessionData = {};
  
  // Oturum başlangıç zamanları: studentId -> DateTime
  final Map<String, DateTime> _sessionStartTimes = {};
  
  // Oturum toplam süreleri (ActivityTimer'dan gelen): studentId -> Duration
  final Map<String, Duration> _sessionTotalDurations = {};

  /// Oturumu başlat (öğrenci giriş yaptığında)
  void startSession(String studentId) {
    _sessionData[studentId] = [];
    _sessionStartTimes[studentId] = DateTime.now();
    _sessionTotalDurations[studentId] = Duration.zero;
    debugPrint('✅ Oturum başlatıldı: $studentId');
  }

  /// Oturum toplam süresini güncelle (ActivityTimer'dan)
  void updateSessionTotalDuration(String studentId, Duration duration) {
    if (!_sessionTotalDurations.containsKey(studentId)) {
      // Oturum başlatılmamışsa başlat
      startSession(studentId);
    }
    _sessionTotalDurations[studentId] = duration;
  }

  /// Aktivite ekle (aktivite tamamlandığında)
  void addActivity({
    required String studentId,
    required String activityId,
    required String activityTitle,
    required int durationSeconds,
    String? successStatus,
    bool isCompleted = false, // Aktivite başarıyla tamamlandı mı?
    int correctAnswerCount = 0, // Doğru cevap sayısı
  }) {
    if (!_sessionData.containsKey(studentId)) {
      // Oturum başlatılmamışsa başlat
      startSession(studentId);
    }

    final activity = SessionActivity(
      activityId: activityId,
      activityTitle: activityTitle,
      durationSeconds: durationSeconds,
      completedAt: DateTime.now(),
      successStatus: successStatus,
      isCompleted: isCompleted,
      correctAnswerCount: correctAnswerCount,
    );

    _sessionData[studentId]!.add(activity);
    debugPrint('✅ Aktivite eklendi: $activityTitle - $durationSeconds s - Tamamlandı: $isCompleted');
  }

  /// Oturum verilerini getir
  List<SessionActivity> getSessionActivities(String studentId) {
    return _sessionData[studentId] ?? [];
  }

  /// Oturum başlangıç zamanını getir
  DateTime? getSessionStartTime(String studentId) {
    return _sessionStartTimes[studentId];
  }

  /// Oturum toplam süresini getir (ActivityTimer'dan gelen süre varsa onu kullan, yoksa aktivitelerden hesapla)
  Duration getSessionTotalDuration(String studentId) {
    // Önce ActivityTimer'dan gelen süreyi kontrol et
    if (_sessionTotalDurations.containsKey(studentId)) {
      return _sessionTotalDurations[studentId]!;
    }
    
    // Yoksa aktivitelerden hesapla
    final activities = getSessionActivities(studentId);
    int totalSeconds = 0;
    
    for (var activity in activities) {
      totalSeconds += activity.durationSeconds;
    }
    
    return Duration(seconds: totalSeconds);
  }

  /// Oturumu temizle (öğrenci çıkış yaptığında veya değiştirildiğinde)
  void clearSession(String studentId) {
    _sessionData.remove(studentId);
    _sessionStartTimes.remove(studentId);
    _sessionTotalDurations.remove(studentId);
    debugPrint('✅ Oturum temizlendi: $studentId');
  }

  /// Tüm oturumları temizle
  void clearAllSessions() {
    _sessionData.clear();
    _sessionStartTimes.clear();
    _sessionTotalDurations.clear();
    debugPrint('✅ Tüm oturumlar temizlendi');
  }
}

/// Oturum aktivite modeli
class SessionActivity {
  final String activityId;
  final String activityTitle;
  final int durationSeconds; // Saniye cinsinden
  final DateTime completedAt;
  final String? successStatus; // Örn: "Başarılı", "Tamamlandı", vb.
  final bool isCompleted; // Aktivite başarıyla tamamlandı mı?
  final int correctAnswerCount; // Doğru cevap sayısı

  SessionActivity({
    required this.activityId,
    required this.activityTitle,
    required this.durationSeconds,
    required this.completedAt,
    this.successStatus,
    this.isCompleted = false, // Varsayılan olarak false
    this.correctAnswerCount = 0, // Varsayılan olarak 0
  });

  Duration get duration => Duration(seconds: durationSeconds);
  
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    
    if (hours > 0) {
      return '$hours s $minutes dk';
    } else if (minutes > 0) {
      return '$minutes dk $seconds sn';
    } else {
      return '$seconds sn';
    }
  }
}

