import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mood selection dialog widget
class MoodSelectionDialog extends StatelessWidget {
  final List<String> moods;
  final Color? backgroundColor;

  const MoodSelectionDialog({
    super.key,
    this.moods = const ['😊', '😢', '😴', '😍', '🤔', '😌', '😎', '🥰'],
    this.backgroundColor,
  });

  static Future<String?> show(BuildContext context, {Color? backgroundColor}) async {
    return await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => MoodSelectionDialog(backgroundColor: backgroundColor),
    );
  }

  /// Check if a color is dark (for text color selection)
  bool _isDarkColor(Color color) {
    // Calculate relative luminance
    final luminance = (0.299 * (color.r * 255.0) + 
                      0.587 * (color.g * 255.0) + 
                      0.114 * (color.b * 255.0)) / 255.0;
    return luminance < 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    // Use provided background color or fallback to theme-based colors
    final cardColor = backgroundColor?.withValues(alpha: 0.95) ??
        (isLightTheme
            ? const Color(0xFFE8D5FF).withValues(alpha: 0.95)
            : const Color(0xFF4A2C7A).withValues(alpha: 0.95));
    
    // Check if the background color is dark (for the 2 dark themes)
    final isDarkBackground = backgroundColor != null ? _isDarkColor(backgroundColor!) : !isLightTheme;
    // Use white text for dark backgrounds, otherwise use theme-based colors
    final textColor = isDarkBackground 
        ? Colors.white 
        : (isLightTheme ? const Color(0xFF5E3A9E) : Colors.white);
    final cancelTextColor = isDarkBackground 
        ? Colors.white 
        : (isLightTheme ? const Color(0xFF5E3A9E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLightTheme
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLightTheme ? 0.1 : 0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Your Mood',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: moods.map((mood) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(mood);
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLightTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        mood,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: cancelTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

