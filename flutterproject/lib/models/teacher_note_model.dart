class TeacherNote {
  final String id;
  final String studentId;
  final String? teacherId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? priority;
  final String? category;

  TeacherNote({
    required this.id,
    required this.studentId,
    this.teacherId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.priority,
    this.category,
  });

  factory TeacherNote.fromJson(Map<String, dynamic> json) {
    return TeacherNote(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? json['student']?.toString() ?? '',
      teacherId: json['teacherId']?.toString() ?? json['teacher']?.toString(),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      priority: json['priority']?.toString(),
      category: json['category']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      if (teacherId != null) 'teacherId': teacherId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (priority != null) 'priority': priority,
      if (category != null) 'category': category,
    };
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      return 'Bugün ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Dün ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${createdAt.day}.${createdAt.month}.${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
  }
}

