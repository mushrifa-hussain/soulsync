import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/services/local_storage_service.dart';
import 'package:soulsync_dairyapp/services/media_storage_service.dart';

/// Service to sync diary entries with Firebase Firestore
/// Handles intelligent merging based on updatedAt timestamps
class CloudSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Get the current user's UID
  static String? get userId => _auth.currentUser?.uid;

  /// Get the Firestore collection path for user entries
  static String _getEntriesPath() {
    final uid = userId;
    if (uid == null) return '';
    return 'users/$uid/entries';
  }

  /// Upload all local entries to cloud (initial sync after login)
  static Future<void> uploadAllLocalEntries() async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [CLOUD SYNC] User not logged in, skipping upload');
      return;
    }

    try {
      final localEntries = await LocalStorageService.getAllEntries();
      debugPrint('🔥 [CLOUD SYNC] Uploading ${localEntries.length} local entries to cloud');

      final batch = _firestore.batch();
      final entriesPath = _getEntriesPath();

      for (final entry in localEntries) {
        // Use cloudId if exists, otherwise use local id
        final docId = entry.cloudId ?? entry.id;
        final docRef = _firestore.collection(entriesPath).doc(docId);
        
        // Prepare entry data for Firestore (ensure userId is included)
        final entryWithUserId = entry.copyWith(userId: userId);
        final entryData = entryWithUserId.toJson();
        entryData['serverUpdatedAt'] = FieldValue.serverTimestamp();
        entryData['serverCreatedAt'] = entryData['createdAt']; // Preserve original createdAt
        
        batch.set(docRef, entryData, SetOptions(merge: true));
        
        // Upload media files
        await _uploadEntryMedia(entry);
      }

      await batch.commit();
      
      // Update sync status for all uploaded entries (mark with userId)
      for (final entry in localEntries) {
        final docId = entry.cloudId ?? entry.id;
        await LocalStorageService.saveEntry(
          entry.copyWith(
            userId: userId,
            cloudId: docId,
            syncStatus: SyncStatus.synced,
          ),
        );
      }
      
      debugPrint('🔥 [CLOUD SYNC] Successfully uploaded ${localEntries.length} entries');
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Failed to upload entries: $e');
      rethrow;
    }
  }

  /// Download all cloud entries and merge with local (intelligent merge)
  static Future<void> downloadAndMergeCloudEntries() async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [CLOUD SYNC] User not logged in, skipping download');
      return;
    }

    try {
      final entriesPath = _getEntriesPath();
      final snapshot = await _firestore.collection(entriesPath).get();
      
      debugPrint('🔥 [CLOUD SYNC] Downloaded ${snapshot.docs.length} entries from cloud');

      final localEntries = await LocalStorageService.getAllEntries();
      
      // Create comprehensive maps for matching
      // Map by local ID
      final localEntryMap = {for (var e in localEntries) e.id: e};
      // Map by cloudId
      final localCloudIdMap = {
        for (var e in localEntries)
          if (e.cloudId != null) e.cloudId!: e
      };

      int merged = 0;
      int added = 0;
      int skipped = 0;

      // Merge cloud entries with local
      for (final doc in snapshot.docs) {
        try {
          final cloudData = doc.data();
          final cloudDocId = doc.id; // Firestore document ID
          
          // Parse cloud entry
          final cloudEntry = DiaryEntry.fromJson(cloudData);
          final cloudUpdatedAt = cloudEntry.updatedAt;
          final cloudEntryId = cloudEntry.id; // Entry's local ID from data
          final cloudEntryCloudId = cloudEntry.cloudId; // Entry's cloudId from data
          
          // Find matching local entry by multiple strategies
          DiaryEntry? localEntry;
          
          // Strategy 1: Match by cloudId in local entry matching document ID
          if (localCloudIdMap.containsKey(cloudDocId)) {
            localEntry = localCloudIdMap[cloudDocId];
            debugPrint('🔥 [CLOUD SYNC] Matched by cloudId (docId): $cloudDocId');
          }
          // Strategy 2: Match by cloudId from entry data matching document ID
          else if (cloudEntryCloudId != null && localCloudIdMap.containsKey(cloudEntryCloudId)) {
            localEntry = localCloudIdMap[cloudEntryCloudId];
            debugPrint('🔥 [CLOUD SYNC] Matched by cloudId (entry): $cloudEntryCloudId');
          }
          // Strategy 3: Match by local entry ID matching document ID
          else if (localEntryMap.containsKey(cloudDocId)) {
            localEntry = localEntryMap[cloudDocId];
            debugPrint('🔥 [CLOUD SYNC] Matched by local ID (docId): $cloudDocId');
          }
          // Strategy 4: Match by entry's local ID from cloud data
          else if (cloudEntryId.isNotEmpty && localEntryMap.containsKey(cloudEntryId)) {
            localEntry = localEntryMap[cloudEntryId];
            debugPrint('🔥 [CLOUD SYNC] Matched by entry ID: $cloudEntryId');
          }

          if (localEntry != null) {
            // Entry exists locally - compare timestamps
            final localUpdatedAt = localEntry.updatedAt;
            
            if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
              // Cloud is newer - overwrite local
              final mergedEntry = cloudEntry.copyWith(
                id: localEntry.id, // Keep local ID
                cloudId: cloudDocId, // Use document ID as cloudId
                userId: userId, // Mark with current user ID
                syncStatus: SyncStatus.synced,
              );
              await LocalStorageService.saveEntry(mergedEntry);
              await _downloadEntryMedia(mergedEntry);
              merged++;
              debugPrint('🔥 [CLOUD SYNC] Updated local entry with cloud version: $cloudDocId');
            } else if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
              // Local is newer - upload local version (but don't save again)
              await syncEntryToCloud(localEntry.copyWith(userId: userId));
              skipped++;
              debugPrint('🔥 [CLOUD SYNC] Local entry is newer, uploaded to cloud: ${localEntry.id}');
            } else {
              // Equal - already synced, but ensure userId and cloudId are set (only if changed)
              if (localEntry.cloudId != cloudDocId || localEntry.userId != userId) {
                await LocalStorageService.saveEntry(
                  localEntry.copyWith(
                    userId: userId,
                    cloudId: cloudDocId,
                    syncStatus: SyncStatus.synced,
                  ),
                );
              }
              skipped++;
            }
          } else {
            // New entry from cloud - add to local
            // Use the entry's ID if it exists and is valid, otherwise use document ID
            final newEntryId = cloudEntryId.isNotEmpty ? cloudEntryId : cloudDocId;
            
            // Double-check this ID doesn't already exist (race condition protection)
            if (!localEntryMap.containsKey(newEntryId)) {
              final newEntry = cloudEntry.copyWith(
                id: newEntryId,
                cloudId: cloudDocId,
                userId: userId, // Mark with current user ID
                syncStatus: SyncStatus.synced,
              );
              await LocalStorageService.saveEntry(newEntry);
              await _downloadEntryMedia(newEntry);
              added++;
              debugPrint('🔥 [CLOUD SYNC] Added new entry from cloud: $cloudDocId (localId: $newEntryId)');
            } else {
              // Entry already exists (race condition - was added between our load and now)
              debugPrint('🔥 [CLOUD SYNC] Skipped duplicate entry (race condition): $cloudDocId');
              skipped++;
            }
          }
        } catch (e) {
          debugPrint('🔥 [CLOUD SYNC ERROR] Failed to parse cloud entry ${doc.id}: $e');
        }
      }

      debugPrint('🔥 [CLOUD SYNC] Merge complete: $added added, $merged merged, $skipped skipped');
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Failed to download entries: $e');
      rethrow;
    }
  }

  /// Sync a single entry to cloud (with timestamp comparison)
  static Future<void> syncEntryToCloud(DiaryEntry entry) async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [CLOUD SYNC] User not logged in, skipping cloud sync');
      return;
    }

    try {
      final entriesPath = _getEntriesPath();
      final docId = entry.cloudId ?? entry.id;
      final docRef = _firestore.collection(entriesPath).doc(docId);
      
      // Check if cloud version exists and compare timestamps
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final cloudData = docSnapshot.data()!;
        final cloudEntry = DiaryEntry.fromJson(cloudData);
        
        // If cloud is newer, don't overwrite
        if (cloudEntry.updatedAt.isAfter(entry.updatedAt)) {
          debugPrint('🔥 [CLOUD SYNC] Cloud version is newer, skipping upload: ${entry.id}');
          // Download cloud version instead
          final mergedEntry = cloudEntry.copyWith(
            id: entry.id,
            cloudId: docId,
            userId: userId, // Mark with current user ID
            syncStatus: SyncStatus.synced,
          );
          await LocalStorageService.saveEntry(mergedEntry);
          await _downloadEntryMedia(mergedEntry);
          return;
        }
      }
      
      // Upload entry (ensure userId is included)
      final entryWithUserId = entry.copyWith(userId: userId);
      final entryData = entryWithUserId.toJson();
      entryData['serverUpdatedAt'] = FieldValue.serverTimestamp();
      if (!docSnapshot.exists) {
        entryData['serverCreatedAt'] = FieldValue.serverTimestamp();
      }
      
      await docRef.set(entryData, SetOptions(merge: true));
      
      // Upload media
      await _uploadEntryMedia(entry);
      
      // Update sync status (with userId)
      await LocalStorageService.saveEntry(
        entry.copyWith(
          userId: userId,
          cloudId: docId,
          syncStatus: SyncStatus.synced,
        ),
      );
      
      debugPrint('🔥 [CLOUD SYNC] Synced entry to cloud: ${entry.id}');
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Failed to sync entry to cloud: $e');
      await LocalStorageService.updateSyncStatus(entry.id, SyncStatus.error);
      // Don't throw - local save already succeeded
    }
  }

  /// Delete entry from cloud
  static Future<void> deleteEntryFromCloud(String entryId, String? cloudId) async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [CLOUD SYNC] User not logged in, skipping cloud delete');
      return;
    }

    try {
      if (cloudId == null) {
        debugPrint('🔥 [CLOUD SYNC] Entry has no cloudId, skipping delete: $entryId');
        return;
      }

      final entriesPath = _getEntriesPath();
      final docRef = _firestore.collection(entriesPath).doc(cloudId);
      
      // Delete Firestore document
      await docRef.delete();
      
      // Delete media files
      await MediaStorageService.deleteEntryMedia(entryId);
      
      debugPrint('🔥 [CLOUD SYNC] Deleted entry from cloud: $cloudId');
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Failed to delete entry from cloud: $e');
      // Don't throw - local delete already succeeded
    }
  }

  /// Clear entries that belong to a different user (prevent cross-account data mixing)
  static Future<void> clearOtherUserEntries() async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [CLOUD SYNC] User not logged in, skipping clear');
      return;
    }

    try {
      final allEntries = await LocalStorageService.getAllEntries();
      int clearedCount = 0;

      for (final entry in allEntries) {
        // If entry has a userId and it doesn't match current user, delete it
        // OR if entry is synced (has cloudId) but no userId, it's from old account - delete it
        if (entry.userId != null && entry.userId != userId) {
          await LocalStorageService.deleteEntry(entry.id);
          clearedCount++;
          debugPrint('🔥 [CLOUD SYNC] Cleared entry from different user: ${entry.id}');
        } else if (entry.syncStatus == SyncStatus.synced && entry.userId == null) {
          // Old synced entry without userId - belongs to previous account
          await LocalStorageService.deleteEntry(entry.id);
          clearedCount++;
          debugPrint('🔥 [CLOUD SYNC] Cleared old synced entry without userId: ${entry.id}');
        }
      }

      if (clearedCount > 0) {
        debugPrint('🔥 [CLOUD SYNC] Cleared $clearedCount entries from different account');
      }
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Failed to clear other user entries: $e');
      // Don't throw - continue with sync even if clear fails
    }
  }

  /// Perform full sync: upload local + download cloud + merge
  static Future<void> performFullSync() async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [CLOUD SYNC] User not logged in, skipping full sync');
      return;
    }

    try {
      debugPrint('🔥 [CLOUD SYNC] Starting full sync...');
      
      // CRITICAL: Clear entries from other accounts first
      await clearOtherUserEntries();
      
      // First, upload all unsynced local entries (mark with current userId)
      final unsyncedEntries = await LocalStorageService.getUnsyncedEntries();
      for (final entry in unsyncedEntries) {
        // Mark entry with current user ID before syncing
        if (entry.userId != userId) {
          await LocalStorageService.saveEntry(entry.copyWith(userId: userId));
        }
        await LocalStorageService.updateSyncStatus(entry.id, SyncStatus.syncing);
        await syncEntryToCloud(entry.copyWith(userId: userId));
      }
      
      // Then, download and merge cloud entries
      await downloadAndMergeCloudEntries();
      
      debugPrint('🔥 [CLOUD SYNC] Full sync completed successfully');
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Full sync failed: $e');
      rethrow;
    }
  }

  /// Restore all entries from cloud (for reinstall scenario)
  static Future<void> restoreFromCloud() async {
    if (!isLoggedIn || userId == null) {
      debugPrint('🔥 [CLOUD SYNC] User not logged in, skipping restore');
      return;
    }

    try {
      debugPrint('🔥 [CLOUD SYNC] Starting restore from cloud...');
      
      final entriesPath = _getEntriesPath();
      final snapshot = await _firestore.collection(entriesPath).get();
      
      debugPrint('🔥 [CLOUD SYNC] Restoring ${snapshot.docs.length} entries from cloud');

      for (final doc in snapshot.docs) {
        try {
          final cloudData = doc.data();
          final cloudId = doc.id;
          
          final entry = DiaryEntry.fromJson(cloudData);
          final restoredEntry = entry.copyWith(
            id: entry.id.isEmpty ? cloudId : entry.id,
            cloudId: cloudId,
            syncStatus: SyncStatus.synced,
          );
          
          await LocalStorageService.saveEntry(restoredEntry);
          await _downloadEntryMedia(restoredEntry);
        } catch (e) {
          debugPrint('🔥 [CLOUD SYNC ERROR] Failed to restore entry ${doc.id}: $e');
        }
      }

      debugPrint('🔥 [CLOUD SYNC] Restore completed successfully');
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Restore failed: $e');
      rethrow;
    }
  }

  /// Upload media files for an entry
  static Future<void> _uploadEntryMedia(DiaryEntry entry) async {
    if (!isLoggedIn) return;

    try {
      for (final media in entry.mediaAttachments) {
        final localPath = media.path;
        if (localPath.isEmpty || !localPath.startsWith('/')) {
          continue; // Skip if already a cloud URL or invalid path
        }

        final file = File(localPath);
        if (!await file.exists()) {
          continue;
        }

        final filename = path.basename(localPath);
        String? downloadUrl;

        if (media.isVideo) {
          final result = await MediaStorageService.uploadVideoWithThumbnail(
            localPath: localPath,
            entryId: entry.id,
          );
          downloadUrl = result['url'];
        } else if (media.isDrawing) {
          // Upload drawing as image
          downloadUrl = await MediaStorageService.uploadFile(
            localPath: localPath,
            entryId: entry.id,
            filename: filename,
          );
        } else {
          // Regular image
          final result = await MediaStorageService.uploadImageWithThumbnail(
            localPath: localPath,
            entryId: entry.id,
          );
          downloadUrl = result['url'];
        }

        // Update media path in entry if upload successful
        if (downloadUrl != null) {
          final updatedMedia = media.copyWith(path: downloadUrl);
          final updatedAttachments = entry.mediaAttachments.map((m) {
            return m.path == localPath ? updatedMedia : m;
          }).toList();
          
          final updatedEntry = entry.copyWith(mediaAttachments: updatedAttachments);
          await LocalStorageService.saveEntry(updatedEntry);
        }
      }
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Failed to upload entry media: $e');
    }
  }

  /// Download media files for an entry
  static Future<void> _downloadEntryMedia(DiaryEntry entry) async {
    if (!isLoggedIn) return;

    try {
      for (final media in entry.mediaAttachments) {
        final mediaPath = media.path;
        if (!mediaPath.startsWith('http')) {
          continue; // Skip if not a cloud URL
        }

        // Extract storage path from URL or use entry structure
        // For now, we'll keep cloud URLs and download on-demand
        // This can be enhanced later for offline access
      }
    } catch (e) {
      debugPrint('🔥 [CLOUD SYNC ERROR] Failed to download entry media: $e');
    }
  }
}
