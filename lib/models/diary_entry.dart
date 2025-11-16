/// Content block types for ordered content display
enum ContentBlockType {
  text,    // Text block (Quill delta)
  media,   // Media block (image/video/drawing)
  audio,   // Audio block
}

/// Model for a content block (text or media)
class ContentBlock {
  final ContentBlockType type;
  final int order; // Order index for display
  final Map<String, dynamic>? textDelta; // Quill delta for text blocks
  final MediaAttachment? media; // Media attachment for media/audio blocks
  final Map<String, dynamic>? textAfterMedia; // Optional text block after media (Quill delta)

  ContentBlock({
    required this.type,
    required this.order,
    this.textDelta,
    this.media,
    this.textAfterMedia,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'order': order,
      'textDelta': textDelta,
      'media': media?.toJson(),
      'textAfterMedia': textAfterMedia,
    };
  }

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: ContentBlockType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ContentBlockType.text,
      ),
      order: json['order'] as int? ?? 0,
      textDelta: json['textDelta'] as Map<String, dynamic>?,
      media: json['media'] != null
          ? MediaAttachment.fromJson(json['media'] as Map<String, dynamic>)
          : null,
      textAfterMedia: json['textAfterMedia'] as Map<String, dynamic>?,
    );
  }

  ContentBlock copyWith({
    ContentBlockType? type,
    int? order,
    Map<String, dynamic>? textDelta,
    MediaAttachment? media,
    Map<String, dynamic>? textAfterMedia,
  }) {
    return ContentBlock(
      type: type ?? this.type,
      order: order ?? this.order,
      textDelta: textDelta ?? this.textDelta,
      media: media ?? this.media,
      textAfterMedia: textAfterMedia ?? this.textAfterMedia,
    );
  }
}

/// Model for media attachment
class MediaAttachment {
  final String path;
  final bool isVideo;
  final int position; // Position in content where it should appear (legacy - kept for backward compatibility)
  final bool isDrawing; // Whether this is a drawing (can be edited)
  final String? drawingDataPath; // Path to JSON file containing drawing points data
  final bool isAudio; // Whether this is an audio file

  MediaAttachment({
    required this.path,
    this.isVideo = false,
    required this.position,
    this.isDrawing = false,
    this.drawingDataPath,
    this.isAudio = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'isVideo': isVideo,
      'position': position,
      'isDrawing': isDrawing,
      'drawingDataPath': drawingDataPath,
      'isAudio': isAudio,
    };
  }

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      path: json['path'] as String,
      isVideo: json['isVideo'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
      isDrawing: json['isDrawing'] as bool? ?? false,
      drawingDataPath: json['drawingDataPath'] as String?,
      isAudio: json['isAudio'] as bool? ?? false,
    );
  }
  
  MediaAttachment copyWith({
    String? path,
    bool? isVideo,
    int? position,
    bool? isDrawing,
    String? drawingDataPath,
    bool? isAudio,
  }) {
    return MediaAttachment(
      path: path ?? this.path,
      isVideo: isVideo ?? this.isVideo,
      position: position ?? this.position,
      isDrawing: isDrawing ?? this.isDrawing,
      drawingDataPath: drawingDataPath ?? this.drawingDataPath,
      isAudio: isAudio ?? this.isAudio,
    );
  }
}

/// Model for sticker attachment (draggable decorative element)
class StickerAttachment {
  final String emoji; // The sticker emoji
  final double x; // X position (0.0 to 1.0, relative to screen width)
  final double y; // Y position (0.0 to 1.0, relative to screen height)
  final double size; // Size multiplier (default 1.0)
  final double rotation; // Rotation in degrees (default 0.0)

  StickerAttachment({
    required this.emoji,
    required this.x,
    required this.y,
    this.size = 1.0,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'x': x,
      'y': y,
      'size': size,
      'rotation': rotation,
    };
  }

  factory StickerAttachment.fromJson(Map<String, dynamic> json) {
    return StickerAttachment(
      emoji: json['emoji'] as String,
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      size: (json['size'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
  
  StickerAttachment copyWith({
    String? emoji,
    double? x,
    double? y,
    double? size,
    double? rotation,
  }) {
    return StickerAttachment(
      emoji: emoji ?? this.emoji,
      x: x ?? this.x,
      y: y ?? this.y,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
    );
  }
}

/// Sync status for diary entries
enum SyncStatus {
  local,      // Only exists locally
  syncing,    // Currently syncing
  synced,     // Synced to cloud
  error,      // Sync error
}

/// Model for a diary entry
class DiaryEntry {
  final String id; // Local ID (used as primary key)
  final String? cloudId; // Cloud ID (Firestore document ID)
  final String? userId; // User ID who owns this entry (prevents cross-account data mixing)
  final String date;
  final String title;
  final String content; // Plain text content (for backward compatibility and search)
  final String mood;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final List<MediaAttachment> mediaAttachments; // Media files attached to entry (legacy - kept for backward compatibility)
  final List<StickerAttachment> stickerAttachments; // Draggable stickers
  final List<Map<String, dynamic>> textFormats; // Legacy text formatting data (deprecated)
  final Map<String, dynamic>? quillDelta; // Quill delta format for rich text (legacy - kept for backward compatibility)
  final List<ContentBlock> contentBlocks; // Ordered content blocks (text, media, audio) - new format

  DiaryEntry({
    required this.id,
    this.cloudId,
    this.userId,
    required this.date,
    required this.title,
    required this.content,
    required this.mood,
    required this.timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    this.mediaAttachments = const [],
    this.stickerAttachments = const [],
    this.textFormats = const [],
    this.quillDelta,
    this.contentBlocks = const [],
  })  : createdAt = createdAt ?? timestamp,
        updatedAt = updatedAt ?? timestamp,
        syncStatus = syncStatus ?? SyncStatus.local;

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cloudId': cloudId,
      'userId': userId,
      'date': date,
      'title': title,
      'content': content,
      'mood': mood,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus.name,
      'mediaAttachments': mediaAttachments.map((m) => m.toJson()).toList(),
      'stickerAttachments': stickerAttachments.map((s) => s.toJson()).toList(),
      'textFormats': textFormats, // Legacy format (deprecated)
      'quillDelta': quillDelta, // Legacy Quill format (deprecated)
      'contentBlocks': contentBlocks.map((b) => b.toJson()).toList(), // New ordered content blocks format
    };
  }

  /// Create from JSON
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.parse(json['timestamp'] as String);
    final createdAt = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : timestamp;
    final updatedAt = json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : timestamp;
    final syncStatus = json['syncStatus'] != null
        ? SyncStatus.values.firstWhere(
            (e) => e.name == json['syncStatus'],
            orElse: () => SyncStatus.local,
          )
        : SyncStatus.local;

    return DiaryEntry(
      id: json['id'] as String,
      cloudId: json['cloudId'] as String?,
      userId: json['userId'] as String?,
      date: json['date'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      mood: json['mood'] as String,
      timestamp: timestamp,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: syncStatus,
      mediaAttachments: (json['mediaAttachments'] as List<dynamic>?)
              ?.map((m) => MediaAttachment.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      stickerAttachments: (json['stickerAttachments'] as List<dynamic>?)
              ?.map((s) => StickerAttachment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      textFormats: (json['textFormats'] as List<dynamic>?)
              ?.map((f) => f as Map<String, dynamic>)
              .toList() ??
          [],
      quillDelta: json['quillDelta'] as Map<String, dynamic>?,
      contentBlocks: (json['contentBlocks'] as List<dynamic>?)
              ?.map((b) => ContentBlock.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  
  /// Copy with method for updates
  DiaryEntry copyWith({
    String? id,
    String? cloudId,
    String? userId,
    String? date,
    String? title,
    String? content,
    String? mood,
    DateTime? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    List<MediaAttachment>? mediaAttachments,
    List<StickerAttachment>? stickerAttachments,
    List<Map<String, dynamic>>? textFormats,
    Map<String, dynamic>? quillDelta,
    List<ContentBlock>? contentBlocks,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
      stickerAttachments: stickerAttachments ?? this.stickerAttachments,
      textFormats: textFormats ?? this.textFormats,
      quillDelta: quillDelta ?? this.quillDelta,
      contentBlocks: contentBlocks ?? this.contentBlocks,
    );
  }
}

