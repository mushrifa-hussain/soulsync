import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Service for handling media uploads to Firebase Storage
class MediaStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Get the current user's UID
  static String? get userId => _auth.currentUser?.uid;

  /// Get storage path for media
  static String _getMediaPath(String entryId, String filename) {
    final uid = userId;
    if (uid == null) return '';
    return 'users/$uid/media/$entryId/$filename';
  }

  /// Upload a file to Firebase Storage
  static Future<String?> uploadFile({
    required String localPath,
    required String entryId,
    required String filename,
  }) async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [MEDIA STORAGE] User not logged in, skipping upload');
      return null;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('🔥 [MEDIA STORAGE ERROR] File does not exist: $localPath');
        return null;
      }

      final storagePath = _getMediaPath(entryId, filename);
      final ref = _storage.ref().child(storagePath);
      
      debugPrint('🔥 [MEDIA STORAGE] Uploading file: $filename to $storagePath');
      
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      
      debugPrint('🔥 [MEDIA STORAGE] Upload successful: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to upload file: $e');
      return null;
    }
  }

  /// Upload image and generate thumbnail
  static Future<Map<String, String?>> uploadImageWithThumbnail({
    required String localPath,
    required String entryId,
  }) async {
    if (!isLoggedIn || userId == null) {
      return {'url': null, 'thumbnailUrl': null};
    }

    try {
      final filename = path.basename(localPath);
      final thumbnailPath = 'thumb_$filename';
      
      // Upload original image
      final imageUrl = await uploadFile(
        localPath: localPath,
        entryId: entryId,
        filename: filename,
      );

      // Generate and upload thumbnail
      String? thumbnailUrl;
      try {
        final thumbnail = await _generateImageThumbnail(localPath);
        if (thumbnail != null) {
          final tempDir = await getTemporaryDirectory();
          final thumbnailFile = File('${tempDir.path}/$thumbnailPath');
          await thumbnailFile.writeAsBytes(thumbnail);
          
          thumbnailUrl = await uploadFile(
            localPath: thumbnailFile.path,
            entryId: entryId,
            filename: thumbnailPath,
          );
          
          // Clean up temp file
          await thumbnailFile.delete();
        }
      } catch (e) {
        debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to generate thumbnail: $e');
      }

      return {
        'url': imageUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to upload image: $e');
      return {'url': null, 'thumbnailUrl': null};
    }
  }

  /// Upload video and generate thumbnail
  static Future<Map<String, String?>> uploadVideoWithThumbnail({
    required String localPath,
    required String entryId,
  }) async {
    if (!isLoggedIn || userId == null) {
      return {'url': null, 'thumbnailUrl': null};
    }

    try {
      final filename = path.basename(localPath);
      final thumbnailPath = 'thumb_${path.basenameWithoutExtension(filename)}.jpg';
      
      // Upload video
      final videoUrl = await uploadFile(
        localPath: localPath,
        entryId: entryId,
        filename: filename,
      );

      // Generate and upload thumbnail
      String? thumbnailUrl;
      try {
        final thumbnail = await VideoThumbnail.thumbnailFile(
          video: localPath,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 300,
          quality: 75,
        );

        if (thumbnail != null) {
          thumbnailUrl = await uploadFile(
            localPath: thumbnail,
            entryId: entryId,
            filename: thumbnailPath,
          );
          
          // Clean up temp file
          await File(thumbnail).delete();
        }
      } catch (e) {
        debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to generate video thumbnail: $e');
      }

      return {
        'url': videoUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to upload video: $e');
      return {'url': null, 'thumbnailUrl': null};
    }
  }

  /// Upload audio file
  static Future<String?> uploadAudio({
    required String localPath,
    required String entryId,
  }) async {
    final filename = path.basename(localPath);
    return await uploadFile(
      localPath: localPath,
      entryId: entryId,
      filename: filename,
    );
  }

  /// Upload any file (generic)
  static Future<String?> uploadGenericFile({
    required String localPath,
    required String entryId,
  }) async {
    final filename = path.basename(localPath);
    return await uploadFile(
      localPath: localPath,
      entryId: entryId,
      filename: filename,
    );
  }

  /// Delete a file from Firebase Storage
  static Future<void> deleteFile(String storagePath) async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [MEDIA STORAGE] User not logged in, skipping delete');
      return;
    }

    try {
      final ref = _storage.ref().child(storagePath);
      await ref.delete();
      debugPrint('🔥 [MEDIA STORAGE] Deleted file: $storagePath');
    } catch (e) {
      debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to delete file: $e');
      // Don't throw - file might not exist
    }
  }

  /// Delete all media for an entry
  static Future<void> deleteEntryMedia(String entryId) async {
    if (!isLoggedIn || userId == null) {
      return;
    }

    try {
      final uid = userId!;
      final mediaPath = 'users/$uid/media/$entryId';
      final ref = _storage.ref().child(mediaPath);
      
      final listResult = await ref.listAll();
      
      // Delete all files
      for (final item in listResult.items) {
        await item.delete();
      }
      
      // Delete all subdirectories (thumbnails, etc.)
      for (final prefix in listResult.prefixes) {
        final subList = await prefix.listAll();
        for (final item in subList.items) {
          await item.delete();
        }
      }
      
      debugPrint('🔥 [MEDIA STORAGE] Deleted all media for entry: $entryId');
    } catch (e) {
      debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to delete entry media: $e');
    }
  }

  /// Generate thumbnail for image (client-side)
  static Future<Uint8List?> _generateImageThumbnail(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 300,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to generate image thumbnail: $e');
      return null;
    }
  }

  /// Download file from Firebase Storage to local path
  static Future<String?> downloadFile({
    required String storagePath,
    required String localPath,
  }) async {
    if (!isLoggedIn || userId == null) {
      return null;
    }

    try {
      final ref = _storage.ref().child(storagePath);
      final file = File(localPath);
      
      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);
      
      await ref.writeToFile(file);
      debugPrint('🔥 [MEDIA STORAGE] Downloaded file to: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('🔥 [MEDIA STORAGE ERROR] Failed to download file: $e');
      return null;
    }
  }
}

