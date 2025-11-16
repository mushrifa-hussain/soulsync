import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/services/local_storage_service.dart';

/// Service for exporting and importing diary entries
class ExportImportService {
  /// Export all diary entries to a JSON file and share it
  static Future<void> exportEntries() async {
    try {
      debugPrint('🔥 [EXPORT] Starting export...');
      
      // Get all entries from local storage
      final entries = await LocalStorageService.getAllEntries();
      debugPrint('🔥 [EXPORT] Found ${entries.length} entries');
      
      if (entries.isEmpty) {
        throw Exception('No entries to export');
      }
      
      // Convert entries to JSON
      final entriesJson = entries.map((entry) => entry.toJson()).toList();
      final exportData = {
        'version': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'entryCount': entries.length,
        'entries': entriesJson,
      };
      
      // Convert to JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      debugPrint('🔥 [EXPORT] JSON string length: ${jsonString.length}');
      
      // Get directory for saving file
      Directory directory;
      try {
        // Try to use application documents directory first (more reliable)
        directory = await getApplicationDocumentsDirectory();
      } catch (e) {
        debugPrint('🔥 [EXPORT] Failed to get documents directory, trying temporary: $e');
        // Fallback to temporary directory
        directory = await getTemporaryDirectory();
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'soulsync_export_$timestamp.json';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      debugPrint('🔥 [EXPORT] Writing file to: $filePath');
      
      // Write to file
      await file.writeAsString(jsonString, encoding: utf8);
      debugPrint('🔥 [EXPORT] File saved successfully: ${file.path}');
      debugPrint('🔥 [EXPORT] File exists: ${await file.exists()}');
      debugPrint('🔥 [EXPORT] File size: ${await file.length()} bytes');
      
      // Share the file
      try {
        if (kIsWeb) {
          // Web: share as text
          debugPrint('🔥 [EXPORT] Sharing as text (web)');
          await Share.share(jsonString, subject: 'SoulSync Diary Export');
        } else {
          // Mobile: share as file
          debugPrint('🔥 [EXPORT] Sharing as file (mobile)');
          final xFile = XFile(file.path, mimeType: 'application/json');
          final result = await Share.shareXFiles([xFile], subject: 'SoulSync Diary Export');
          debugPrint('🔥 [EXPORT] Share result: $result');
          
          // Check if file exists and is readable
          if (!await file.exists()) {
            throw Exception('Exported file was not created properly');
          }
        }
        debugPrint('🔥 [EXPORT] Share completed successfully');
      } catch (shareError) {
        debugPrint('🔥 [EXPORT ERROR] Share failed: $shareError');
        
        // Check if it's a cancellation (user cancelled share dialog)
        final errorString = shareError.toString().toLowerCase();
        if (errorString.contains('cancel') || errorString.contains('dismiss')) {
          // User cancelled - this is not an error, just log it
          debugPrint('🔥 [EXPORT] User cancelled share dialog');
          return; // Exit successfully - user just cancelled
        }
        
        // If share fails, throw a more user-friendly error
        throw Exception('Failed to share file: ${shareError.toString()}');
      }
      
      debugPrint('🔥 [EXPORT] Export completed successfully');
    } catch (e, stackTrace) {
      debugPrint('🔥 [EXPORT ERROR] Failed to export: $e');
      debugPrint('🔥 [EXPORT ERROR] Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Import diary entries from a JSON file
  static Future<ImportResult> importEntries() async {
    try {
      debugPrint('🔥 [IMPORT] Starting import...');
      
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        throw Exception('No file selected');
      }
      
      // Read file content
      String fileContent;
      if (result.files.single.bytes != null) {
        // File content is in memory
        fileContent = utf8.decode(result.files.single.bytes!);
      } else if (result.files.single.path != null) {
        // Read from file path
        final file = File(result.files.single.path!);
        fileContent = await file.readAsString();
      } else {
        throw Exception('Could not read file content');
      }
      
      if (fileContent.isEmpty) {
        throw Exception('File is empty');
      }
      
      // Parse JSON
      final jsonData = jsonDecode(fileContent) as Map<String, dynamic>;
      
      // Validate format
      if (!jsonData.containsKey('entries')) {
        throw Exception('Invalid export file format');
      }
      
      final entriesJson = jsonData['entries'] as List<dynamic>;
      debugPrint('🔥 [IMPORT] Found ${entriesJson.length} entries in file');
      
      int imported = 0;
      int skipped = 0;
      int errors = 0;
      
      // Get current user ID (if logged in)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // Import each entry
      for (final entryJson in entriesJson) {
        try {
          final entry = DiaryEntry.fromJson(entryJson as Map<String, dynamic>);
          
          // IMPORTANT: Clear cloud-related fields for cross-account imports
          // This ensures imported entries are treated as new local entries
          // and won't conflict with cloud sync or be associated with wrong account
          final cleanedEntry = entry.copyWith(
            cloudId: null, // Clear cloud ID (from old account)
            userId: currentUserId, // Set to current user (or null if not logged in)
            syncStatus: SyncStatus.local, // Mark as local-only (will sync if user logs in later)
          );
          
          debugPrint('🔥 [IMPORT] Processing entry: ${cleanedEntry.id}');
          debugPrint('🔥 [IMPORT]   Original userId: ${entry.userId}');
          debugPrint('🔥 [IMPORT]   New userId: ${cleanedEntry.userId}');
          debugPrint('🔥 [IMPORT]   Cleared cloudId: ${entry.cloudId} -> null');
          
          // Check if entry already exists (by ID)
          final existingEntry = await LocalStorageService.getEntry(cleanedEntry.id);
          
          if (existingEntry != null) {
            // Entry exists - check if import is newer
            if (cleanedEntry.updatedAt.isAfter(existingEntry.updatedAt)) {
              // Imported entry is newer - update (with cleaned data)
              await LocalStorageService.saveEntry(cleanedEntry);
              imported++;
              debugPrint('🔥 [IMPORT] Updated entry: ${cleanedEntry.id}');
            } else {
              // Existing entry is newer or same - skip
              skipped++;
              debugPrint('🔥 [IMPORT] Skipped entry (existing is newer/same): ${cleanedEntry.id}');
            }
          } else {
            // New entry - add it (with cleaned data)
            await LocalStorageService.saveEntry(cleanedEntry);
            imported++;
            debugPrint('🔥 [IMPORT] Added new entry: ${cleanedEntry.id}');
          }
        } catch (e) {
          errors++;
          debugPrint('🔥 [IMPORT ERROR] Failed to import entry: $e');
        }
      }
      
      debugPrint('🔥 [IMPORT] Import completed. Imported: $imported, Skipped: $skipped, Errors: $errors');
      
      return ImportResult(
        imported: imported,
        skipped: skipped,
        errors: errors,
        total: entriesJson.length,
      );
    } catch (e) {
      debugPrint('🔥 [IMPORT ERROR] Failed to import: $e');
      rethrow;
    }
  }
}

/// Result of import operation
class ImportResult {
  final int imported;
  final int skipped;
  final int errors;
  final int total;
  
  ImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
    required this.total,
  });
  
  String get summary {
    if (errors > 0) {
      return 'Imported $imported, skipped $skipped, $errors errors';
    } else if (skipped > 0) {
      return 'Imported $imported new entries, skipped $skipped existing';
    } else {
      return 'Successfully imported $imported entries';
    }
  }
}

