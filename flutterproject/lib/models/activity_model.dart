import 'lesson_model.dart';

class Activity {
  final String id;
  final String title;
  final String lessonId;
  final String type; // Drawing, Listening, Quiz, Visual
  final int durationMinutes;
  final String? activityType; // Image, Audio, Video, Drawing, Text
  final String? mediaType;
  final String? mediaStorage;
  final String? mediaFileId;
  final String? mediaUrl;
  final List<MediaFile>? mediaFiles;
  final List<String>? textLines;
  final int? readingDuration;
  final String? content;

  Activity({
    required this.id,
    required this.title,
    required this.lessonId,
    required this.type,
    this.durationMinutes = 5,
    this.activityType,
    this.mediaType,
    this.mediaStorage,
    this.mediaFileId,
    this.mediaUrl,
    this.mediaFiles,
    this.textLines,
    this.readingDuration,
    this.content,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      lessonId: json['lesson'] is String
          ? json['lesson']
          : json['lesson']?['_id'] ?? json['lesson']?['id'] ?? '',
      type: json['type'] ?? 'Quiz',
      durationMinutes: json['durationMinutes'] ?? 5,
      activityType: json['activityType'],
      mediaType: json['mediaType'],
      mediaStorage: json['mediaStorage'],
      mediaFileId: json['mediaFileId'],
      mediaUrl: json['mediaUrl'],
      mediaFiles: json['mediaFiles'] != null
          ? (json['mediaFiles'] as List)
              .map((item) => MediaFile.fromJson(item))
              .toList()
          : null,
      textLines: json['textLines'] != null
          ? List<String>.from(json['textLines'])
          : null,
      readingDuration: json['readingDuration'],
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'lesson': lessonId,
      'type': type,
      'durationMinutes': durationMinutes,
      'activityType': activityType,
      'mediaType': mediaType,
      'mediaStorage': mediaStorage,
      'mediaFileId': mediaFileId,
      'mediaUrl': mediaUrl,
      'mediaFiles': mediaFiles?.map((f) => f.toJson()).toList(),
      'textLines': textLines,
      'readingDuration': readingDuration,
      'content': content,
    };
  }
}

class ActivitiesResponse {
  final bool success;
  final List<Activity> activities;
  final PaginationInfo? pagination;

  ActivitiesResponse({
    required this.success,
    required this.activities,
    this.pagination,
  });

  factory ActivitiesResponse.fromJson(Map<String, dynamic> json) {
    return ActivitiesResponse(
      success: json['success'] ?? false,
      activities: json['activities'] != null
          ? (json['activities'] as List)
              .map((item) => Activity.fromJson(item))
              .toList()
          : [],
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'])
          : null,
    );
  }
}

