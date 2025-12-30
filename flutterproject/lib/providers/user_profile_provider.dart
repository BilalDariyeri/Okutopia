import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserProfileProvider with ChangeNotifier {
  final SharedPreferences _prefs;

  User? _user;
  Classroom? _classroom;
  bool _isLoadingProfile = false;

  UserProfileProvider(this._prefs) {
    // Initialize profile from storage
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    try {
      await _loadUserFromStorage();
    } catch (e) {
      debugPrint('Profile initialization error: $e');
    }
  }

  User? get user => _user;
  Classroom? get classroom => _classroom;
  bool get isLoadingProfile => _isLoadingProfile;

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

  Future<void> setUser(User user, {Classroom? classroom, bool forceRefresh = false}) async {
    if (!forceRefresh && _user != null && _user!.id == user.id) {
      _user = user;
      if (classroom != null) {
        _classroom = classroom;
      }
    } else {
      _user = user;
      _classroom = classroom;
    }

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

  Future<void> updateUser(User updatedUser) async {
    _user = updatedUser;
    // Kullanıcı bilgilerini shared preferences'a kaydet
    await _prefs.setString('user', jsonEncode(updatedUser.toJson()));
    notifyListeners();
  }

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

  Future<void> clearProfile() async {
    await _clearStoredUserData();
    _isLoadingProfile = false;
    notifyListeners();
  }

  Future<void> refreshProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _user != null) {
      return;
    }

    // forceRefresh=true ise cache'den yeniden yükle
    _isLoadingProfile = true;
    notifyListeners();

    try {
      await _loadUserFromStorage();
      _isLoadingProfile = false;
      notifyListeners();
    } catch (e) {
      _isLoadingProfile = false;
      notifyListeners();
      rethrow;
    }
  }
}

