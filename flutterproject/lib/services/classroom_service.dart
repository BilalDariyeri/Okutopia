import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/student_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ClassroomService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ClassroomService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        )),
        _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  /// Öğretmenin sınıflarını getir
  /// GET /api/classrooms/teacher/:teacherId
  Future<List<ClassroomInfo>> getTeacherClassrooms(String teacherId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.get(
        '/classrooms/teacher/$teacherId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final classrooms = (response.data['classrooms'] as List)
            .map((c) => ClassroomInfo.fromJson(c))
            .toList();
        return classrooms;
      } else {
        throw Exception(
          response.data['message'] ?? 'Sınıflar yüklenemedi.',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.');
      } else if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Sınıflar yüklenemedi.';
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sınıflar yüklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Sınıftaki tüm öğrencileri getir
  /// GET /api/classrooms/:classId/students
  Future<ClassroomStudentsResponse> getClassroomStudents(
    String classId,
    String? teacherId,
  ) async {
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
        '/classrooms/$classId/students',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ClassroomStudentsResponse.fromJson(response.data);
      } else {
        throw Exception(
          response.data['message'] ?? 'Öğrenciler yüklenemedi.',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.');
      } else if (e.response != null) {
        final responseData = e.response?.data;
        String message = 'Öğrenciler yüklenemedi.';
        
        // Validation hatalarını kontrol et
        if (responseData is Map<String, dynamic>) {
          if (responseData['errors'] != null && responseData['errors'] is List) {
            final errors = responseData['errors'] as List;
            if (errors.isNotEmpty) {
              message = errors.first['msg'] ?? message;
            }
          } else if (responseData['message'] != null) {
            message = responseData['message'];
          } else if (responseData['error'] != null) {
            message = responseData['error'].toString();
          }
        }
        
        // 500 hatası için özel mesaj
        if (e.response?.statusCode == 500) {
          message = 'Sunucu hatası: $message. Lütfen daha sonra tekrar deneyin.';
        }
        
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Öğrenciler yüklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Sınıfa yeni öğrenci ekle
  /// POST /api/classrooms/:classId/add-student
  /// Token'dan öğretmen ID'si otomatik alınır
  Future<Map<String, dynamic>> addStudentToClassroom({
    required String classId,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      // Request body'yi hazırla
      final requestData = {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
      };

      final response = await _dio.post(
        '/classrooms/$classId/add-student',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Öğrenci başarıyla eklendi.',
          'student': response.data['student'],
        };
      } else {
        throw Exception(
          response.data['message'] ?? 'Öğrenci eklenemedi.',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.');
      } else if (e.response != null) {
        final responseData = e.response?.data;
        String message = 'Öğrenci eklenemedi.';
        
        // Validation hatalarını kontrol et
        if (responseData is Map<String, dynamic>) {
          if (responseData['errors'] != null && responseData['errors'] is List) {
            final errors = responseData['errors'] as List;
            if (errors.isNotEmpty) {
              message = errors.first['msg'] ?? message;
            }
          } else if (responseData['message'] != null) {
            message = responseData['message'];
          }
        }
        
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Öğrenci eklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Öğrenciyi sınıftan çıkar ve veritabanından sil
  /// DELETE /api/classrooms/:classId/students/:studentId
  Future<Map<String, dynamic>> removeStudentFromClassroom({
    required String classId,
    required String studentId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
      }

      final response = await _dio.delete(
        '/classrooms/$classId/students/$studentId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Öğrenci başarıyla silindi.',
        };
      } else {
        throw Exception(
          response.data['message'] ?? 'Öğrenci silinemedi.',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.');
      } else if (e.response != null) {
        final responseData = e.response?.data;
        String message = 'Öğrenci silinemedi.';
        
        // Validation hatalarını kontrol et
        if (responseData is Map<String, dynamic>) {
          if (responseData['errors'] != null && responseData['errors'] is List) {
            final errors = responseData['errors'] as List;
            if (errors.isNotEmpty) {
              message = errors.first['msg'] ?? message;
            }
          } else if (responseData['message'] != null) {
            message = responseData['message'];
          }
        }
        
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Öğrenci silinirken hata oluştu: ${e.toString()}');
    }
  }
}

