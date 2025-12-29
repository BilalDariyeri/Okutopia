import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_logger.dart';

class TeacherNoteService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  TeacherNoteService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        )),
        _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  /// Öğrencinin notlarını getir
  /// GET /api/teacher-notes/student/:studentId
  Future<Map<String, dynamic>> getStudentNotes(String studentId, {String? teacherId}) async {
    try {
      AppLogger.info('Fetching notes for student: $studentId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for notes fetch');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final queryParams = <String, dynamic>{};
      if (teacherId != null) {
        queryParams['teacherId'] = teacherId;
        AppLogger.debug('Filtering notes by teacher: $teacherId');
      }

      final response = await _dio.get(
        '/teacher-notes/student/$studentId',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Notes fetched successfully for student: $studentId');
        return response.data;
      } else {
        AppLogger.warning('Notes fetch failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Notlar yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Notes fetch failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Notlar yüklenemedi.');
      }
      AppLogger.error('Notes fetch failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrencinin son oturum istatistiklerini getir
  /// GET /api/teacher-notes/student/:studentId/last-session
  Future<Map<String, dynamic>> getStudentLastSessionStats(String studentId) async {
    try {
      AppLogger.info('Fetching last session stats for student: $studentId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for last session stats fetch');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.get(
        '/teacher-notes/student/$studentId/last-session',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        // Backend response yapısını frontend beklentisine uyarla
        final data = response.data;
        if (data['success'] == true && data['lastSession'] != null) {
          // Backend'den gelen 'lastSession' objesini 'lastSessionStats' olarak dönüştür
          AppLogger.debug('Last session data transformed for student: $studentId');
          return {
            'success': true,
            'lastSessionStats': data['lastSession'],
            'student': data['student'],
          };
        }
        AppLogger.info('Last session stats fetched for student: $studentId');
        return data;
      } else {
        AppLogger.warning('Last session stats fetch failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Son oturum istatistikleri yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          // Öğrenci bulunamadı veya veri yok - boş response döndür
          AppLogger.debug('No last session data found for student: $studentId');
          return {
            'success': true,
            'lastSessionStats': null,
          };
        }
        AppLogger.error('Last session stats fetch failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Son oturum istatistikleri yüklenemedi.');
      }
      AppLogger.error('Last session stats fetch failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrenciye not ekle
  /// POST /api/teacher-notes/student/:studentId
  Future<Map<String, dynamic>> createNote({
    required String studentId,
    required String title,
    required String content,
    String? priority,
    String? category,
    String? teacherId,
  }) async {
    try {
      AppLogger.info('Creating note for student: $studentId - Title: $title');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for note creation');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final data = <String, dynamic>{
        'title': title,
        'content': content,
        if (priority != null) 'priority': priority,
        if (category != null) 'category': category,
        if (teacherId != null) 'teacherId': teacherId,
      };

      AppLogger.debug('Note data prepared: ${data.keys.toList()}');

      final response = await _dio.post(
        '/teacher-notes/student/$studentId',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        AppLogger.info('Note created successfully for student: $studentId');
        return {
          'success': true,
          'message': response.data['message'],
          'note': response.data['note'],
        };
      } else {
        AppLogger.warning('Note creation failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Not oluşturulamadı.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Note creation failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Not oluşturulamadı.');
      }
      AppLogger.error('Note creation failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrenci için veliye gönderilen son maili getir
  /// GET /api/statistics/student/:studentId/last-email
  Future<Map<String, dynamic>> getLastEmailToParent(String studentId) async {
    try {
      AppLogger.info('Fetching last email for student: $studentId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for last email fetch');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.get(
        '/statistics/student/$studentId/last-email',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Last email fetched successfully for student: $studentId');
        return response.data;
      } else if (response.statusCode == 404) {
        // Email bulunamadı - boş response döndür
        AppLogger.debug('No email found for student: $studentId');
        return {
          'success': true,
          'email': null,
        };
      } else {
        AppLogger.warning('Last email fetch failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Son email yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          // Email bulunamadı - boş response döndür
          AppLogger.debug('No email found for student: $studentId');
          return {
            'success': true,
            'email': null,
          };
        }
        AppLogger.error('Last email fetch failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Son email yüklenemedi.');
      }
      AppLogger.error('Last email fetch failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Notu güncelle
  /// PUT /api/teacher-notes/:noteId
  Future<Map<String, dynamic>> updateNote({
    required String noteId,
    required String title,
    required String content,
    String? priority,
    String? category,
  }) async {
    try {
      AppLogger.info('Updating note: $noteId - Title: $title');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for note update');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final data = <String, dynamic>{
        'title': title,
        'content': content,
        if (priority != null) 'priority': priority,
        if (category != null) 'category': category,
      };

      AppLogger.debug('Note update data prepared: ${data.keys.toList()}');

      final response = await _dio.put(
        '/teacher-notes/$noteId',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Note updated successfully: $noteId');
        return {
          'success': true,
          'message': response.data['message'],
          'note': response.data['note'],
        };
      } else {
        AppLogger.warning('Note update failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Not güncellenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Note update failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Not güncellenemedi.');
      }
      AppLogger.error('Note update failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }
}

