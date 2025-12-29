import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/category_model.dart';
import '../models/group_model.dart';
import '../models/lesson_model.dart';
import '../models/activity_model.dart';
import '../models/mini_question_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ContentService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ContentService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      ),
      _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  /// Tüm kategorileri getir
  /// GET /api/content/categories
  Future<CategoriesResponse> getAllCategories({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      // Token opsiyonel - kategoriler public olabilir
      final token = await _getToken();

      final options = Options();
      if (token != null) {
        options.headers = {'Authorization': 'Bearer $token'};
      }

      final response = await _dio.get(
        '/content/categories',
        queryParameters: {'page': page, 'limit': limit},
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return CategoriesResponse.fromJson(response.data);
      } else {
        throw Exception(response.data['message'] ?? 'Kategoriler yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
        );
      } else if (e.response != null) {
        final message =
            e.response?.data['message'] ?? 'Kategoriler yüklenemedi.';
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Kategoriler yüklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Kategoriye göre grupları getir
  /// GET /api/content/category/:categoryId/hierarchy
  Future<GroupsResponse> getGroupsByCategory({
    required String categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();

      final options = Options();
      if (token != null) {
        options.headers = {'Authorization': 'Bearer $token'};
      }

      final response = await _dio.get(
        '/content/category/$categoryId/hierarchy',
        queryParameters: {'page': page, 'limit': limit},
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return GroupsResponse.fromJson(response.data);
      } else {
        throw Exception(response.data['message'] ?? 'Gruplar yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
        );
      } else if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Gruplar yüklenemedi.';
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Gruplar yüklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Gruba göre dersleri getir
  /// GET /api/content/group/:groupId/lessons
  Future<LessonsResponse> getLessonsByGroup({
    required String groupId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();

      final options = Options();
      if (token != null) {
        options.headers = {'Authorization': 'Bearer $token'};
      }

      final response = await _dio.get(
        '/content/group/$groupId/lessons',
        queryParameters: {'page': page, 'limit': limit},
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return LessonsResponse.fromJson(response.data);
      } else {
        throw Exception(response.data['message'] ?? 'Dersler yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
        );
      } else if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Dersler yüklenemedi.';
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Dersler yüklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Derse göre etkinlikleri getir
  /// GET /api/content/lesson/:lessonId/activities
  Future<ActivitiesResponse> getActivitiesByLesson({
    required String lessonId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();

      final options = Options();
      if (token != null) {
        options.headers = {'Authorization': 'Bearer $token'};
      }

      final response = await _dio.get(
        '/content/lesson/$lessonId/activities',
        queryParameters: {'page': page, 'limit': limit},
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ActivitiesResponse.fromJson(response.data);
      } else {
        throw Exception(response.data['message'] ?? 'Etkinlikler yüklenemedi.');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
        );
      } else if (e.response != null) {
        final message =
            e.response?.data['message'] ?? 'Etkinlikler yüklenemedi.';
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Etkinlikler yüklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Etkinliğe göre soruları getir
  /// GET /api/content/activities/:activityId/questions
  Future<QuestionsResponse> getQuestionsForActivity({
    required String activityId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();

      final options = Options();
      if (token != null) {
        options.headers = {'Authorization': 'Bearer $token'};
      }

      final response = await _dio.get(
        '/content/activities/$activityId/questions',
        queryParameters: {'page': page, 'limit': limit},
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return QuestionsResponse.fromJson(response.data);
      } else {
        throw Exception(response.data['message'] ?? 'Sorular yüklenemedi.');
      }
    } on DioException catch (e) {
      // 404 hatası normal bir durum (soru yoksa)
      if (e.response?.statusCode == 404) {
        return QuestionsResponse(
          success: true,
          questions: [],
          pagination: null,
        );
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
        );
      } else if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Sorular yüklenemedi.';
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sorular yüklenirken hata oluştu: ${e.toString()}');
    }
  }

  /// Derse göre soruları getir
  /// GET /api/content/lessons/:lessonId/questions
  Future<QuestionsResponse> getQuestionsForLesson({
    required String lessonId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();

      final options = Options();
      if (token != null) {
        options.headers = {'Authorization': 'Bearer $token'};
      }

      final response = await _dio.get(
        '/content/lessons/$lessonId/questions',
        queryParameters: {'page': page, 'limit': limit},
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return QuestionsResponse.fromJson(response.data);
      } else {
        throw Exception(response.data['message'] ?? 'Sorular yüklenemedi.');
      }
    } on DioException catch (e) {
      // 404 hatası normal bir durum (soru yoksa)
      if (e.response?.statusCode == 404) {
        return QuestionsResponse(
          success: true,
          questions: [],
          pagination: null,
        );
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.',
        );
      } else if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Sorular yüklenemedi.';
        throw Exception(message);
      } else {
        throw Exception('Beklenmeyen bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sorular yüklenirken hata oluştu: ${e.toString()}');
    }
  }
}
