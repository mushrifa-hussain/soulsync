import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';

/// Service for calendar-related entry queries
/// Now uses DiaryEntriesProvider for synchronized data access
class EntryService {
  /// Get all entries for a specific date (via provider)
  static List<DiaryEntry> getEntriesForDate(DateTime date, DiaryEntriesProvider provider) {
    return provider.getEntriesForDate(date);
  }

  /// Get all entries for a specific month (via provider)
  static List<DiaryEntry> getEntriesForMonth(DateTime month, DiaryEntriesProvider provider) {
    return provider.getEntriesForMonth(month);
  }

  /// Get mood emoji for a specific date (via provider)
  static String? getMoodForDate(DateTime date, DiaryEntriesProvider provider) {
    return provider.getMoodForDate(date);
  }

  /// Get all dates that have entries in a month (via provider)
  static Set<DateTime> getDatesWithEntries(DateTime month, DiaryEntriesProvider provider) {
    return provider.getDatesWithEntries(month);
  }

  /// Get all media (photos/videos) for a specific month (via provider)
  static List<({DiaryEntry entry, MediaAttachment media})> getMediaForMonth(DateTime month, DiaryEntriesProvider provider) {
    final entries = provider.getEntriesForMonth(month);
    final mediaList = <({DiaryEntry entry, MediaAttachment media})>[];

    for (final entry in entries) {
      for (final media in entry.mediaAttachments) {
        // Only include photos and videos (not drawings or audio)
        if (!media.isDrawing) {
          mediaList.add((entry: entry, media: media));
        }
      }
    }

    // Sort by timestamp (most recent first)
    mediaList.sort((a, b) => b.entry.timestamp.compareTo(a.entry.timestamp));

    return mediaList;
  }
}
