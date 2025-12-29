import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
// 🔒 ARCHITECTURE: Student model import kaldırıldı (StudentSelectionProvider'a taşındı)
import '../services/auth_service.dart';
import '../services/token_service.dart';

// 🔒 ARCHITECTURE: God Object - Bu sınıf çok fazla sorumluluk taşıyor
// TODO: Bu sınıfı şu şekilde bölmek gerekiyor:
//   1. AuthStateProvider - Sadece authentication state (user, token, isAuthenticated)
//   2. UserProfileProvider - User profile management (updateUser, etc.)
//   3. StudentSelectionProvider - Student selection logic
//   4. SessionProvider - Session management (logout, etc.)
// Bu bölme işlemi büyük bir refactoring gerektirdiği için şu an yapılmadı.
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SharedPreferences _prefs;

  User? _user;
  String? _token;
  Classroom? _classroom;
  // 🔒 ARCHITECTURE: Student selection moved to StudentSelectionProvider
  // Artık burada _selectedStudent yok, StudentSelectionProvider kullanılmalı
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  AuthProvider(this._prefs) {
    // Initialize authentication state from storage
    _initializeAuthState();
  }

  Future<void> _initializeAuthState() async {
    try {
      await _loadUserFromStorage();
    } catch (e) {
      // Silently handle initialization errors
      debugPrint('Auth initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Getters
  User? get user => _user;
  String? get token => _token; // Token caching: TokenService zaten cache kullanıyor
  Classroom? get classroom => _classroom;
  // 🔒 ARCHITECTURE: selectedStudent getter kaldırıldı
  // Artık StudentSelectionProvider kullanılmalı:
  // Provider.of<StudentSelectionProvider>(context).selectedStudent
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isInitialized && _token != null && _user != null;

  // Kullanıcı bilgilerini storage'dan yükle
  Future<void> _loadUserFromStorage() async {
    try {
      // Token caching: Önce cache'den kontrol et, yoksa TokenService'den al
      _token = await TokenService.getToken();
      
      // Clear invalid stored data if token is missing
      if (_token == null) {
        await _clearStoredUserData();
        return;
      }
      
      final userJson = _prefs.getString('user');
      if (userJson != null) {
        try {
          final userMap = jsonDecode(userJson) as Map<String, dynamic>;
          _user = User.fromJson(userMap);
          
          // 🔒 ARCHITECTURE: Student selection loading moved to StudentSelectionProvider
          // StudentSelectionProvider kendi initState'inde yükleyecek
        } catch (e) {
          // Clear corrupted user data
          await _clearStoredUserData();
        }
      }
    } catch (e) {
      // Clear all stored data on error
      await _clearStoredUserData();
    }
  }

  // Clear all stored user data
  Future<void> _clearStoredUserData() async {
    await TokenService.clearAll();
    await _prefs.remove('user');
    // 🔒 ARCHITECTURE: selectedStudent temizleme StudentSelectionProvider'a taşındı
    // StudentSelectionProvider.clearAll() çağrılmalı (logout'ta)
    
    _token = null;
    _user = null;
  }

  // Giriş yap
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(email, password);

      if (response.success) {
        _token = response.token;
        _user = response.user;
        _classroom = response.classroom;

        // Debug: Classroom bilgisini kontrol et
        debugPrint('🔍 Login başarılı:');
        debugPrint('  - User: ${_user?.fullName}');
        debugPrint('  - Classroom: ${_classroom?.id} - ${_classroom?.name}');
        debugPrint('  - Classroom null mu?: ${_classroom == null}');

        // Token'ı hem cache'e hem güvenli storage'a kaydet
        await TokenService.cacheToken(_token!);
        
        // Kullanıcı bilgilerini shared preferences'a kaydet
        await _prefs.setString('user', jsonEncode(response.user.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Kayıt ol
  Future<bool> registerTeacher({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.registerTeacher(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );

      if (response.success) {
        _token = response.token;
        _user = response.teacher;
        _classroom = response.classroom;

        // Token'ı hem cache'e hem güvenli storage'a kaydet
        await TokenService.cacheToken(_token!);
        
        // Kullanıcı bilgilerini shared preferences'a kaydet
        await _prefs.setString('user', jsonEncode(response.teacher.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 🔒 ARCHITECTURE: Student selection methods moved to StudentSelectionProvider
  // Artık bu metodlar yok, StudentSelectionProvider kullanılmalı:
  // Provider.of<StudentSelectionProvider>(context, listen: false).setSelectedStudent(student)
  // Provider.of<StudentSelectionProvider>(context, listen: false).clearSelectedStudent()

  // Çıkış yap
  // 🔒 ARCHITECTURE: logout() metodunda StudentSelectionProvider'ı temizlemek için
  // Bu metodu çağıran yerlerde StudentSelectionProvider.clearAll() da çağrılmalı
  // Örnek: 
  //   await authProvider.logout();
  //   Provider.of<StudentSelectionProvider>(context, listen: false).clearAll();
  Future<void> logout() async {
    _token = null;
    _user = null;
    _classroom = null;
    // 🔒 ARCHITECTURE: _selectedStudent kaldırıldı, StudentSelectionProvider temizlenmeli
    _errorMessage = null;

    await TokenService.clearAll();
    await _prefs.remove('user');
    // 🔒 ARCHITECTURE: selectedStudent temizleme StudentSelectionProvider'a taşındı

    notifyListeners();
  }

  // Kullanıcı bilgilerini güncelle
  Future<void> updateUser(User updatedUser) async {
    _user = updatedUser;
    // Kullanıcı bilgilerini shared preferences'a kaydet
    await _prefs.setString('user', jsonEncode(updatedUser.toJson()));
    notifyListeners();
  }

  // Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

