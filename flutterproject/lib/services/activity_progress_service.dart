import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Etkinlik ilerleme takibi servisi
/// Kademeli kilit sistemi için tamamlanan etkinlikleri takip eder
class ActivityProgressService {
  static final ActivityProgressService _instance = ActivityProgressService._internal();
  factory ActivityProgressService() => _instance;
  ActivityProgressService._internal();

  static const String _prefsKeyPrefix = 'activity_progress_';

  /// Öğrenci için tamamlanan etkinlikleri kaydet
  /// Harf bazlı olarak saklanır: "A", "B", "C" vb.
  Future<void> markActivityCompleted({
    required String studentId,
    required String letter,
    required String activityId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsKeyPrefix${studentId}_$letter';
      
      // Mevcut tamamlanan etkinlikleri al
      final completedActivitiesJson = prefs.getString(key);
      Set<String> completedActivities = {};
      
      if (completedActivitiesJson != null) {
        try {
          final list = jsonDecode(completedActivitiesJson) as List;
          completedActivities = Set<String>.from(list.map((e) => e.toString()));
        } catch (e) {
          AppLogger.debug('Error parsing completed activities: $e');
        }
      }
      
      // Yeni etkinliği ekle
      completedActivities.add(activityId);
      
      // Kaydet
      await prefs.setString(key, jsonEncode(completedActivities.toList()));
      AppLogger.debug('Activity completed: $activityId for student $studentId, letter $letter');
    } catch (e) {
      AppLogger.error('Error marking activity as completed', e);
    }
  }

  /// Öğrenci için tamamlanan etkinlikleri getir (deprecated - async versiyonu kullanılmalı)
  @Deprecated('Use getCompletedActivitiesAsync instead')
  Set<String> getCompletedActivities({
    required String studentId,
    required String letter,
  }) {
    // Synchronous erişim için getInstance() kullanılamaz, bu yüzden boş döndür
    // Async versiyonu kullanılmalı
    return {};
  }

  /// Öğrenci için tamamlanan etkinlikleri getir (async)
  Future<Set<String>> getCompletedActivitiesAsync({
    required String studentId,
    required String letter,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsKeyPrefix${studentId}_$letter';
      
      final completedActivitiesJson = prefs.getString(key);
      if (completedActivitiesJson == null) {
        return {};
      }
      
      try {
        final list = jsonDecode(completedActivitiesJson) as List;
        return Set<String>.from(list.map((e) => e.toString()));
      } catch (e) {
        AppLogger.debug('Error parsing completed activities: $e');
        return {};
      }
    } catch (e) {
      AppLogger.error('Error getting completed activities', e);
      return {};
    }
  }

  /// Etkinliğin tamamlanıp tamamlanmadığını kontrol et
  Future<bool> isActivityCompleted({
    required String studentId,
    required String letter,
    required String activityId,
  }) async {
    final completed = await getCompletedActivitiesAsync(
      studentId: studentId,
      letter: letter,
    );
    return completed.contains(activityId);
  }

  /// Belirli bir harf için tamamlanan etkinlik sayısını getir
  Future<int> getCompletedCount({
    required String studentId,
    required String letter,
  }) async {
    final completed = await getCompletedActivitiesAsync(
      studentId: studentId,
      letter: letter,
    );
    return completed.length;
  }

  /// Öğrenci için tüm ilerlemeyi temizle (opsiyonel)
  Future<void> clearProgress({
    required String studentId,
    required String letter,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsKeyPrefix${studentId}_$letter';
      await prefs.remove(key);
      AppLogger.debug('Progress cleared for student $studentId, letter $letter');
    } catch (e) {
      AppLogger.error('Error clearing progress', e);
    }
  }

  /// Öğrenci için tüm ilerlemeyi temizle (tüm harfler)
  Future<void> clearAllProgress(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('$_prefsKeyPrefix${studentId}_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
      AppLogger.debug('All progress cleared for student $studentId');
    } catch (e) {
      AppLogger.error('Error clearing all progress', e);
    }
  }

  /// Okuma metni tamamlandı olarak işaretle
  Future<void> markReadingTextCompleted({
    required String studentId,
    required String readingTextId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_prefsKeyPrefix}reading_texts_${studentId}';
      
      // Mevcut tamamlanan metinleri al
      final completedTextsJson = prefs.getString(key);
      Set<String> completedTexts = {};
      
      if (completedTextsJson != null) {
        try {
          final list = jsonDecode(completedTextsJson) as List;
          completedTexts = Set<String>.from(list.map((e) => e.toString()));
        } catch (e) {
          AppLogger.debug('Error parsing completed reading texts: $e');
        }
      }
      
      // Yeni metni ekle
      completedTexts.add(readingTextId);
      
      // Kaydet
      await prefs.setString(key, jsonEncode(completedTexts.toList()));
      AppLogger.debug('Reading text completed: $readingTextId for student $studentId');
    } catch (e) {
      AppLogger.error('Error marking reading text as completed', e);
    }
  }

  /// Tamamlanan okuma metinlerini getir
  Future<Set<String>> getCompletedReadingTexts(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_prefsKeyPrefix}reading_texts_${studentId}';
      
      final completedTextsJson = prefs.getString(key);
      if (completedTextsJson == null) {
        return {};
      }
      
      try {
        final list = jsonDecode(completedTextsJson) as List;
        return Set<String>.from(list.map((e) => e.toString()));
      } catch (e) {
        AppLogger.debug('Error parsing completed reading texts: $e');
        return {};
      }
    } catch (e) {
      AppLogger.error('Error getting completed reading texts', e);
      return {};
    }
  }

  /// Okuma metninin tamamlanıp tamamlanmadığını kontrol et
  Future<bool> isReadingTextCompleted({
    required String studentId,
    required String readingTextId,
  }) async {
    final completed = await getCompletedReadingTexts(studentId);
    return completed.contains(readingTextId);
  }

  /// Activity title'dan harf bilgisini çıkar
  /// Örnek: "A Harfi Sesi Hissetme" -> "A"
  static String extractLetterFromTitle(String activityTitle) {
    final titleUpper = activityTitle.toUpperCase().trim();
    
    // Türkçe harfler listesi
    final turkishLetters = [
      'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H', 
      'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P', 
      'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z'
    ];
    
    // Başlıkta geçen ilk harfi bul
    for (var letter in turkishLetters) {
      // Başlık başında harf kontrolü
      if (titleUpper.startsWith('$letter ') ||
          titleUpper.startsWith('$letter HARF') ||
          titleUpper.startsWith('$letter HARFİ') ||
          titleUpper.contains(' $letter HARF') ||
          titleUpper.contains(' $letter HARFİ') ||
          titleUpper.contains('HARF $letter') ||
          titleUpper.contains('HARFİ $letter')) {
        return letter;
      }
    }
    
    // Eğer bulunamazsa, başlıktaki ilk karakteri kontrol et
    if (titleUpper.isNotEmpty && turkishLetters.contains(titleUpper[0])) {
      return titleUpper[0];
    }
    
    // Varsayılan olarak boş string döndür
    return '';
  }
}

