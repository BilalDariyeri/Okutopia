// models/base_question.dart - Base Question Interface

/// Base Question Interface
/// Tüm soru tipleri bu interface'i implement etmeli
abstract class BaseQuestion {
  /// Soru ID'si
  String get id;

  /// Aktivite ID'si
  String get activityId;

  /// Soru tipi (ONLY_TEXT, AUDIO_TEXT, IMAGE_TEXT, vb.)
  String get questionType;

  /// Soru metni
  String? get questionText;

  /// Açıklama metni
  String? get instruction;

  /// Doğru cevap
  String? get correctAnswer;

  /// Soru verisini JSON'a çevirir
  Map<String, dynamic> toJson();

  /// JSON'dan soru oluşturur
  factory BaseQuestion.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('fromJson must be implemented by subclass');
  }

  /// Soru tipine göre doğru implementasyonu döndürür
  static BaseQuestion createFromJson(Map<String, dynamic> json) {
    final questionType = json['questionType'] ?? json['questionFormat'] ?? 'Text';
    
    switch (questionType) {
      case 'ONLY_TEXT':
      case 'Text':
        return OnlyTextQuestion.fromJson(json);
      case 'AUDIO_TEXT':
      case 'Audio':
        return AudioTextQuestion.fromJson(json);
      case 'IMAGE_TEXT':
      case 'Image':
        return ImageTextQuestion.fromJson(json);
      case 'AUDIO_IMAGE_TEXT':
        return AudioImageTextQuestion.fromJson(json);
      case 'DRAG_DROP':
      case 'Drawing':
        return DragDropQuestion.fromJson(json);
      default:
        return OnlyTextQuestion.fromJson(json);
    }
  }
}

/// Sadece Metin Sorusu
class OnlyTextQuestion implements BaseQuestion {
  @override
  final String id;
  @override
  final String activityId;
  @override
  final String questionType = 'ONLY_TEXT';
  @override
  final String? questionText;
  @override
  final String? instruction;
  @override
  final String? correctAnswer;

  OnlyTextQuestion({
    required this.id,
    required this.activityId,
    this.questionText,
    this.instruction,
    this.correctAnswer,
  });

  factory OnlyTextQuestion.fromJson(Map<String, dynamic> json) {
    return OnlyTextQuestion(
      id: json['_id'] ?? json['id'] ?? '',
      activityId: json['activity'] is String
          ? json['activity']
          : json['activity']?['_id'] ?? json['activity']?['id'] ?? '',
      questionText: json['data']?['questionText'],
      instruction: json['data']?['instruction'],
      correctAnswer: json['correctAnswer'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'activity': activityId,
      'questionType': questionType,
      'questionFormat': questionType,
      'correctAnswer': correctAnswer,
      'data': {
        'questionText': questionText,
        'instruction': instruction,
      },
    };
  }
}

/// Ses + Metin Sorusu
class AudioTextQuestion implements BaseQuestion {
  @override
  final String id;
  @override
  final String activityId;
  @override
  final String questionType = 'AUDIO_TEXT';
  @override
  final String? questionText;
  @override
  final String? instruction;
  @override
  final String? correctAnswer;
  final String? audioFileId;
  final String? audioUrl;

  AudioTextQuestion({
    required this.id,
    required this.activityId,
    this.questionText,
    this.instruction,
    this.correctAnswer,
    this.audioFileId,
    this.audioUrl,
  });

  factory AudioTextQuestion.fromJson(Map<String, dynamic> json) {
    return AudioTextQuestion(
      id: json['_id'] ?? json['id'] ?? '',
      activityId: json['activity'] is String
          ? json['activity']
          : json['activity']?['_id'] ?? json['activity']?['id'] ?? '',
      questionText: json['data']?['questionText'],
      instruction: json['data']?['instruction'],
      correctAnswer: json['correctAnswer'],
      audioFileId: json['mediaFileId'] ?? json['data']?['audioFileId'],
      audioUrl: json['mediaUrl'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'activity': activityId,
      'questionType': questionType,
      'questionFormat': questionType,
      'correctAnswer': correctAnswer,
      'mediaFileId': audioFileId,
      'mediaUrl': audioUrl,
      'mediaType': 'Audio',
      'mediaStorage': audioFileId != null ? 'GridFS' : 'None',
      'data': {
        'questionText': questionText,
        'instruction': instruction,
        'audioFileId': audioFileId,
      },
    };
  }
}

/// Resim + Metin Sorusu
class ImageTextQuestion implements BaseQuestion {
  @override
  final String id;
  @override
  final String activityId;
  @override
  final String questionType = 'IMAGE_TEXT';
  @override
  final String? questionText;
  @override
  final String? instruction;
  @override
  final String? correctAnswer;
  final String? imageFileId;
  final String? imageUrl;

  ImageTextQuestion({
    required this.id,
    required this.activityId,
    this.questionText,
    this.instruction,
    this.correctAnswer,
    this.imageFileId,
    this.imageUrl,
  });

  factory ImageTextQuestion.fromJson(Map<String, dynamic> json) {
    return ImageTextQuestion(
      id: json['_id'] ?? json['id'] ?? '',
      activityId: json['activity'] is String
          ? json['activity']
          : json['activity']?['_id'] ?? json['activity']?['id'] ?? '',
      questionText: json['data']?['questionText'],
      instruction: json['data']?['instruction'],
      correctAnswer: json['correctAnswer'],
      imageFileId: json['mediaFileId'] ?? json['data']?['imageFileId'],
      imageUrl: json['mediaUrl'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'activity': activityId,
      'questionType': questionType,
      'questionFormat': questionType,
      'correctAnswer': correctAnswer,
      'mediaFileId': imageFileId,
      'mediaUrl': imageUrl,
      'mediaType': 'Image',
      'mediaStorage': imageFileId != null ? 'GridFS' : 'None',
      'data': {
        'questionText': questionText,
        'instruction': instruction,
        'imageFileId': imageFileId,
      },
    };
  }
}

/// Ses + Resim + Metin Sorusu
class AudioImageTextQuestion implements BaseQuestion {
  @override
  final String id;
  @override
  final String activityId;
  @override
  final String questionType = 'AUDIO_IMAGE_TEXT';
  @override
  final String? questionText;
  @override
  final String? instruction;
  @override
  final String? correctAnswer;
  final String? audioFileId;
  final String? audioUrl;
  final String? imageFileId;
  final String? imageUrl;

  AudioImageTextQuestion({
    required this.id,
    required this.activityId,
    this.questionText,
    this.instruction,
    this.correctAnswer,
    this.audioFileId,
    this.audioUrl,
    this.imageFileId,
    this.imageUrl,
  });

  factory AudioImageTextQuestion.fromJson(Map<String, dynamic> json) {
    final mediaFiles = json['mediaFiles'] as List?;
    String? audioId, imageId;
    
    if (mediaFiles != null) {
      for (var file in mediaFiles) {
        if (file['mediaType'] == 'Audio') {
          audioId = file['fileId'];
        } else if (file['mediaType'] == 'Image') {
          imageId = file['fileId'];
        }
      }
    }

    return AudioImageTextQuestion(
      id: json['_id'] ?? json['id'] ?? '',
      activityId: json['activity'] is String
          ? json['activity']
          : json['activity']?['_id'] ?? json['activity']?['id'] ?? '',
      questionText: json['data']?['questionText'],
      instruction: json['data']?['instruction'],
      correctAnswer: json['correctAnswer'],
      audioFileId: audioId ?? json['data']?['audioFileId'],
      imageFileId: imageId ?? json['data']?['imageFileId'] ?? json['mediaFileId'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final mediaFiles = <Map<String, dynamic>>[];
    if (imageFileId != null) {
      mediaFiles.add({
        'fileId': imageFileId,
        'mediaType': 'Image',
        'order': 0,
      });
    }
    if (audioFileId != null) {
      mediaFiles.add({
        'fileId': audioFileId,
        'mediaType': 'Audio',
        'order': imageFileId != null ? 1 : 0,
      });
    }

    return {
      '_id': id,
      'activity': activityId,
      'questionType': questionType,
      'questionFormat': questionType,
      'correctAnswer': correctAnswer,
      'mediaFileId': imageFileId ?? audioFileId,
      'mediaType': 'Image',
      'mediaStorage': (imageFileId != null || audioFileId != null) ? 'GridFS' : 'None',
      'mediaFiles': mediaFiles,
      'data': {
        'questionText': questionText,
        'instruction': instruction,
        'audioFileId': audioFileId,
        'imageFileId': imageFileId,
      },
    };
  }
}

/// Sürükle-Bırak Sorusu
class DragDropQuestion implements BaseQuestion {
  @override
  final String id;
  @override
  final String activityId;
  @override
  final String questionType = 'DRAG_DROP';
  @override
  final String? questionText;
  @override
  final String? instruction;
  @override
  final String? correctAnswer;
  final Map<String, dynamic>? contentObject;

  DragDropQuestion({
    required this.id,
    required this.activityId,
    this.questionText,
    this.instruction,
    this.correctAnswer,
    this.contentObject,
  });

  factory DragDropQuestion.fromJson(Map<String, dynamic> json) {
    return DragDropQuestion(
      id: json['_id'] ?? json['id'] ?? '',
      activityId: json['activity'] is String
          ? json['activity']
          : json['activity']?['_id'] ?? json['activity']?['id'] ?? '',
      questionText: json['data']?['questionText'],
      instruction: json['data']?['instruction'],
      correctAnswer: json['correctAnswer'],
      contentObject: json['data']?['contentObject'] != null
          ? Map<String, dynamic>.from(json['data']['contentObject'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'activity': activityId,
      'questionType': questionType,
      'questionFormat': questionType,
      'correctAnswer': correctAnswer,
      'mediaType': 'None',
      'mediaStorage': 'None',
      'data': {
        'questionText': questionText,
        'instruction': instruction,
        'contentObject': contentObject,
      },
    };
  }
}

