import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';

/// Service for calling Firebase Cloud Functions
class FirebaseFunctionService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Call syncLocalToCloud function
  /// Accepts array of local entries and returns mapping { localId: cloudId }
  static Future<Map<String, String>> syncLocalToCloud(List<DiaryEntry> entries) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to sync');
    }

    try {
      debugPrint('🔥 [CLOUD FUNCTION] Calling syncLocalToCloud with ${entries.length} entries');
      
      final callable = _functions.httpsCallable('syncLocalToCloud');
      final entriesJson = entries.map((e) => e.toJson()).toList();
      
      final result = await callable.call({
        'entries': entriesJson,
      });
      
      final data = result.data as Map<String, dynamic>;
      final mapping = Map<String, String>.from(data['mapping'] as Map);
      
      debugPrint('🔥 [CLOUD FUNCTION] Sync completed: ${mapping.length} entries synced');
      return mapping;
    } catch (e) {
      debugPrint('🔥 [CLOUD FUNCTION ERROR] syncLocalToCloud failed: $e');
      rethrow;
    }
  }

  /// Call backupNow function (forces immediate sync)
  static Future<void> backupNow() async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to backup');
    }

    try {
      debugPrint('🔥 [CLOUD FUNCTION] Calling backupNow');
      
      final callable = _functions.httpsCallable('backupNow');
      await callable.call();
      
      debugPrint('🔥 [CLOUD FUNCTION] Backup completed');
    } catch (e) {
      debugPrint('🔥 [CLOUD FUNCTION ERROR] backupNow failed: $e');
      rethrow;
    }
  }

  /// Call geminiChat function for AI conversation
  /// conversationHistory: List of maps with 'role' ('user' or 'assistant') and 'text'
  static Future<String> geminiChat(List<Map<String, String>> conversationHistory) async {
    try {
      debugPrint('🔥 [CLOUD FUNCTION] Calling geminiChat with ${conversationHistory.length} messages');
      
      final callable = _functions.httpsCallable('geminiChat');
      final result = await callable.call({
        'conversationHistory': conversationHistory,
      });
      
      final data = result.data as Map<String, dynamic>;
      final response = data['response'] as String;
      
      debugPrint('🔥 [CLOUD FUNCTION] Gemini chat response received');
      return response;
    } catch (e) {
      debugPrint('🔥 [CLOUD FUNCTION ERROR] geminiChat failed: $e');
      rethrow;
    }
  }

  /// Call geminiSummarize function to create diary entry summary
  /// conversationText: Full conversation as text
  /// imagePaths: Optional list of image file paths to include in summary
  static Future<String> geminiSummarize(
    String conversationText, {
    List<String>? imagePaths,
  }) async {
    try {
      debugPrint('🔥 [CLOUD FUNCTION] Calling geminiSummarize');
      if (imagePaths != null && imagePaths.isNotEmpty) {
        debugPrint('🔥 [CLOUD FUNCTION] Including ${imagePaths.length} images in summary');
      }
      
      final callable = _functions.httpsCallable('geminiSummarize');
      final result = await callable.call({
        'conversationText': conversationText,
        'imagePaths': imagePaths,
      });
      
      final data = result.data as Map<String, dynamic>;
      final summary = data['summary'] as String;
      
      debugPrint('🔥 [CLOUD FUNCTION] Gemini summary received');
      return summary;
    } catch (e) {
      debugPrint('🔥 [CLOUD FUNCTION ERROR] geminiSummarize failed: $e');
      rethrow;
    }
  }
}

