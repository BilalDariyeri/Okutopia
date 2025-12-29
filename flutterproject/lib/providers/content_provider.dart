import 'package:flutter/foundation.dart' hide Category;
import '../models/category_model.dart';
import '../models/group_model.dart';
import '../models/lesson_model.dart';
import '../models/activity_model.dart';
import '../services/content_service.dart';
import '../services/cache_service.dart';
import '../utils/app_logger.dart';

/// Zero-Loading UI için Content Provider
/// Cache-first stratejisi ile anında veri gösterimi sağlar
class ContentProvider with ChangeNotifier {
  final ContentService _contentService = ContentService();
  final CacheService _cacheService = CacheService();

  // Cache'lenmiş veriler
  List<Category>? _cachedCategories;
  Map<String, List<Group>> _cachedGroups = {};
  Map<String, List<Lesson>> _cachedLessons = {};
  Map<String, List<Activity>> _cachedActivities = {};

  // Loading durumları (sadece background refresh için)
  bool _isRefreshingCategories = false;
  bool _isRefreshingGroups = false;
  bool _isRefreshingLessons = false;
  bool _isRefreshingActivities = false;

  // Getters
  List<Category>? get categories => _cachedCategories;
  bool get isRefreshingCategories => _isRefreshingCategories;

  List<Group>? getGroups(String categoryId) => _cachedGroups[categoryId];
  bool isRefreshingGroups(String categoryId) => _isRefreshingGroups;

  List<Lesson>? getLessons(String groupId) => _cachedLessons[groupId];
  bool isRefreshingLessons(String groupId) => _isRefreshingLessons;

  List<Activity>? getActivities(String lessonId) => _cachedActivities[lessonId];
  bool isRefreshingActivities(String lessonId) => _isRefreshingActivities;

  /// Kategorileri yükle (Cache-First)
  Future<void> loadCategories({bool forceRefresh = false}) async {
    // 1. Cache'den kontrol et (force refresh değilse)
    if (!forceRefresh) {
      final cached = _cacheService.get<List<Category>>(CacheService.categoriesKey());
      if (cached != null) {
      _cachedCategories = cached;
      // notifyListeners() kaldırıldı - gereksiz rebuild'i önlemek için
      AppLogger.debug('Categories loaded from cache');
      
      // Arka planda refresh yap (daha sonra, performans için geciktirildi)
      Future.delayed(const Duration(seconds: 2), () {
        _refreshCategoriesInBackground();
      });
      return;
      }
    }

    // 2. Cache yoksa veya force refresh ise API'den çek
    try {
      _isRefreshingCategories = true;
      notifyListeners();

      final response = await _contentService.getAllCategories();
      _cachedCategories = response.categories;
      
      // Cache'e kaydet
      await _cacheService.set(CacheService.categoriesKey(), _cachedCategories);
      
      _isRefreshingCategories = false;
      notifyListeners();
    } catch (e) {
      _isRefreshingCategories = false;
      AppLogger.error('Load categories error', e);
      notifyListeners();
      rethrow;
    }
  }

  /// Arka planda kategorileri refresh et (kullanıcı görmez)
  Future<void> _refreshCategoriesInBackground() async {
    try {
      final response = await _contentService.getAllCategories();
      if (response.categories.isNotEmpty) {
        _cachedCategories = response.categories;
        await _cacheService.set(CacheService.categoriesKey(), _cachedCategories);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.debug('Background refresh categories failed: $e');
      // Hata olsa bile sessizce devam et
    }
  }

  /// Grupları yükle (Cache-First)
  Future<void> loadGroups(String categoryId, {bool forceRefresh = false}) async {
    // 1. Cache'den kontrol et
    if (!forceRefresh) {
      final cached = _cacheService.get<List<Group>>(CacheService.groupsKey(categoryId));
      if (cached != null) {
        _cachedGroups[categoryId] = cached;
        notifyListeners();
        AppLogger.debug('Groups loaded from cache: $categoryId');
        
        // Arka planda refresh
        _refreshGroupsInBackground(categoryId);
        return;
      }
    }

    // 2. API'den çek
    try {
      _isRefreshingGroups = true;
      notifyListeners();

      final response = await _contentService.getGroupsByCategory(categoryId: categoryId);
      _cachedGroups[categoryId] = response.groups;
      
      await _cacheService.set(CacheService.groupsKey(categoryId), _cachedGroups[categoryId]);
      
      _isRefreshingGroups = false;
      notifyListeners();
    } catch (e) {
      _isRefreshingGroups = false;
      AppLogger.error('Load groups error: $categoryId', e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshGroupsInBackground(String categoryId) async {
    try {
      final response = await _contentService.getGroupsByCategory(categoryId: categoryId);
      if (response.groups.isNotEmpty) {
        _cachedGroups[categoryId] = response.groups;
        await _cacheService.set(CacheService.groupsKey(categoryId), _cachedGroups[categoryId]);
        // notifyListeners() kaldırıldı - gereksiz rebuild'i önlemek için
      }
    } catch (e) {
      AppLogger.debug('Background refresh groups failed: $e');
    }
  }

  /// Dersleri yükle (Cache-First)
  Future<void> loadLessons(String groupId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cacheService.get<List<Lesson>>(CacheService.lessonsKey(groupId));
      if (cached != null) {
        _cachedLessons[groupId] = cached;
        notifyListeners();
        _refreshLessonsInBackground(groupId);
        return;
      }
    }

    try {
      _isRefreshingLessons = true;
      notifyListeners();

      final response = await _contentService.getLessonsByGroup(groupId: groupId);
      _cachedLessons[groupId] = response.lessons;
      
      await _cacheService.set(CacheService.lessonsKey(groupId), _cachedLessons[groupId]);
      
      _isRefreshingLessons = false;
      notifyListeners();
    } catch (e) {
      _isRefreshingLessons = false;
      AppLogger.error('Load lessons error: $groupId', e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshLessonsInBackground(String groupId) async {
    try {
      final response = await _contentService.getLessonsByGroup(groupId: groupId);
      if (response.lessons.isNotEmpty) {
        _cachedLessons[groupId] = response.lessons;
        await _cacheService.set(CacheService.lessonsKey(groupId), _cachedLessons[groupId]);
        // notifyListeners() kaldırıldı - gereksiz rebuild'i önlemek için
      }
    } catch (e) {
      AppLogger.debug('Background refresh lessons failed: $e');
    }
  }

  /// Aktiviteleri yükle (Cache-First)
  Future<void> loadActivities(String lessonId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cacheService.get<List<Activity>>(CacheService.activitiesKey(lessonId));
      if (cached != null) {
        _cachedActivities[lessonId] = cached;
        notifyListeners();
        _refreshActivitiesInBackground(lessonId);
        return;
      }
    }

    try {
      _isRefreshingActivities = true;
      notifyListeners();

      final response = await _contentService.getActivitiesByLesson(lessonId: lessonId);
      _cachedActivities[lessonId] = response.activities;
      
      await _cacheService.set(CacheService.activitiesKey(lessonId), _cachedActivities[lessonId]);
      
      _isRefreshingActivities = false;
      notifyListeners();
    } catch (e) {
      _isRefreshingActivities = false;
      AppLogger.error('Load activities error: $lessonId', e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshActivitiesInBackground(String lessonId) async {
    try {
      final response = await _contentService.getActivitiesByLesson(lessonId: lessonId);
      if (response.activities.isNotEmpty) {
        _cachedActivities[lessonId] = response.activities;
        await _cacheService.set(CacheService.activitiesKey(lessonId), _cachedActivities[lessonId]);
        // notifyListeners() kaldırıldı - gereksiz rebuild'i önlemek için
      }
    } catch (e) {
      AppLogger.debug('Background refresh activities failed: $e');
    }
  }

  /// Cache'i temizle
  void clearCache() {
    _cachedCategories = null;
    _cachedGroups.clear();
    _cachedLessons.clear();
    _cachedActivities.clear();
    notifyListeners();
  }
}

