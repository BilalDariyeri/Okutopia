import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';

/// Student Selection Provider
/// Öğrenci seçimi mantığını yönetir (AuthProvider'dan ayrıldı)
/// 
/// Bu provider şu sorumlulukları taşır:
/// - Seçili öğrenciyi saklama ve yönetme
/// - Seçili öğrenciyi SharedPreferences'a kaydetme/yükleme
/// - Öğrenci seçimini temizleme
class StudentSelectionProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  
  Student? _selectedStudent;
  bool _isInitialized = false;

  StudentSelectionProvider(this._prefs) {
    // Initialize student selection state from storage
    _initializeStudentSelection();
  }

  /// Initialize student selection from storage
  Future<void> _initializeStudentSelection() async {
    try {
      await _loadSelectedStudentFromStorage();
    } catch (e) {
      // Silently handle initialization errors
      debugPrint('Student selection initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Getters
  Student? get selectedStudent => _selectedStudent;
  bool get isInitialized => _isInitialized;

  /// Load selected student from SharedPreferences
  Future<void> _loadSelectedStudentFromStorage() async {
    try {
      final studentJson = _prefs.getString('selectedStudent');
      if (studentJson != null) {
        try {
          final studentMap = jsonDecode(studentJson) as Map<String, dynamic>;
          _selectedStudent = Student.fromJson(studentMap);
        } catch (e) {
          // Clear corrupted student data
          await _prefs.remove('selectedStudent');
          _selectedStudent = null;
        }
      }
    } catch (e) {
      debugPrint('Error loading selected student: $e');
      _selectedStudent = null;
    }
  }

  /// Set selected student
  /// Öğrenci seçildiğinde çağrılır
  void setSelectedStudent(Student student) {
    _selectedStudent = student;
    // Seçili öğrenciyi SharedPreferences'a kaydet
    _prefs.setString('selectedStudent', jsonEncode(student.toJson()));
    notifyListeners();
  }

  /// Clear selected student
  /// Seçili öğrenciyi temizler (logout veya manuel temizleme için)
  void clearSelectedStudent() {
    _selectedStudent = null;
    _prefs.remove('selectedStudent');
    notifyListeners();
  }

  /// Clear all student selection data
  /// Tüm öğrenci seçim verilerini temizler (logout için)
  Future<void> clearAll() async {
    _selectedStudent = null;
    await _prefs.remove('selectedStudent');
    notifyListeners();
  }
}

