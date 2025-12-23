class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role,
    };
  }
}

class Classroom {
  final String id;
  final String name;
  final User? teacher;
  final List<User> students;

  Classroom({
    required this.id,
    required this.name,
    this.teacher,
    required this.students,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {
    User? teacher;
    if (json['teacher'] != null) {
      if (json['teacher'] is Map<String, dynamic>) {
        final teacherMap = json['teacher'] as Map<String, dynamic>;
        // Backend'den gelen teacher objesi role içermeyebilir, default olarak 'Teacher' ekle
        if (!teacherMap.containsKey('role')) {
          teacherMap['role'] = 'Teacher';
        }
        teacher = User.fromJson(teacherMap);
      } else if (json['teacher'] is String) {
        // Sadece ID gelmişse
        teacher = User(
          id: json['teacher'] as String,
          firstName: '',
          lastName: '',
          email: '',
          role: 'Teacher',
        );
      }
    }

    List<User> students = [];
    if (json['students'] != null && json['students'] is List) {
      students = (json['students'] as List)
          .map((student) {
            if (student is Map<String, dynamic>) {
              return User.fromJson(student);
            } else if (student is String) {
              return User(
                id: student,
                firstName: '',
                lastName: '',
                email: '',
                role: 'Student',
              );
            }
            return User(
              id: '',
              firstName: '',
              lastName: '',
              email: '',
              role: 'Student',
            );
          })
          .where((user) => user.id.isNotEmpty)
          .toList();
    }

    return Classroom(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      teacher: teacher,
      students: students,
    );
  }
}

class LoginResponse {
  final bool success;
  final String message;
  final String token;
  final User user;
  final Classroom? classroom;

  LoginResponse({
    required this.success,
    required this.message,
    required this.token,
    required this.user,
    this.classroom,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      token: json['token'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
      classroom: json['classroom'] != null
          ? Classroom.fromJson(json['classroom'])
          : null,
    );
  }
}

class RegisterResponse {
  final bool success;
  final String message;
  final String token;
  final User teacher;
  final Classroom? classroom;

  RegisterResponse({
    required this.success,
    required this.message,
    required this.token,
    required this.teacher,
    this.classroom,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      token: json['token'] ?? '',
      teacher: User.fromJson(json['teacher'] ?? {}),
      classroom: json['classroom'] != null
          ? Classroom.fromJson(json['classroom'])
          : null,
    );
  }
}

