import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/theme_background_wrapper.dart';
import '../utils/theme_utils.dart';

class DonatePage extends StatelessWidget {
  const DonatePage({super.key});

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

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
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDarkTheme
                            ? Colors.white
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Support SoulSync',
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
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Section
                      _buildHeroSection(isLightTheme, isDarkTheme),
                      const SizedBox(height: 16),
                      // Why Support Section
                      _buildSection(
                        'Why Support SoulSync?',
                        'SoulSync is committed to providing a free, privacy-focused diary application. Your support enables us to:\n\n• Continue developing new features and improvements\n• Maintain secure cloud infrastructure for data sync\n• Provide responsive customer support\n• Keep the app free and accessible to everyone\n• Invest in security and privacy enhancements\n• Build a sustainable future for the app',
                        Icons.volunteer_activism_outlined,
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      // Donation Options
                      Text(
                        'Ways to Support',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkTheme
                              ? Colors.white
                              : (isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDonationOption(
                        'One-Time Donation',
                        'Make a single contribution to support SoulSync development',
                        'PayPal',
                        Icons.payment,
                        () => _openUrl('https://paypal.me/soulsync'),
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 8),
                      _buildDonationOption(
                        'Monthly Support',
                        'Become a recurring supporter with monthly contributions',
                        'Patreon',
                        Icons.repeat,
                        () => _openUrl('https://patreon.com/soulsync'),
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 8),
                      _buildDonationOption(
                        'Buy Us a Coffee',
                        'Show your appreciation with a small contribution',
                        'Buy Me a Coffee',
                        Icons.local_cafe,
                        () => _openUrl('https://buymeacoffee.com/soulsync'),
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      // Alternative Support
                      _buildSection(
                        'Other Ways to Help',
                        'Not ready to donate? Here are other meaningful ways to support SoulSync:\n\n• Share SoulSync with friends and family who might benefit\n• Leave a positive review and rating on the app store\n• Report bugs and suggest new features\n• Follow us on social media and spread the word\n• Provide feedback to help us improve\n• Recommend SoulSync to mental health communities',
                        Icons.favorite_border,
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      // Thank You Message
                      _buildThankYouSection(isLightTheme, isDarkTheme),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isLightTheme, bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF5E3A9E).withValues(alpha: 0.2),
                  const Color(0xFF9B7EDE).withValues(alpha: 0.3),
                ],
              ),
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: 28,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thank You for Considering a Donation',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your support helps us continue developing and improving SoulSync, ensuring it remains a safe, private, and beautiful space for your thoughts and reflections.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              height: 1.5,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    String content,
    IconData icon,
    bool isLightTheme,
    bool isDarkTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isDarkTheme
                    ? const Color(0xFF5E3A9E) // Purple on white card
                    : (isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationOption(
    String title,
    String subtitle,
    String platform,
    IconData icon,
    VoidCallback onTap,
    bool isLightTheme,
    bool isDarkTheme,
  ) {
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF5E3A9E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF5E3A9E),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
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
                      fontSize: 11.5,
                      color: isDarkTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on white card
                          : (isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      platform,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5E3A9E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.7) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThankYouSection(bool isLightTheme, bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5E3A9E).withValues(alpha: 0.12),
            const Color(0xFF9B7EDE).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5E3A9E).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: const Color(0xFF5E3A9E),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Support Makes a Difference',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5E3A9E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every contribution, no matter the size, helps us continue building and improving SoulSync. Thank you for being part of our community and for supporting privacy-focused, user-centric software.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.6,
                    color: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
