import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/services/local_storage_service.dart';
import 'package:soulsync_dairyapp/services/cloud_sync_service.dart';
import 'package:soulsync_dairyapp/services/media_storage_service.dart';

/// Centralized state manager for diary entries
/// Provides 2-way synchronization between local and cloud storage
class DiaryEntriesProvider extends ChangeNotifier {
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  List<DiaryEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  /// Load all entries from storage (local first, cloud sync if logged in)
  Future<void> loadEntries() async {
    if (_isLoading) {
      debugPrint('🔥 [PROVIDER] Already loading entries, skipping...');
      return; // Prevent multiple simultaneous loads
    }

    _isLoading = true;
    // Schedule notifyListeners to run after current build cycle
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Always load from local storage first (works offline)
      _entries = await LocalStorageService.getAllEntries();
      debugPrint('🔥 [PROVIDER] Loaded ${_entries.length} entries from local storage');
      
      // If user is logged in, sync with cloud in background (non-blocking)
      if (CloudSyncService.isLoggedIn) {
        // Don't await - let it run in background
        _syncInBackground();
      }
    } catch (e) {
      debugPrint('🔥 [PROVIDER ERROR] Error loading entries: $e');
      _entries = [];
    } finally {
      _isLoading = false;
      // Schedule notifyListeners to run after current build cycle
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  bool _isSyncingInBackground = false; // Prevent concurrent syncs

  /// Sync with cloud in background (non-blocking)
  Future<void> _syncInBackground() async {
    // Prevent concurrent syncs
    if (_isSyncingInBackground) {
      debugPrint('🔥 [PROVIDER] Sync already in progress, skipping...');
      return;
    }

    try {
      _isSyncingInBackground = true;
      _isSyncing = true;
      // Schedule notifyListeners to run after current build cycle
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      
      debugPrint('🔥 [PROVIDER] Starting background cloud sync...');
      
      // Perform full sync: upload local + download cloud + merge
      await CloudSyncService.performFullSync();
      
      // Reload after sync to get merged entries
      final syncedEntries = await LocalStorageService.getAllEntries();
      _entries = syncedEntries;
      
      debugPrint('🔥 [PROVIDER] Cloud sync completed, ${syncedEntries.length} entries');
    } catch (e) {
      debugPrint('🔥 [PROVIDER ERROR] Error syncing with cloud: $e');
      // Continue with local entries even if cloud sync fails
    } finally {
      _isSyncing = false;
      _isSyncingInBackground = false;
      // Schedule notifyListeners to run after current build cycle
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Add or update an entry (saves locally first, then syncs to cloud if logged in)
  Future<void> saveEntry(DiaryEntry entry) async {
    try {
      // Update entry with current timestamp and user ID
      final now = DateTime.now();
      final currentUserId = CloudSyncService.userId;
      final updatedEntry = entry.copyWith(
        updatedAt: now,
        userId: CloudSyncService.isLoggedIn ? (entry.userId ?? currentUserId) : null,
        syncStatus: CloudSyncService.isLoggedIn 
            ? SyncStatus.syncing 
            : SyncStatus.local,
      );

      // Always save locally first (works offline)
      await LocalStorageService.saveEntry(updatedEntry);
      
      // Sync to cloud in background if logged in (non-blocking)
      if (CloudSyncService.isLoggedIn) {
        CloudSyncService.syncEntryToCloud(updatedEntry).catchError((e) {
          debugPrint('🔥 [PROVIDER ERROR] Error syncing entry to cloud: $e');
          // Update sync status to error
          LocalStorageService.updateSyncStatus(updatedEntry.id, SyncStatus.error);
        });
      }
      
      // Update local entries list without triggering full sync
      _entries = await LocalStorageService.getAllEntries();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error saving entry: $e');
      rethrow;
    }
  }

  /// Delete an entry (deletes locally first, then from cloud if logged in)
  Future<void> deleteEntry(String id) async {
    try {
      // Get entry to find cloudId and media
      final entry = await LocalStorageService.getEntry(id);
      final cloudId = entry?.cloudId;
      
      // Delete media files from storage if logged in
      if (CloudSyncService.isLoggedIn && entry != null) {
        MediaStorageService.deleteEntryMedia(id).catchError((e) {
          debugPrint('Error deleting entry media: $e');
        });
      }
      
      // Always delete locally first (works offline)
      await LocalStorageService.deleteEntry(id);
      
      // Delete from cloud in background if logged in (non-blocking)
      if (CloudSyncService.isLoggedIn) {
        CloudSyncService.deleteEntryFromCloud(id, cloudId).catchError((e) {
          debugPrint('Error deleting entry from cloud: $e');
          // Don't throw - local delete succeeded
        });
      }
      
      await loadEntries(); // Reload to get updated list
    } catch (e) {
      debugPrint('Error deleting entry: $e');
      rethrow;
    }
  }

  /// Force backup to cloud (from Settings)
  Future<void> backupNow() async {
    if (!CloudSyncService.isLoggedIn) {
      throw Exception('User must be logged in to backup');
    }

    try {
      _isSyncing = true;
      notifyListeners();

      await CloudSyncService.performFullSync();
      
      // Reload entries after sync
      _entries = await LocalStorageService.getAllEntries();
      notifyListeners();
      
      debugPrint('🔥 [PROVIDER] Backup completed successfully');
    } catch (e) {
      debugPrint('🔥 [PROVIDER ERROR] Backup failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Restore from cloud (for reinstall scenario)
  Future<void> restoreFromCloud() async {
    if (!CloudSyncService.isLoggedIn) {
      throw Exception('User must be logged in to restore');
    }

    try {
      _isLoading = true;
      _isSyncing = true;
      notifyListeners();

      await CloudSyncService.restoreFromCloud();
      
      // Reload entries after restore
      _entries = await LocalStorageService.getAllEntries();
      notifyListeners();
      
      debugPrint('🔥 [PROVIDER] Restore completed successfully');
    } catch (e) {
      debugPrint('🔥 [PROVIDER ERROR] Restore failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Get entries for a specific date
  List<DiaryEntry> getEntriesForDate(DateTime date) {
    final dateString = _formatDate(date);
    return _entries.where((entry) {
      final entryDateString = _formatDate(entry.timestamp);
      return entryDateString == dateString;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Latest first
  }

  /// Get entries for a specific month
  List<DiaryEntry> getEntriesForMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    return _entries.where((entry) {
      return entry.timestamp.isAfter(monthStart.subtract(const Duration(days: 1))) &&
             entry.timestamp.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get mood emoji for a specific date (returns latest entry's mood)
  String? getMoodForDate(DateTime date) {
    final entriesForDate = getEntriesForDate(date);
    if (entriesForDate.isEmpty) return null;
    
    // Return latest entry's mood (entries are sorted latest first)
    final mood = entriesForDate.first.mood;
    return mood.isEmpty ? null : mood;
  }

  /// Get all dates that have entries in a month
  Set<DateTime> getDatesWithEntries(DateTime month) {
    final entriesForMonth = getEntriesForMonth(month);
    final dates = <DateTime>{};
    
    for (final entry in entriesForMonth) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      dates.add(date);
    }
    
    return dates;
  }

  /// Group entries by year (for Home screen)
  Map<int, List<DiaryEntry>> groupEntriesByYear({String sortOrder = 'latest'}) {
    final Map<int, List<DiaryEntry>> grouped = {};
    
    for (final entry in _entries) {
      final year = entry.timestamp.year;
      if (!grouped.containsKey(year)) {
        grouped[year] = [];
      }
      grouped[year]!.add(entry);
    }
    
    // Sort entries within each year
    grouped.forEach((year, entries) {
      if (sortOrder == 'latest') {
        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    });
    
    return grouped;
  }

  /// Format date to YYYY-MM-DD string for comparison
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
