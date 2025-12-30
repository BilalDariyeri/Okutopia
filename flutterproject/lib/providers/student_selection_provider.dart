import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';
import '../services/classroom_service.dart';
import '../models/user_model.dart';

/// Student Selection Provider
/// Öğrenci seçimi mantığını yönetir (AuthProvider'dan ayrıldı)
/// 
/// Bu provider şu sorumlulukları taşır:
/// - Seçili öğrenciyi saklama ve yönetme
/// - Seçili öğrenciyi SharedPreferences'a kaydetme/yükleme
/// - Öğrenci listesini cache'leme ve yönetme (Cache-First Strategy)
/// - Öğrenci seçimini temizleme
class StudentSelectionProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  final ClassroomService _classroomService = ClassroomService();
  
  Student? _selectedStudent;
  List<Student> _studentsList = [];
  bool _isLoadingStudents = false;
  bool _isInitialized = false;

  StudentSelectionProvider(this._prefs) {
    // Initialize student selection state from storage
    _initializeStudentSelection();
  }

  Future<void> _initializeStudentSelection() async {
    try {
      await _loadSelectedStudentFromStorage();
      await _loadStudentsFromCache();
    } catch (e) {
      debugPrint('Student selection initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Student? get selectedStudent => _selectedStudent;
  List<Student> get studentsList => _studentsList;
  bool get isLoadingStudents => _isLoadingStudents;
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

  void setSelectedStudent(Student student) {
    _selectedStudent = student;
    // Seçili öğrenciyi SharedPreferences'a kaydet
    _prefs.setString('selectedStudent', jsonEncode(student.toJson()));
    notifyListeners();
  }

  void clearSelectedStudent() {
    _selectedStudent = null;
    _prefs.remove('selectedStudent');
    notifyListeners();
  }

  Future<void> clearAll() async {
    _selectedStudent = null;
    _studentsList = [];
    await _prefs.remove('selectedStudent');
    await _prefs.remove('studentsList');
    notifyListeners();
  }

  Future<void> loadStudents({
    required User user,
    Classroom? classroom,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _studentsList.isNotEmpty) {
      _refreshStudentsInBackground(user: user, classroom: classroom);
      return;
    }

    // Cache boş veya forceRefresh=true ise API'den çek
    _isLoadingStudents = true;
    notifyListeners();

    try {
      Classroom? currentClassroom = classroom;

      if (currentClassroom == null || currentClassroom.id.isEmpty) {
        final classrooms = await _classroomService.getTeacherClassrooms(user.id);
        if (classrooms.isEmpty) {
          throw Exception('Öğretmenin sınıfı bulunamadı. Lütfen yönetici ile iletişime geçin.');
        }
        currentClassroom = Classroom(
          id: classrooms.first.id,
          name: classrooms.first.name,
          teacher: user,
          students: [],
        );
      }

      final response = await _classroomService.getClassroomStudents(
        currentClassroom.id,
        user.id,
      );

      _studentsList = response.students;
      
      // Cache'e kaydet
      await _prefs.setString('studentsList', jsonEncode(
        _studentsList.map((s) => s.toJson()).toList(),
      ));

      _isLoadingStudents = false;
      notifyListeners();
    } catch (e) {
      _isLoadingStudents = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshStudentsInBackground({
    required User user,
    Classroom? classroom,
  }) async {
    try {
      Classroom? currentClassroom = classroom;

      if (currentClassroom == null || currentClassroom.id.isEmpty) {
        final classrooms = await _classroomService.getTeacherClassrooms(user.id);
        if (classrooms.isNotEmpty) {
          currentClassroom = Classroom(
            id: classrooms.first.id,
            name: classrooms.first.name,
            teacher: user,
            students: [],
          );
        } else {
          return; // Classroom bulunamadı, güncelleme yapma
        }
      }

      final response = await _classroomService.getClassroomStudents(
        currentClassroom.id,
        user.id,
      );

      // Sadece veri değiştiyse güncelle
      if (response.students.length != _studentsList.length ||
          response.students.any((s) => !_studentsList.any((cached) => cached.id == s.id))) {
        _studentsList = response.students;
        
        // Cache'e kaydet
        await _prefs.setString('studentsList', jsonEncode(
          _studentsList.map((s) => s.toJson()).toList(),
        ));

        notifyListeners();
      }
    } catch (e) {
      // Ignore background refresh errors
    }
  }

  void setStudentsList(List<Student> students) {
    _studentsList = students;
    // Cache'e kaydet
    _prefs.setString('studentsList', jsonEncode(
      _studentsList.map((s) => s.toJson()).toList(),
    ));
    notifyListeners();
  }

  Future<void> _loadStudentsFromCache() async {
    try {
      final studentsJson = _prefs.getString('studentsList');
      if (studentsJson != null) {
        try {
          final studentsList = (jsonDecode(studentsJson) as List)
              .map((s) => Student.fromJson(s as Map<String, dynamic>))
              .toList();
          _studentsList = studentsList;
        } catch (e) {
          await _prefs.remove('studentsList');
          _studentsList = [];
        }
      }
    } catch (e) {
      _studentsList = [];
    }
  }
}
