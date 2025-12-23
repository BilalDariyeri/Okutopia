import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    return await _storage.read(key: 'token');
  }

  /// Öğrenci oturumu başlat
  /// POST /api/statistics/start-session
  Future<Map<String, dynamic>> startSession(String studentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
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
        return {
          'success': true,
          'session': response.data['session'],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Oturum başlatılamadı.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Oturum başlatılamadı.');
      }
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrenci oturumu bitir
  /// POST /api/statistics/end-session
  Future<Map<String, dynamic>> endSession(String studentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.post(
        '/statistics/end-session',
        data: {'studentId': studentId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Oturum bitirilemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Oturum bitirilemedi.');
      }
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Öğrenci istatistiklerini getir
  /// GET /api/statistics/student/:studentId
  Future<Map<String, dynamic>> getStudentStatistics(String studentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.get(
        '/statistics/student/$studentId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'İstatistikler yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'İstatistikler yüklenemedi.');
      }
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Veliye email gönder
  /// POST /api/statistics/student/:studentId/send-email
  Future<Map<String, dynamic>> sendEmailToParent(String studentId, {String? parentEmail}) async {
    try {
      final token = await _getToken();
      if (token == null) {
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
        return {
          'success': true,
          'message': response.data['message'],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Email gönderilemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Email gönderilemedi.');
      }
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }
}

