import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';

/// Service for local storage using Hive
/// Handles all offline diary entry operations
class LocalStorageService {
  static const String _boxName = 'diary_entries';
  static Box<Map>? _box;

  /// Recursively convert Map<dynamic, dynamic> to Map<String, dynamic>
  /// and List<dynamic> to List with proper type conversions
  static dynamic _convertToTyped(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((key, val) => MapEntry(key.toString(), _convertToTyped(val))),
      );
    } else if (value is List) {
      return value.map((item) => _convertToTyped(item)).toList();
    }
    return value;
  }

  /// Initialize Hive and open the diary entries box
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<Map>(_boxName);
      debugPrint('🔥 [LOCAL STORAGE] Hive initialized successfully');
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Get the Hive box (creates if not exists)
  static Future<Box<Map>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<Map>(_boxName);
    }
    return _box!;
  }

  /// Save a diary entry locally
  static Future<void> saveEntry(DiaryEntry entry) async {
    try {
      final box = await _getBox();
      final entryJson = entry.toJson();
      
      // Convert DateTime to ISO string for Hive storage
      entryJson['timestamp'] = entry.timestamp.toIso8601String();
      entryJson['createdAt'] = entry.createdAt.toIso8601String();
      entryJson['updatedAt'] = entry.updatedAt.toIso8601String();
      
      await box.put(entry.id, entryJson);
      debugPrint('🔥 [LOCAL STORAGE] Saved entry: ${entry.id}');
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to save entry: $e');
      rethrow;
    }
  }

  /// Get all diary entries from local storage
  static Future<List<DiaryEntry>> getAllEntries() async {
    try {
      final box = await _getBox();
      final entries = <DiaryEntry>[];

      for (final key in box.keys) {
        try {
          final entryData = box.get(key);
          if (entryData != null) {
            // Convert Hive Map<dynamic, dynamic> to Map<String, dynamic> recursively
            final json = _convertToTyped(entryData) as Map<String, dynamic>;
            final entry = DiaryEntry.fromJson(json);
            entries.add(entry);
          }
        } catch (e) {
          debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to parse entry $key: $e');
        }
      }

      // Sort by timestamp descending (newest first)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      debugPrint('🔥 [LOCAL STORAGE] Loaded ${entries.length} entries');
      return entries;
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to get entries: $e');
      return [];
    }
  }

  /// Get a single entry by ID
  static Future<DiaryEntry?> getEntry(String id) async {
    try {
      final box = await _getBox();
      final entryData = box.get(id);
      
      if (entryData != null) {
        // Convert Hive Map<dynamic, dynamic> to Map<String, dynamic> recursively
        final json = _convertToTyped(entryData) as Map<String, dynamic>;
        return DiaryEntry.fromJson(json);
      }
      return null;
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to get entry: $e');
      return null;
    }
  }

  /// Delete an entry from local storage
  static Future<void> deleteEntry(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id);
      debugPrint('🔥 [LOCAL STORAGE] Deleted entry: $id');
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to delete entry: $e');
      rethrow;
    }
  }

  /// Update sync status of an entry
  static Future<void> updateSyncStatus(String id, SyncStatus status, {String? cloudId}) async {
    try {
      final entry = await getEntry(id);
      if (entry != null) {
        final updatedEntry = entry.copyWith(
          syncStatus: status,
          cloudId: cloudId ?? entry.cloudId,
          updatedAt: DateTime.now(),
        );
        await saveEntry(updatedEntry);
        debugPrint('🔥 [LOCAL STORAGE] Updated sync status for $id: ${status.name}');
      }
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to update sync status: $e');
      rethrow;
    }
  }

  /// Get entries that need syncing (local or error status)
  static Future<List<DiaryEntry>> getUnsyncedEntries() async {
    try {
      final allEntries = await getAllEntries();
      return allEntries.where((entry) => 
        entry.syncStatus == SyncStatus.local || 
        entry.syncStatus == SyncStatus.error
      ).toList();
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to get unsynced entries: $e');
      return [];
    }
  }

  /// Clear all entries (use with caution)
  static Future<void> clearAllEntries() async {
    try {
      final box = await _getBox();
      await box.clear();
      debugPrint('🔥 [LOCAL STORAGE] Cleared all entries');
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to clear entries: $e');
      rethrow;
    }
  }

  /// Get entry count
  static Future<int> getEntryCount() async {
    try {
      final box = await _getBox();
      return box.length;
    } catch (e) {
      debugPrint('🔥 [LOCAL STORAGE ERROR] Failed to get entry count: $e');
      return 0;
    }
  }
}

