import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  final Dio _dio;

  AuthService() : _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  // Öğretmen girişi
  Future<LoginResponse> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/users/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return LoginResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Giriş başarısız: ${response.data?['message'] ?? 'Bilinmeyen hata'}');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final errorData = e.response!.data;
        String errorMessage = 'Giriş başarısız';
        
        if (errorData is Map<String, dynamic>) {
          String backendMessage = errorData['message'] ?? errorMessage;
          // "Sadece öğretmenler" mesajını genel hata mesajına çevir
          if (backendMessage.contains('öğretmenler') || backendMessage.contains('Sadece')) {
            errorMessage = 'Kullanıcı adı ve şifre hatalı.';
          } else {
            errorMessage = backendMessage;
          }
        } else if (errorData is String) {
          errorMessage = errorData;
        }
        
        throw Exception(errorMessage);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.');
      } else {
        throw Exception('Bağlantı hatası: ${e.message ?? 'Bilinmeyen hata'}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Giriş sırasında hata oluştu: ${e.toString()}');
    }
  }

  // Öğretmen kaydı
  Future<RegisterResponse> registerTeacher({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/users/register/teacher',
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        return RegisterResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Kayıt başarısız: ${response.data?['message'] ?? 'Bilinmeyen hata'}');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final errorData = e.response!.data;
        String errorMessage = 'Kayıt başarısız';
        
        if (errorData is Map<String, dynamic>) {
          // Validation hatalarını kontrol et
          if (errorData['errors'] != null && errorData['errors'] is List) {
            final errors = errorData['errors'] as List;
            errorMessage = errors.isNotEmpty 
                ? errors.first['msg'] ?? errorMessage
                : errorMessage;
          } else {
            errorMessage = errorData['message'] ?? errorMessage;
          }
        } else if (errorData is String) {
          errorMessage = errorData;
        }
        
        throw Exception(errorMessage);
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.');
      } else {
        throw Exception('Bağlantı hatası: ${e.message ?? 'Bilinmeyen hata'}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Kayıt sırasında hata oluştu: ${e.toString()}');
    }
  }
}

