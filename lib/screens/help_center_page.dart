import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/theme_background_wrapper.dart';
import '../utils/theme_utils.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final List<FAQCategory> _categories = [
    FAQCategory(
      title: 'Getting Started',
      icon: Icons.rocket_launch_outlined,
      faqs: [
        FAQItem(
          question: 'How do I create my first diary entry?',
          answer: 'To create a new diary entry, tap the "+" button on the home screen or calendar page. You\'ll be taken to the entry editor where you can add a title, write your thoughts, select a mood, and attach photos, videos, or audio recordings. Tap "Save" when you\'re done.',
        ),
        FAQItem(
          question: 'Can I use SoulSync without creating an account?',
          answer: 'Yes! SoulSync works completely offline and does not require an account. All your entries are stored locally on your device. Creating an account is optional and only needed if you want to backup your entries to the cloud and sync across multiple devices.',
        ),
        FAQItem(
          question: 'How do I change my app theme?',
          answer: 'Navigate to Settings → Theme. You\'ll see a preview of available themes. Swipe through the options, preview how they look, and tap "Apply" when you find one you like. You can change your theme at any time.',
        ),
      ],
    ),
    FAQCategory(
      title: 'Data & Backup',
      icon: Icons.cloud_done_outlined,
      faqs: [
        FAQItem(
          question: 'How do I backup my diary entries?',
          answer: 'First, sign in to your account in Settings. Once signed in, go to Settings → Backup Now. This will upload all your local entries to the cloud. Your data will also automatically sync when you sign in on other devices.',
        ),
        FAQItem(
          question: 'How do I export my entries?',
          answer: 'Go to Settings → Export & Import → Export Entries. This creates a JSON file containing all your entries that you can save, share, or use as a backup. The export includes all entry data, timestamps, and metadata.',
        ),
        FAQItem(
          question: 'Can I import entries from another account?',
          answer: 'Yes. Export your entries from the source account, then in your new account, go to Settings → Export & Import → Import Entries. Select the exported JSON file. Imported entries will be associated with your current account and marked as local entries.',
        ),
        FAQItem(
          question: 'How do I restore entries from cloud?',
          answer: 'If you\'re signed in, go to Settings → Restore from Cloud. This downloads all your cloud-stored entries and intelligently merges them with your local entries, keeping the most recent version of each entry.',
        ),
        FAQItem(
          question: 'What happens to my data if I delete my account?',
          answer: 'Deleting your account removes all cloud-stored data permanently. Your local entries will remain on your device unless you also delete the app. We recommend exporting your entries before deleting your account if you want to keep a backup.',
        ),
      ],
    ),
    FAQCategory(
      title: 'Features & Usage',
      icon: Icons.featured_play_list_outlined,
      faqs: [
        FAQItem(
          question: 'How do I set reminders?',
          answer: 'Go to the Reminders page from the home screen, tap the "+" button, enter a reminder title, select a date and time, and ensure the reminder is enabled. You\'ll receive a notification at the scheduled time. You can toggle reminders on/off or delete them at any time.',
        ),
        FAQItem(
          question: 'How do I lock my diary with a PIN?',
          answer: 'Navigate to Settings → Diary Lock, then tap "Set PIN" or "Change PIN". Enter a 4-6 digit PIN and confirm it. Your diary will be locked when you close the app. To unlock, enter your PIN when you reopen the app.',
        ),
        FAQItem(
          question: 'Can I attach photos and videos to entries?',
          answer: 'Yes! When creating or editing an entry, use the attachment buttons to add photos, videos, audio recordings, or drawings. Media files are stored locally and optionally synced to cloud if you\'re signed in.',
        ),
        FAQItem(
          question: 'How do I edit or delete an entry?',
          answer: 'Tap on any entry from the home screen or calendar to open it. You can edit the content, title, mood, or attachments. To delete, use the delete option in the entry editor. Deleted entries are permanently removed from both local and cloud storage.',
        ),
        FAQItem(
          question: 'Can I search through my entries?',
          answer: 'Currently, you can browse entries by date on the calendar page or view all entries on the home screen. Full-text search functionality is planned for a future update.',
        ),
      ],
    ),
    FAQCategory(
      title: 'Troubleshooting',
      icon: Icons.build_outlined,
      faqs: [
        FAQItem(
          question: 'My reminders are not showing notifications',
          answer: 'Ensure notifications are enabled in your device settings and in the app (Settings → Notification). For Android, grant notification permissions when prompted. If issues persist, try creating a test reminder set for 1-2 minutes in the future to verify notifications are working.',
        ),
        FAQItem(
          question: 'Cloud sync is not working',
          answer: 'Check your internet connection and ensure you\'re signed in. Go to Settings → Backup Now to manually trigger a sync. If problems continue, try signing out and signing back in, or use Restore from Cloud to re-download your data.',
        ),
        FAQItem(
          question: 'I can\'t see my entries after signing in',
          answer: 'Your local entries remain on your device. After signing in, use Settings → Backup Now to upload local entries to cloud. If you had cloud entries, use Restore from Cloud to download them. Entries from different accounts are kept separate.',
        ),
        FAQItem(
          question: 'The app is running slowly',
          answer: 'If you have many entries with large media files, performance may be affected. Try clearing the app cache, closing other apps, or restarting your device. We\'re continuously optimizing performance in updates.',
        ),
      ],
    ),
  ];

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
                        'Help Center',
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
                      // Welcome Section
                      _buildWelcomeSection(isLightTheme, isDarkTheme),
                      const SizedBox(height: 16),
                      // Categories and FAQs
                      ..._categories.map((category) => _buildCategorySection(category, isLightTheme, isDarkTheme)),
                      const SizedBox(height: 12),
                      // Contact Section
                      _buildContactSection(isLightTheme, isDarkTheme),
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

  Widget _buildWelcomeSection(bool isLightTheme, bool isDarkTheme) {
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
                  const Color(0xFF5E3A9E).withValues(alpha: 0.15),
                  const Color(0xFF9B7EDE).withValues(alpha: 0.25),
                ],
              ),
            ),
            child: Icon(
              Icons.help_outline,
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
            'How can we help you?',
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
            'Browse our help articles organized by topic, or contact our support team for personalized assistance.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              height: 1.5,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(FAQCategory category, bool isLightTheme, bool isDarkTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                category.icon,
                size: 18,
                color: isDarkTheme
                    ? Colors.white
                    : (isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                category.title,
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
            ],
          ),
        ),
        ...category.faqs.map((faq) => _buildFAQItem(faq, isLightTheme, isDarkTheme)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildFAQItem(FAQItem faq, bool isLightTheme, bool isDarkTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            color: Colors.black.withValues(alpha: isLightTheme ? 0.03 : 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: isDarkTheme
                ? const Color(0xFF5E3A9E) // Purple on white card
                : (isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white),
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          Text(
            faq.answer,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
        iconColor: isDarkTheme
            ? const Color(0xFF5E3A9E) // Purple on white card
            : (isLightTheme
                ? const Color(0xFF5E3A9E)
                : Colors.white),
        collapsedIconColor: isDarkTheme
            ? const Color(0xFF5E3A9E).withValues(alpha: 0.7) // Purple on white card
            : (isLightTheme
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _buildContactSection(bool isLightTheme, bool isDarkTheme) {
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.email_outlined,
                  color: isDarkTheme
                      ? const Color(0xFF5E3A9E) // Purple on light background
                      : const Color(0xFF5E3A9E),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Still need help?',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme
                      ? const Color(0xFF5E3A9E) // Purple on white card
                      : (isLightTheme
                          ? const Color(0xFF5E3A9E)
                          : Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Our support team is here to assist you. Contact us for personalized help with any questions or issues.',
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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5E3A9E).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alternate_email,
                  color: const Color(0xFF5E3A9E), // Always purple on light background
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'support@soulsync.app',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5E3A9E), // Always purple on light background
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We typically respond within 24-48 hours during business days.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isLightTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

class FAQCategory {
  final String title;
  final IconData icon;
  final List<FAQItem> faqs;

  FAQCategory({
    required this.title,
    required this.icon,
    required this.faqs,
  });
}
