import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/diary_entries_provider.dart';

class MoodStatsWidget extends StatelessWidget {
  const MoodStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DiaryEntriesProvider>(
      builder: (context, provider, child) {
        final today = DateTime.now();
        final todayEntries = provider.entries.where((entry) {
          return entry.timestamp.year == today.year &&
                 entry.timestamp.month == today.month &&
                 entry.timestamp.day == today.day;
        }).toList();

        // Only show widget if there are entries (even if none today)
        // Don't show "No entries today" message - just hide the widget
        if (todayEntries.isEmpty) {
          return const SizedBox.shrink();
        }

        final moodCounts = <String, int>{};
        for (final entry in todayEntries) {
          if (entry.mood.isNotEmpty) {
            moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
          }
        }

        final sortedMoods = moodCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6B4C93).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF6B4C93).withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Today's Moods",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C93),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: sortedMoods.take(5).map((entry) {
                  return Chip(
                    label: Text(
                      '${entry.key} (${entry.value})',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

