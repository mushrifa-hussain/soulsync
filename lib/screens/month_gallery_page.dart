import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:soulsync_dairyapp/services/entry_service.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/screens/new_entry_screen.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';
import 'dart:io';

class MonthGalleryPage extends StatefulWidget {
  final DateTime month;

  const MonthGalleryPage({
    super.key,
    required this.month,
  });

  @override
  State<MonthGalleryPage> createState() => _MonthGalleryPageState();
}

class _MonthGalleryPageState extends State<MonthGalleryPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _navigateToEntry(DiaryEntry entry, MediaAttachment media) async {
    // Properly detect dark theme using ThemeUtils
    final isDarkTheme = await ThemeUtils.isDarkTheme();
    final isLightTheme = !isDarkTheme;
    
    // Navigate directly to the diary entry where that media was added
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewEntryScreen(
          isLightTheme: isLightTheme,
          existingEntry: entry,
          scrollToMedia: media, // Pass media to scroll to
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(isLightTheme),
              
              // Month Name
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  DateFormat('MMMM yyyy').format(widget.month),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                  ),
                ),
              ),
              
              // Gallery Grid - 2 columns
              Expanded(
                child: Consumer<DiaryEntriesProvider>(
                  builder: (context, provider, child) {
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF5E3A9E)));
                    }
                    
                    // Reload media when provider updates
                    final media = EntryService.getMediaForMonth(widget.month, provider);
                    
                    if (media.isEmpty) {
                      return _buildEmptyState(isLightTheme);
                    }
                    
                    return _buildGalleryGrid(isLightTheme, media);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isLightTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Gallery',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isLightTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: isLightTheme
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No photos or videos this month',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isLightTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(bool isLightTheme, List<({DiaryEntry entry, MediaAttachment media})> mediaList) {
    return GridView.builder(
      padding: const EdgeInsets.all(12), // Small spacing
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Changed from 3 to 2 columns
        crossAxisSpacing: 8, // Small spacing
        mainAxisSpacing: 8, // Small spacing
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final item = mediaList[index];
        final file = File(item.media.path);
        final exists = file.existsSync();

        // Store and use: file URL (path), entryId, timestamp
        // These are accessible via item.media.path, item.entry.id, item.entry.timestamp

        return GestureDetector(
          onTap: () => _navigateToEntry(item.entry, item.media),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: exists
                  ? (item.media.isVideo
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              file,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholder(isLightTheme, isVideo: true);
                              },
                            ),
                            // Video play icon overlay
                            Container(
                              color: Colors.black.withValues(alpha: 0.3),
                              child: const Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ],
                        )
                      : Image.file(
                          file,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder(isLightTheme);
                          },
                        ))
                  : _buildPlaceholder(isLightTheme, isVideo: item.media.isVideo),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(bool isLightTheme, {bool isVideo = false}) {
    return Container(
      color: isLightTheme
          ? Colors.grey.shade200
          : Colors.grey.shade800,
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_outlined : Icons.image_outlined,
          color: isLightTheme
              ? Colors.grey.shade400
              : Colors.grey.shade600,
          size: 32,
        ),
      ),
    );
  }
}

