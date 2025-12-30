import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';
import 'user_profile_provider.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserProfileProvider? _userProfileProvider;

  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

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
      debugPrint('Auth initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isInitialized && _token != null && _userProfileProvider?.user != null;

  Future<void> _loadUserFromStorage() async {
    try {
      _token = await TokenService.getToken();
      
      if (_token == null) {
        await _clearStoredUserData();
        return;
      }
    } catch (e) {
      await _clearStoredUserData();
    }
  }

  Future<void> _clearStoredUserData() async {
    await TokenService.clearAll();
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
        await TokenService.cacheToken(_token!);
        
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
        await TokenService.cacheToken(_token!);
        
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

  Future<void> logout() async {
    _token = null;
    _errorMessage = null;
    await TokenService.clearAll();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

