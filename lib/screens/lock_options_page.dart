import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pin_change_page.dart';
import 'pin_remove_page.dart';
import '../widgets/theme_background_wrapper.dart';
import '../utils/theme_utils.dart';

class LockOptionsPage extends StatelessWidget {
  const LockOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildContent(context, isLightTheme, isDarkTheme);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isLightTheme, bool isDarkTheme) {
    return Scaffold(
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDarkTheme
                            ? Colors.white
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lock Options',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.white
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Lock icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 38,
                    color: isDarkTheme
                        ? Colors.white
                        : (isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                // Options
                Expanded(
                  child: Column(
                    children: [
                      // Change PIN option
                      _buildOptionCard(
                        context: context,
                        icon: Icons.lock_reset_outlined,
                        title: 'Change PIN',
                        subtitle: 'Update your current PIN',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PinChangePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      // Remove PIN option
                      _buildOptionCard(
                        context: context,
                        icon: Icons.lock_open_outlined,
                        title: 'Remove PIN',
                        subtitle: 'Disable app lock',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PinRemovePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLightTheme,
    required bool isDarkTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isLightTheme
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLightTheme
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLightTheme ? 0.04 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8D5FF).withValues(alpha: 0.2),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDarkTheme
                    ? const Color(0xFF5E3A9E) // Purple on white card
                    : (isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDarkTheme
                          ? const Color(0xFF5E3A9E) // Purple on white card
                          : (isLightTheme
                              ? const Color(0xFF5E3A9E)
                              : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDarkTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on white card
                          : (isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.6) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.6)),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
