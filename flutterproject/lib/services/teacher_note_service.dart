import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final queryParams = <String, dynamic>{};
      if (teacherId != null) {
        queryParams['teacherId'] = teacherId;
      }

      final response = await _dio.get(
        '/teacher-notes/student/$studentId',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Notlar yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Notlar yüklenemedi.');
      }
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrencinin son oturum istatistiklerini getir
  /// GET /api/teacher-notes/student/:studentId/last-session
  Future<Map<String, dynamic>> getStudentLastSessionStats(String studentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
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
          return {
            'success': true,
            'lastSessionStats': data['lastSession'],
            'student': data['student'],
          };
        }
        return data;
      } else {
        throw Exception(response.data['message'] ?? 'Son oturum istatistikleri yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          // Öğrenci bulunamadı veya veri yok - boş response döndür
          return {
            'success': true,
            'lastSessionStats': null,
          };
        }
        throw Exception(e.response?.data['message'] ?? 'Son oturum istatistikleri yüklenemedi.');
      }
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
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final data = <String, dynamic>{
        'title': title,
        'content': content,
        if (priority != null) 'priority': priority,
        if (category != null) 'category': category,
        if (teacherId != null) 'teacherId': teacherId,
      };

      final response = await _dio.post(
        '/teacher-notes/student/$studentId',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'note': response.data['note'],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Not oluşturulamadı.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Not oluşturulamadı.');
      }
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
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final data = <String, dynamic>{
        'title': title,
        'content': content,
        if (priority != null) 'priority': priority,
        if (category != null) 'category': category,
      };

      final response = await _dio.put(
        '/teacher-notes/$noteId',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'note': response.data['note'],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Not güncellenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Not güncellenemedi.');
      }
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }
}

