import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mood selection dialog widget
class MoodSelectionDialog extends StatelessWidget {
  final List<String> moods;

  const MoodSelectionDialog({
    super.key,
    this.moods = const ['😊', '😢', '😴', '😍', '🤔', '😌', '😎', '🥰'],
  });

  static Future<String?> show(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const MoodSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final cardColor = const Color(0xFFE8D5FF).withValues(alpha: 0.95);

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
                color: isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF5E3A9E).withValues(alpha: 0.2),
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
                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

