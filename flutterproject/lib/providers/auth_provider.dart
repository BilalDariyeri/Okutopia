import 'package:flutter/foundation.dart';
// 🔒 ARCHITECTURE: SharedPreferences import kaldırıldı (artık kullanılmıyor, TokenService ve UserProfileProvider kullanılıyor)
// 🔒 ARCHITECTURE: User model import kaldırıldı (UserProfileProvider'a taşındı)
import '../services/auth_service.dart';
import '../services/token_service.dart';
import 'user_profile_provider.dart';

// 🔒 ARCHITECTURE: AuthProvider artık sadece authentication state'inden sorumlu
// User profile bilgileri UserProfileProvider'a taşındı
// Student selection logic StudentSelectionProvider'a taşındı
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserProfileProvider? _userProfileProvider; // UserProfileProvider referansı

  String? _token;
  // 🔒 ARCHITECTURE: User ve Classroom UserProfileProvider'a taşındı
  // Artık burada _user ve _classroom yok, UserProfileProvider kullanılmalı
  // 🔒 ARCHITECTURE: Student selection moved to StudentSelectionProvider
  // Artık burada _selectedStudent yok, StudentSelectionProvider kullanılmalı
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  // UserProfileProvider referansını set et (main.dart'dan çağrılacak)
  void setUserProfileProvider(UserProfileProvider provider) {
    _userProfileProvider = provider;
  }

  AuthProvider() {
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
  // 🔒 ARCHITECTURE: user ve classroom getter'ları kaldırıldı
  // Artık UserProfileProvider kullanılmalı:
  // Provider.of<UserProfileProvider>(context).user
  // Provider.of<UserProfileProvider>(context).classroom
  String? get token => _token; // Token caching: TokenService zaten cache kullanıyor
  // 🔒 ARCHITECTURE: selectedStudent getter kaldırıldı
  // Artık StudentSelectionProvider kullanılmalı:
  // Provider.of<StudentSelectionProvider>(context).selectedStudent
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isInitialized && _token != null && _userProfileProvider?.user != null;

  // Token'ı storage'dan yükle
  Future<void> _loadUserFromStorage() async {
    try {
      // Token caching: Önce cache'den kontrol et, yoksa TokenService'den al
      _token = await TokenService.getToken();
      
      // Clear invalid stored data if token is missing
      if (_token == null) {
        await _clearStoredUserData();
        return;
      }
      
      // 🔒 ARCHITECTURE: User ve Classroom bilgileri UserProfileProvider tarafından yükleniyor
      // UserProfileProvider kendi initState'inde yükleyecek
    } catch (e) {
      // Clear all stored data on error
      await _clearStoredUserData();
    }
  }

  // Clear all stored auth data (sadece token)
  Future<void> _clearStoredUserData() async {
    await TokenService.clearAll();
    // 🔒 ARCHITECTURE: User ve Classroom temizleme UserProfileProvider'a taşındı
    // UserProfileProvider.clearProfile() çağrılmalı (logout'ta)
    // 🔒 ARCHITECTURE: selectedStudent temizleme StudentSelectionProvider'a taşındı
    // StudentSelectionProvider.clearAll() çağrılmalı (logout'ta)
    
    _token = null;
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

        // Debug: Classroom bilgisini kontrol et
        debugPrint('🔍 Login başarılı:');
        debugPrint('  - User: ${response.user.fullName}');
        debugPrint('  - Classroom: ${response.classroom?.id} - ${response.classroom?.name}');
        debugPrint('  - Classroom null mu?: ${response.classroom == null}');

        // Token'ı hem cache'e hem güvenli storage'a kaydet
        await TokenService.cacheToken(_token!);
        
        // 🔒 ARCHITECTURE: User ve Classroom bilgileri UserProfileProvider'a kaydediliyor
        if (_userProfileProvider != null) {
          await _userProfileProvider!.setUser(response.user, classroom: response.classroom);
        }

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

        // Token'ı hem cache'e hem güvenli storage'a kaydet
        await TokenService.cacheToken(_token!);
        
        // 🔒 ARCHITECTURE: User ve Classroom bilgileri UserProfileProvider'a kaydediliyor
        if (_userProfileProvider != null) {
          await _userProfileProvider!.setUser(response.teacher, classroom: response.classroom);
        }

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
  // 🔒 ARCHITECTURE: logout() metodunda UserProfileProvider ve StudentSelectionProvider'ı temizlemek için
  // Bu metodu çağıran yerlerde UserProfileProvider.clearProfile() ve StudentSelectionProvider.clearAll() da çağrılmalı
  // Örnek: 
  //   await authProvider.logout();
  //   Provider.of<UserProfileProvider>(context, listen: false).clearProfile();
  //   Provider.of<StudentSelectionProvider>(context, listen: false).clearAll();
  Future<void> logout() async {
    _token = null;
    // 🔒 ARCHITECTURE: User ve Classroom temizleme UserProfileProvider'a taşındı
    // UserProfileProvider.clearProfile() çağrılmalı
    // 🔒 ARCHITECTURE: _selectedStudent kaldırıldı, StudentSelectionProvider temizlenmeli
    _errorMessage = null;

    await TokenService.clearAll();
    // 🔒 ARCHITECTURE: User ve Classroom temizleme UserProfileProvider'a taşındı
    // UserProfileProvider.clearProfile() çağrılmalı
    // 🔒 ARCHITECTURE: selectedStudent temizleme StudentSelectionProvider'a taşındı

    notifyListeners();
  }

  // 🔒 ARCHITECTURE: updateUser metodu UserProfileProvider'a taşındı
  // Artık UserProfileProvider.updateUser() kullanılmalı

  // Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

