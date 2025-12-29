import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';
import 'token_service.dart';

class StatisticsService {
  final Dio _dio;

  StatisticsService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ));

  Future<String?> _getToken() async {
    return await TokenService.getToken();
  }

  Exception _handleDioException(DioException e, String defaultMessage) {
    if (e.response != null) {
      AppLogger.error('Request failed - server error', e);
      return Exception(e.response?.data['message'] ?? defaultMessage);
    }
    AppLogger.error('Request failed - connection error', e);
    return Exception('Bağlantı hatası: ${e.message}');
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
      throw _handleDioException(e, 'Oturum başlatılamadı.');
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
      throw _handleDioException(e, 'Oturum bitirilemedi.');
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
      throw _handleDioException(e, 'İstatistikler yüklenemedi.');
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
      throw _handleDioException(e, 'Email gönderilemedi.');
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
      throw _handleDioException(e, 'Email gönderilemedi.');
    }
  }
}

