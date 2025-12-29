import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_logger.dart';
import 'token_service.dart';

class StatisticsService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  StatisticsService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        )),
        _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await TokenService.getToken();
  }

  /// Öğrenci oturumu başlat
  /// POST /api/statistics/start-session
  Future<Map<String, dynamic>> startSession(String studentId) async {
    try {
      AppLogger.info('Starting session for student: $studentId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for session start');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.post(
        '/statistics/start-session',
        data: {'studentId': studentId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        AppLogger.info('Session started successfully for student: $studentId');
        return {
          'success': true,
          'session': response.data['session'],
        };
      } else {
        AppLogger.warning('Session start failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Oturum başlatılamadı.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Session start failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Oturum başlatılamadı.');
      }
      AppLogger.error('Session start failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrenci oturumu bitir (oturum verileriyle birlikte)
  /// POST /api/statistics/end-session
  Future<Map<String, dynamic>> endSession(
    String studentId, {
    List<Map<String, dynamic>>? sessionActivities,
    int? totalDurationSeconds,
  }) async {
    try {
      AppLogger.info('Ending session for student: $studentId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for session end');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final requestData = <String, dynamic>{'studentId': studentId};
      
      // Oturum verileri varsa ekle (lastSessionStats güncellemesi için)
      if (sessionActivities != null && totalDurationSeconds != null) {
        requestData['sessionActivities'] = sessionActivities;
        requestData['totalDurationSeconds'] = totalDurationSeconds;
        AppLogger.debug('Including session data: ${sessionActivities.length} activities, ${totalDurationSeconds}s total');
      }

      final response = await _dio.post(
        '/statistics/end-session',
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Session ended successfully for student: $studentId');
        return {
          'success': true,
          'message': response.data['message'],
        };
      } else {
        AppLogger.warning('Session end failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Oturum bitirilemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Session end failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Oturum bitirilemedi.');
      }
      AppLogger.error('Session end failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrenci istatistiklerini getir
  /// GET /api/statistics/student/:studentId
  Future<Map<String, dynamic>> getStudentStatistics(String studentId) async {
    try {
      AppLogger.info('Fetching statistics for student: $studentId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for statistics fetch');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.get(
        '/statistics/student/$studentId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Statistics fetched successfully for student: $studentId');
        return response.data;
      } else {
        AppLogger.warning('Statistics fetch failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'İstatistikler yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Statistics fetch failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'İstatistikler yüklenemedi.');
      }
      AppLogger.error('Statistics fetch failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Veliye email gönder (oturum bazlı)
  /// POST /api/statistics/student/:studentId/send-session-email
  Future<Map<String, dynamic>> sendSessionEmailToParent(
    String studentId, {
    String? parentEmail,
    required List<Map<String, dynamic>> sessionActivities,
    required int totalDurationSeconds,
  }) async {
    try {
      AppLogger.info('Sending session email for student: $studentId to ${parentEmail ?? 'default parent email'}');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for session email');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.post(
        '/statistics/student/$studentId/send-session-email',
        data: {
          if (parentEmail != null) 'parentEmail': parentEmail,
          'sessionActivities': sessionActivities,
          'totalDurationSeconds': totalDurationSeconds,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Session email sent successfully for student: $studentId');
        return {
          'success': true,
          'message': response.data['message'],
        };
      } else {
        AppLogger.warning('Session email failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Email gönderilemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Session email failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Email gönderilemedi.');
      }
      AppLogger.error('Session email failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Veliye email gönder (mevcut - bugünkü veriler)
  /// POST /api/statistics/student/:studentId/send-email
  Future<Map<String, dynamic>> sendEmailToParent(String studentId, {String? parentEmail}) async {
    try {
      AppLogger.info('Sending daily email for student: $studentId to ${parentEmail ?? 'default parent email'}');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for daily email');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.post(
        '/statistics/student/$studentId/send-email',
        data: parentEmail != null ? {'parentEmail': parentEmail} : {},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Daily email sent successfully for student: $studentId');
        return {
          'success': true,
          'message': response.data['message'],
        };
      } else {
        AppLogger.warning('Daily email failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Email gönderilemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Daily email failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Email gönderilemedi.');
      }
      AppLogger.error('Daily email failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }
}

