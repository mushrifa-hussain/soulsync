# SoulSync Backend Implementation Guide

## Overview

This document explains the complete backend architecture for the SoulSync diary app, including local storage, cloud sync, media handling, and Firebase Cloud Functions.

## Architecture

### 1. Local Storage (Offline Mode)

**Service:** `LocalStorageService` (uses Hive)

- **Location:** `lib/services/local_storage_service.dart`
- **Storage:** Hive database (fast, NoSQL local database)
- **Box Name:** `diary_entries`

**Features:**
- All diary entries stored locally using Hive
- Works completely offline
- Fast read/write operations
- Automatic persistence

**Key Methods:**
- `initialize()` - Initialize Hive and open the entries box
- `saveEntry(entry)` - Save/update an entry
- `getAllEntries()` - Get all entries (sorted by timestamp)
- `getEntry(id)` - Get a single entry by ID
- `deleteEntry(id)` - Delete an entry
- `updateSyncStatus(id, status, cloudId)` - Update sync status
- `getUnsyncedEntries()` - Get entries that need syncing

### 2. Cloud Storage & Firestore Sync

**Service:** `CloudSyncService`

- **Location:** `lib/services/cloud_sync_service.dart`
- **Firestore Path:** `users/{uid}/entries/{entryId}`

**Sync Logic:**

1. **Initial Sync (After Sign In):**
   - Upload all local entries to Firestore
   - Download all cloud entries
   - Merge intelligently based on `updatedAt` timestamps

2. **Intelligent Merging:**
   - If `local.updatedAt > cloud.updatedAt` → Upload local version
   - If `cloud.updatedAt > local.updatedAt` → Download and overwrite local
   - If `updatedAt` are equal → Skip (already synced)

3. **Real-time Sync:**
   - When entry is saved → Save locally first, then sync to cloud
   - When entry is deleted → Delete locally first, then delete from cloud
   - Media files are uploaded/downloaded automatically

**Key Methods:**
- `uploadAllLocalEntries()` - Upload all local entries to cloud
- `downloadAndMergeCloudEntries()` - Download and merge cloud entries
- `syncEntryToCloud(entry)` - Sync a single entry
- `deleteEntryFromCloud(id, cloudId)` - Delete entry from cloud
- `performFullSync()` - Full bidirectional sync
- `restoreFromCloud()` - Restore all entries from cloud (for reinstall)

### 3. Media Storage

**Service:** `MediaStorageService`

- **Location:** `lib/services/media_storage_service.dart`
- **Storage Path:** `users/{uid}/media/{entryId}/{filename}`

**Features:**
- Upload images, videos, audio, and files to Firebase Storage
- Generate thumbnails for images and videos (client-side)
- Download media files on-demand
- Delete media when entry is deleted

**Key Methods:**
- `uploadFile(localPath, entryId, filename)` - Upload any file
- `uploadImageWithThumbnail()` - Upload image + generate thumbnail
- `uploadVideoWithThumbnail()` - Upload video + generate thumbnail
- `uploadAudio()` - Upload audio file
- `deleteFile(storagePath)` - Delete a file
- `deleteEntryMedia(entryId)` - Delete all media for an entry
- `downloadFile(storagePath, localPath)` - Download file to local storage

### 4. Cloud Functions

**Location:** `functions/index.js`

**Functions:**

1. **`syncLocalToCloud`** (Callable)
   - Accepts: Array of local entries
   - Returns: Mapping `{ localId: cloudId }`
   - Upserts entries with server timestamps

2. **`onAuthCreate`** (Trigger)
   - Triggered when a new user signs up
   - Creates `users/{uid}` document in Firestore

3. **`backupNow`** (Callable)
   - Forces immediate backup operation
   - Can trigger server-side sync operations

### 5. Data Model

**DiaryEntry Model:**

```dart
class DiaryEntry {
  final String id;              // Local ID (primary key)
  final String? cloudId;        // Cloud ID (Firestore document ID)
  final String date;
  final String title;
  final String content;
  final String mood;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;  // local, syncing, synced, error
  final List<MediaAttachment> mediaAttachments;
  final List<StickerAttachment> stickerAttachments;
  final Map<String, dynamic>? quillDelta;
}
```

**SyncStatus Enum:**
- `local` - Only exists locally
- `syncing` - Currently syncing
- `synced` - Synced to cloud
- `error` - Sync error occurred

## Workflow

### Sign In Flow

1. User signs in with email/password
2. `DiaryEntriesProvider.loadEntries()` is called
3. Loads entries from local storage (instant)
4. If logged in:
   - Calls `CloudSyncService.performFullSync()`
   - Uploads all unsynced local entries
   - Downloads all cloud entries
   - Merges intelligently based on timestamps
   - Updates sync status

### Save Entry Flow

1. User creates/edits an entry
2. Entry saved to local storage immediately (works offline)
3. If logged in:
   - Entry marked as `syncing`
   - Uploaded to Firestore in background
   - Media files uploaded to Storage
   - Entry marked as `synced` on success
   - Entry marked as `error` on failure

### Delete Entry Flow

1. User deletes an entry
2. Entry deleted from local storage immediately
3. If logged in:
   - Media files deleted from Storage
   - Entry deleted from Firestore
   - All operations non-blocking

### Sign Out Flow

1. User signs out
2. Local entries remain intact
3. Cloud sync stops
4. App continues working offline

### Reinstall + Sign In Flow

1. User reinstalls app and signs in
2. `CloudSyncService.restoreFromCloud()` is called
3. Downloads all entries from Firestore
4. Saves to local storage
5. Downloads media files
6. All entries marked as `synced`

## Settings Page Functions

### Backup Now

- **Method:** `DiaryEntriesProvider.backupNow()`
- **Action:** Forces immediate full sync to cloud
- **UI:** Shows loading dialog, then success/error message

### Restore from Cloud

- **Method:** `DiaryEntriesProvider.restoreFromCloud()`
- **Action:** Downloads all entries from cloud and merges with local
- **UI:** Shows confirmation dialog, then loading, then success/error

## File Structure

```
lib/
├── models/
│   └── diary_entry.dart          # Entry model with sync fields
├── services/
│   ├── local_storage_service.dart # Hive local storage
│   ├── cloud_sync_service.dart    # Firestore sync logic
│   ├── media_storage_service.dart # Firebase Storage for media
│   └── firebase_function_service.dart # Cloud Functions client
├── providers/
│   └── diary_entries_provider.dart # State management with sync
└── screens/
    └── settings_page.dart         # Backup/Restore UI

functions/
├── index.js                       # Cloud Functions code
└── package.json                   # Functions dependencies
```

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### 3. Initialize Hive

Hive is automatically initialized in `main.dart`:
```dart
await LocalStorageService.initialize();
```

## Testing Checklist

- [ ] App works offline (no login required)
- [ ] Creating entries works offline
- [ ] Signing in syncs local entries to cloud
- [ ] Signing in downloads cloud entries
- [ ] Merging works correctly (newest wins)
- [ ] Media uploads work
- [ ] Media downloads work
- [ ] Signing out preserves local data
- [ ] After reinstall + sign in → entries restore
- [ ] Backup Now works
- [ ] Restore from Cloud works
- [ ] Deleting entry removes from both local and cloud
- [ ] No duplicate entries after sync

## Error Handling

- All cloud operations are non-blocking
- Local operations always succeed first
- Cloud failures don't break the app
- Sync errors are logged but don't crash
- Users can continue using app offline

## Performance

- Local storage is instant (Hive)
- Cloud sync happens in background
- Media uploads are non-blocking
- UI remains responsive during sync
- Batch operations for efficiency

## Security

- All Firestore operations require authentication
- Storage paths are user-specific: `users/{uid}/...`
- Cloud Functions verify authentication
- No data leakage between users

## Future Enhancements

- Real-time sync using Firestore listeners
- Conflict resolution UI
- Sync progress indicator
- Selective sync (sync specific entries)
- Offline queue for failed syncs

