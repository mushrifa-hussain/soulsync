import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:soulsync_dairyapp/models/diary_entry.dart';

/// Service to migrate old textFormats to Quill delta format
class QuillMigrationService {
  /// Convert old textFormats to Quill delta
  static Map<String, dynamic>? convertTextFormatsToQuill(
    String content,
    List<Map<String, dynamic>> textFormats,
  ) {
    if (textFormats.isEmpty) {
      // No formatting - return simple delta with plain text
      if (content.isEmpty) {
        final doc = quill.Document();
        return {'ops': doc.toDelta().toJson()};
      }
      final doc = quill.Document()..insert(0, content);
      return {'ops': doc.toDelta().toJson()};
    }

    try {
      // Build document by inserting text with formatting
      final doc = quill.Document();
      int currentPos = 0;

      // Sort formats by start position
      final sortedFormats = List<Map<String, dynamic>>.from(textFormats)
        ..sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

      for (final format in sortedFormats) {
        final start = format['start'] as int;
        final end = format['end'] as int;

        // Add unformatted text before this format
        if (start > currentPos) {
          final plainText = content.substring(
            currentPos,
            start.clamp(0, content.length),
          );
          if (plainText.isNotEmpty) {
            doc.insert(doc.length, plainText);
          }
        }

        // Add formatted text (for now, insert as plain text)
        // TODO: Apply formatting attributes when Document API is clarified
        if (end > start && start < content.length) {
          final formatStart = start.clamp(0, content.length);
          final formatEnd = end.clamp(0, content.length);
          if (formatEnd > formatStart) {
            final formattedText = content.substring(formatStart, formatEnd);
            doc.insert(doc.length, formattedText);
            // Note: Formatting attributes will be applied in a future update
            // when the correct Document API is determined
          }
        }

        currentPos = end;
      }

      // Add remaining unformatted text
      if (currentPos < content.length) {
        final remainingText = content.substring(currentPos);
        if (remainingText.isNotEmpty) {
          doc.insert(doc.length, remainingText);
        }
      }

      return {'ops': doc.toDelta().toJson()};
    } catch (e) {
      // If conversion fails, return simple delta with plain text
      final doc = quill.Document()..insert(0, content);
      return {'ops': doc.toDelta().toJson()};
    }
  }

  /// Migrate an entry from old format to Quill format
  static DiaryEntry migrateEntry(DiaryEntry entry) {
    // If already has quillDelta, no migration needed
    if (entry.quillDelta != null) {
      return entry;
    }

    // If has old textFormats, convert them
    if (entry.textFormats.isNotEmpty) {
      final quillDelta = convertTextFormatsToQuill(
        entry.content,
        entry.textFormats,
      );
      return entry.copyWith(quillDelta: quillDelta);
    }

    // No formatting - create simple delta
    final doc = quill.Document()..insert(0, entry.content);
    return entry.copyWith(quillDelta: {'ops': doc.toDelta().toJson()});
  }
}
