import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// User Profile Provider - Kullanıcı profil bilgilerini yönetir
/// 🔒 ARCHITECTURE: AuthProvider'dan ayrıldı - Sadece profil bilgilerinden sorumlu
class UserProfileProvider with ChangeNotifier {
  final SharedPreferences _prefs;

  User? _user;
  Classroom? _classroom;

  UserProfileProvider(this._prefs) {
    // Initialize profile from storage
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    try {
      await _loadUserFromStorage();
    } catch (e) {
      // Silently handle initialization errors
      debugPrint('Profile initialization error: $e');
    }
  }

  // Getters
  User? get user => _user;
  Classroom? get classroom => _classroom;

  // Kullanıcı bilgilerini storage'dan yükle
  Future<void> _loadUserFromStorage() async {
    try {
      final userJson = _prefs.getString('user');
      if (userJson != null) {
        try {
          final userMap = jsonDecode(userJson) as Map<String, dynamic>;
          _user = User.fromJson(userMap);
        } catch (e) {
          // Clear corrupted user data
          await _clearStoredUserData();
        }
      }

      // Classroom bilgisini yükle (eğer varsa)
      final classroomJson = _prefs.getString('classroom');
      if (classroomJson != null) {
        try {
          final classroomMap = jsonDecode(classroomJson) as Map<String, dynamic>;
          _classroom = Classroom.fromJson(classroomMap);
        } catch (e) {
          // Clear corrupted classroom data
          await _prefs.remove('classroom');
        }
      }
    } catch (e) {
      // Clear all stored data on error
      await _clearStoredUserData();
    }
  }

  // Clear all stored user data
  Future<void> _clearStoredUserData() async {
    await _prefs.remove('user');
    await _prefs.remove('classroom');
    _user = null;
    _classroom = null;
  }

  // Kullanıcı bilgilerini set et (login/register sonrası)
  Future<void> setUser(User user, {Classroom? classroom}) async {
    _user = user;
    _classroom = classroom;

    // Kullanıcı bilgilerini shared preferences'a kaydet
    await _prefs.setString('user', jsonEncode(user.toJson()));
    
    // Classroom bilgisini kaydet (eğer varsa)
    if (classroom != null) {
      await _prefs.setString('classroom', jsonEncode({
        'id': classroom.id,
        'name': classroom.name,
        'teacher': classroom.teacher?.toJson(),
        'students': classroom.students.map((s) => s.toJson()).toList(),
      }));
    } else {
      await _prefs.remove('classroom');
    }

    notifyListeners();
  }

  // Kullanıcı bilgilerini güncelle
  Future<void> updateUser(User updatedUser) async {
    _user = updatedUser;
    // Kullanıcı bilgilerini shared preferences'a kaydet
    await _prefs.setString('user', jsonEncode(updatedUser.toJson()));
    notifyListeners();
  }

  // Classroom bilgisini güncelle
  Future<void> updateClassroom(Classroom? classroom) async {
    _classroom = classroom;
    
    if (classroom != null) {
      await _prefs.setString('classroom', jsonEncode({
        'id': classroom.id,
        'name': classroom.name,
        'teacher': classroom.teacher?.toJson(),
        'students': classroom.students.map((s) => s.toJson()).toList(),
      }));
    } else {
      await _prefs.remove('classroom');
    }

    notifyListeners();
  }

  // Profil bilgilerini temizle (logout sonrası)
  Future<void> clearProfile() async {
    await _clearStoredUserData();
    notifyListeners();
  }
}

