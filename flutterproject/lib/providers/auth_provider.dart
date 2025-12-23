import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SharedPreferences _prefs;

  User? _user;
  String? _token;
  Classroom? _classroom;
  Student? _selectedStudent;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._prefs) {
    // Storage'dan kullanıcı bilgilerini yükle (async işlem)
    _loadUserFromStorage();
  }

  // Getters
  User? get user => _user;
  String? get token => _token;
  Classroom? get classroom => _classroom;
  Student? get selectedStudent => _selectedStudent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _user != null;

  // Kullanıcı bilgilerini storage'dan yükle
  Future<void> _loadUserFromStorage() async {
    try {
      _token = await _secureStorage.read(key: 'token');
      final userJson = _prefs.getString('user');
      if (userJson != null && _token != null) {
        // JSON string'i parse et
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _user = User.fromJson(userMap);
        
        // Seçili öğrenciyi yükle
        final studentJson = _prefs.getString('selectedStudent');
        if (studentJson != null) {
          try {
            final studentMap = jsonDecode(studentJson) as Map<String, dynamic>;
            _selectedStudent = Student.fromJson(studentMap);
          } catch (e) {
            debugPrint('Seçili öğrenci yükleme hatası: $e');
          }
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Storage yükleme hatası: $e');
    }
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

        // Token'ı güvenli storage'a kaydet
        await _secureStorage.write(key: 'token', value: _token);
        
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

        // Token'ı güvenli storage'a kaydet
        await _secureStorage.write(key: 'token', value: _token);
        
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

  // Öğrenci seç
  void setSelectedStudent(Student student) {
    _selectedStudent = student;
    // Seçili öğrenciyi SharedPreferences'a kaydet
    _prefs.setString('selectedStudent', jsonEncode(student.toJson()));
    notifyListeners();
  }

  // Seçili öğrenciyi temizle
  void clearSelectedStudent() {
    _selectedStudent = null;
    _prefs.remove('selectedStudent');
    notifyListeners();
  }

  // Çıkış yap
  Future<void> logout() async {
    _token = null;
    _user = null;
    _classroom = null;
    _selectedStudent = null;
    _errorMessage = null;

    await _secureStorage.delete(key: 'token');
    await _prefs.remove('user');
    await _prefs.remove('selectedStudent');

    notifyListeners();
  }

  // Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

