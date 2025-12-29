import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';

class UserService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  UserService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        )),
        _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  /// Kullanıcı profilini güncelle (sadece isim/soyisim)
  /// PUT /api/admin/users/:id
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
  }) async {
    try {
      AppLogger.info('Updating profile for user: $userId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for profile update');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.put(
        '/admin/users/$userId',
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Profile updated successfully for user: $userId');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Profil başarıyla güncellendi.',
          'user': response.data['data'],
        };
      } else {
        AppLogger.warning('Profile update failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Profil güncellenemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Profile update failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Profil güncellenemedi.');
      }
      AppLogger.error('Profile update failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Şifre değiştir (eski şifre kontrolü ile)
  /// PUT /api/admin/users/:id
  Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      AppLogger.info('Changing password for user: $userId');
      
      final token = await _getToken();
      if (token == null) {
        AppLogger.error('No token found for password change');
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      // Önce eski şifreyi doğrula (login endpoint'i ile)
      try {
        final verifyResponse = await _dio.post(
          '/users/login',
          data: {
            'email': (await _getCurrentUserEmail()) ?? '',
            'password': oldPassword,
          },
        );
        
        if (verifyResponse.statusCode != 200) {
          throw Exception('Eski şifre hatalı.');
        }
      } catch (e) {
        AppLogger.warning('Old password verification failed');
        throw Exception('Eski şifre hatalı. Lütfen tekrar deneyin.');
      }

      // Şifre validasyonu
      if (newPassword.length < 6) {
        throw Exception('Şifre en az 6 karakter olmalıdır.');
      }
      
      if (!RegExp(r'^(?=.*[A-Z])(?=.*\d)').hasMatch(newPassword)) {
        throw Exception('Şifre en az bir büyük harf ve bir rakam içermelidir.');
      }

      // Yeni şifreyi güncelle
      final response = await _dio.put(
        '/admin/users/$userId',
        data: {
          'password': newPassword,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Password changed successfully for user: $userId');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Şifre başarıyla değiştirildi.',
        };
      } else {
        AppLogger.warning('Password change failed - unexpected response: ${response.statusCode}');
        throw Exception(response.data['message'] ?? 'Şifre değiştirilemedi.');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        AppLogger.error('Password change failed - server error', e);
        throw Exception(e.response?.data['message'] ?? 'Şifre değiştirilemedi.');
      }
      AppLogger.error('Password change failed - connection error', e);
      throw Exception('Bağlantı hatası: ${e.message}');
    }
  }

  /// Mevcut kullanıcının email'ini al (şifre doğrulama için)
  Future<String?> _getCurrentUserEmail() async {
    try {
      final sharedPrefs = await SharedPreferences.getInstance();
      final userJson = sharedPrefs.getString('user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return userMap['email'] as String?;
      }
    } catch (e) {
      AppLogger.error('Failed to get current user email', e);
    }
    return null;
  }
}

