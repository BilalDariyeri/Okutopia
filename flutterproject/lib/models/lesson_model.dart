class Lesson {
  final String id;
  final String title;
  final String groupId;
  final String targetContent;
  final int orderIndex;
  final String? lessonType;
  final String? mediaType;
  final String? mediaStorage;
  final String? mediaFileId;
  final String? mediaUrl;
  final List<MediaFile>? mediaFiles;

  Lesson({
    required this.id,
    required this.title,
    required this.groupId,
    required this.targetContent,
    required this.orderIndex,
    this.lessonType,
    this.mediaType,
    this.mediaStorage,
    this.mediaFileId,
    this.mediaUrl,
    this.mediaFiles,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      groupId: json['group'] is String
          ? json['group']
          : json['group']?['_id'] ?? json['group']?['id'] ?? '',
      targetContent: json['targetContent'] ?? '',
      orderIndex: json['orderIndex'] ?? 0,
      lessonType: json['lessonType'],
      mediaType: json['mediaType'],
      mediaStorage: json['mediaStorage'],
      mediaFileId: json['mediaFileId'],
      mediaUrl: json['mediaUrl'],
      mediaFiles: json['mediaFiles'] != null
          ? (json['mediaFiles'] as List)
              .map((item) => MediaFile.fromJson(item))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'group': groupId,
      'targetContent': targetContent,
      'orderIndex': orderIndex,
      'lessonType': lessonType,
      'mediaType': mediaType,
      'mediaStorage': mediaStorage,
      'mediaFileId': mediaFileId,
      'mediaUrl': mediaUrl,
      'mediaFiles': mediaFiles?.map((f) => f.toJson()).toList(),
    };
  }
}

class MediaFile {
  final String fileId;
  final String mediaType;
  final int order;

  MediaFile({
    required this.fileId,
    required this.mediaType,
    required this.order,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      fileId: json['fileId'] is String
          ? json['fileId']
          : json['fileId']?['_id'] ?? json['fileId']?['id'] ?? '',
      mediaType: json['mediaType'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'mediaType': mediaType,
      'order': order,
    };
  }
}

class LessonsResponse {
  final bool success;
  final List<Lesson> lessons;
  final PaginationInfo? pagination;

  LessonsResponse({
    required this.success,
    required this.lessons,
    this.pagination,
  });

  factory LessonsResponse.fromJson(Map<String, dynamic> json) {
    return LessonsResponse(
      success: json['success'] ?? false,
      lessons: json['lessons'] != null
          ? (json['lessons'] as List)
              .map((item) => Lesson.fromJson(item))
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

