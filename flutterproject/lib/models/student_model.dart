class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final StudentProgress progress;
  final DateTime? lastActivity;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.progress,
    this.lastActivity,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      role: json['role'] ?? 'Student',
      progress: json['progress'] != null
          ? StudentProgress.fromJson(json['progress'])
          : StudentProgress(overallScore: 0, completedActivities: 0),
      lastActivity: json['lastActivity'] != null
          ? DateTime.tryParse(json['lastActivity'].toString())
          : null,
    );
  }

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return first + last;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'progress': progress.toJson(),
      'lastActivity': lastActivity?.toIso8601String(),
    };
  }
}

class StudentProgress {
  final int overallScore;
  final int completedActivities;
  final int totalActivities; // Varsayılan 25

  StudentProgress({
    required this.overallScore,
    required this.completedActivities,
    this.totalActivities = 25,
  });

  factory StudentProgress.fromJson(Map<String, dynamic> json) {
    return StudentProgress(
      overallScore: json['overallScore'] ?? 0,
      completedActivities: json['completedActivities'] ?? 0,
      totalActivities: json['totalActivities'] ?? 25,
    );
  }

  double get progressPercentage {
    if (totalActivities == 0) return 0.0;
    return (completedActivities / totalActivities).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'overallScore': overallScore,
      'completedActivities': completedActivities,
      'totalActivities': totalActivities,
    };
  }
}

class ClassroomStudentsResponse {
  final bool success;
  final ClassroomInfo classroom;
  final List<Student> students;
  final int totalStudents;

  ClassroomStudentsResponse({
    required this.success,
    required this.classroom,
    required this.students,
    required this.totalStudents,
  });

  factory ClassroomStudentsResponse.fromJson(Map<String, dynamic> json) {
    return ClassroomStudentsResponse(
      success: json['success'] ?? false,
      classroom: ClassroomInfo.fromJson(json['classroom'] ?? {}),
      students: (json['students'] as List<dynamic>?)
              ?.map((s) => Student.fromJson(s))
              .toList() ??
          [],
      totalStudents: json['totalStudents'] ?? 0,
    );
  }
}

class ClassroomInfo {
  final String id;
  final String name;
  final String? teacherId;

  ClassroomInfo({
    required this.id,
    required this.name,
    this.teacherId,
  });

  factory ClassroomInfo.fromJson(Map<String, dynamic> json) {
    return ClassroomInfo(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      teacherId: json['teacher']?.toString(),
    );
  }
}

