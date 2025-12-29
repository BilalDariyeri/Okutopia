class MiniQuestion {
  final String id;
  final String? activityId; // Artık optional - etkinlik veya ders bağlantısı
  final String? lessonId; // Yeni: ders bağlantısı
  final String questionType; // Image, Audio, Video, Drawing, Text
  final String? questionFormat; // Soru formatı (opsiyonel)
  final String? mediaFileId;
  final String? mediaUrl;
  final Map<String, dynamic>? data;
  final String? mediaType;
  final String? mediaStorage;
  final String? correctAnswer; // Artık optional

  MiniQuestion({
    required this.id,
    this.activityId,
    this.lessonId,
    required this.questionType,
    this.questionFormat,
    this.correctAnswer,
    this.mediaFileId,
    this.mediaUrl,
    this.data,
    this.mediaType,
    this.mediaStorage,
  });

  factory MiniQuestion.fromJson(Map<String, dynamic> json) {
    return MiniQuestion(
      id: json['_id'] ?? json['id'] ?? '',
      activityId: json['activity'] != null
          ? (json['activity'] is String
          ? json['activity']
              : json['activity']?['_id'] ?? json['activity']?['id'] ?? '')
          : null,
      lessonId: json['lesson'] != null
          ? (json['lesson'] is String
              ? json['lesson']
              : json['lesson']?['_id'] ?? json['lesson']?['id'] ?? '')
          : null,
      questionType: json['questionType'] ?? 'Text',
      questionFormat: json['questionFormat'],
      correctAnswer: json['correctAnswer'],
      mediaFileId: json['mediaFileId'],
      mediaUrl: json['mediaUrl'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      mediaType: json['mediaType'],
      mediaStorage: json['mediaStorage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'activity': activityId,
      'lesson': lessonId,
      'questionType': questionType,
      'questionFormat': questionFormat,
      'correctAnswer': correctAnswer,
      'mediaFileId': mediaFileId,
      'mediaUrl': mediaUrl,
      'data': data,
      'mediaType': mediaType,
      'mediaStorage': mediaStorage,
    };
  }
}

class QuestionsResponse {
  final bool success;
  final List<MiniQuestion> questions;
  final PaginationInfo? pagination;

  QuestionsResponse({
    required this.success,
    required this.questions,
    this.pagination,
  });

  factory QuestionsResponse.fromJson(Map<String, dynamic> json) {
    return QuestionsResponse(
      success: json['success'] ?? false,
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((item) => MiniQuestion.fromJson(item))
              .toList()
          : [],
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'])
          : null,
    );
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int pages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 50,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 0,
    );
  }
}

