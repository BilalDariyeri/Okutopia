class Group {
  final String id;
  final String name;
  final String categoryId;
  final int orderIndex;
  final String? groupType;
  final String? mediaType;
  final String? mediaStorage;
  final String? mediaFileId;
  final String? mediaUrl;
  final List<MediaFile>? mediaFiles;

  Group({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.orderIndex,
    this.groupType,
    this.mediaType,
    this.mediaStorage,
    this.mediaFileId,
    this.mediaUrl,
    this.mediaFiles,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      categoryId: json['category'] is String
          ? json['category']
          : json['category']?['_id'] ?? json['category']?['id'] ?? '',
      orderIndex: json['orderIndex'] ?? 0,
      groupType: json['groupType'],
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
      'name': name,
      'category': categoryId,
      'orderIndex': orderIndex,
      'groupType': groupType,
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

class GroupsResponse {
  final bool success;
  final List<Group> groups;
  final PaginationInfo? pagination;

  GroupsResponse({
    required this.success,
    required this.groups,
    this.pagination,
  });

  factory GroupsResponse.fromJson(Map<String, dynamic> json) {
    return GroupsResponse(
      success: json['success'] ?? false,
      groups: json['groups'] != null
          ? (json['groups'] as List)
              .map((item) => Group.fromJson(item))
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

