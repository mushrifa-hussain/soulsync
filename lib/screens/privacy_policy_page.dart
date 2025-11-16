import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/theme_background_wrapper.dart';
import '../utils/theme_utils.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                        'Privacy Policy',
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
                      _buildHeaderSection(isLightTheme, isDarkTheme),
                      const SizedBox(height: 16),
                      _buildSection(
                        '1. Introduction',
                        'SoulSync ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application ("App"). Please read this policy carefully to understand our practices regarding your personal data.',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '2. Information We Collect',
                        '2.1 Personal Information\nWe collect the following personal information:\n• Email address (required for account creation and authentication)\n• User authentication credentials (securely stored and encrypted)\n\n2.2 Diary Content\n• Diary entries, journal entries, and personal reflections\n• Mood selections and emotional tracking data\n• Timestamps and dates associated with entries\n\n2.3 Media Files\n• Photos, videos, and audio recordings you attach to entries\n• Drawing files and associated metadata\n\n2.4 Device and Technical Information\n• Device type, model, and operating system version\n• App version and installation identifier\n• Usage statistics and app interaction data\n• IP address and network information (for cloud sync only)\n\n2.5 Preferences and Settings\n• Theme selections\n• Notification preferences\n• App configuration settings',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '3. How We Use Your Information',
                        'We use the collected information for the following purposes:\n\n3.1 Service Provision\n• To provide, maintain, and improve our diary application\n• To authenticate your account and ensure secure access\n• To enable data synchronization across your devices\n• To store and retrieve your diary entries and media files\n\n3.2 User Experience\n• To personalize your app experience based on preferences\n• To analyze usage patterns and improve app functionality\n• To provide customer support and respond to inquiries\n\n3.3 Communication\n• To send important updates about the app\n• To notify you about security issues or policy changes\n• To respond to your support requests\n\n3.4 Legal Compliance\n• To comply with applicable laws and regulations\n• To protect our rights and prevent fraud\n• To enforce our Terms of Service',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '4. Data Storage and Security',
                        '4.1 Local Storage\nBy default, all your diary entries and media files are stored locally on your device. This ensures your data remains private and accessible even without an internet connection.\n\n4.2 Cloud Storage (Optional)\nWhen you choose to sign in and enable cloud sync:\n• Your data is stored on Firebase (Google Cloud Platform)\n• All data transmission is encrypted using industry-standard TLS/SSL protocols\n• Data is stored in secure, access-controlled databases\n• We implement regular security audits and updates\n\n4.3 Security Measures\nWe employ multiple layers of security:\n• End-to-end encryption for data in transit\n• Secure authentication using Firebase Authentication\n• Access controls and authentication tokens\n• Regular security patches and updates\n• Secure backup and disaster recovery procedures\n\n4.4 Data Retention\n• Local data: Retained on your device until you delete it\n• Cloud data: Retained until you delete your account or request deletion\n• Deleted data: Permanently removed within 30 days of deletion request',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '5. Data Sharing and Disclosure',
                        'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:\n\n5.1 Service Providers\nWe may share data with trusted service providers who assist in operating our app:\n• Firebase (Google Cloud Platform) for authentication and cloud storage\n• These providers are contractually obligated to protect your data\n\n5.2 Legal Requirements\nWe may disclose information if required by law, court order, or government regulation.\n\n5.3 Business Transfers\nIn the event of a merger, acquisition, or sale of assets, your data may be transferred as part of the transaction.\n\n5.4 With Your Consent\nWe will share your information only with your explicit consent.',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '6. Your Rights and Choices',
                        'You have the following rights regarding your personal information:\n\n6.1 Access and Portability\n• Access all your personal data stored in the app\n• Export your diary entries in JSON format at any time\n• Request a copy of your cloud-stored data\n\n6.2 Correction and Deletion\n• Correct or update your personal information\n• Delete individual diary entries\n• Delete your account and all associated data\n\n6.3 Opt-Out Options\n• Use the app entirely offline without cloud sync\n• Disable cloud synchronization at any time\n• Opt out of non-essential communications\n\n6.4 Data Portability\n• Export your data in a machine-readable format\n• Transfer your data to another service\n\nTo exercise these rights, contact us at privacy@soulsync.app',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '7. Third-Party Services',
                        'Our app uses the following third-party services:\n\n7.1 Firebase Services (Google)\n• Firebase Authentication: For secure user authentication\n• Cloud Firestore: For cloud-based data storage\n• Firebase Storage: For media file storage\n• These services are subject to Google\'s Privacy Policy\n\n7.2 Google Fonts\n• Used for typography and text rendering\n• Subject to Google Fonts Privacy Policy\n\nWe recommend reviewing the privacy policies of these third-party services to understand their data practices.',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '8. Children\'s Privacy',
                        'SoulSync is not intended for children under the age of 13 (or the minimum age required in your jurisdiction). We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately at privacy@soulsync.app. We will promptly delete such information upon verification.',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '9. International Data Transfers',
                        'If you use our cloud sync feature, your data may be transferred to and stored on servers located outside your country of residence. These servers may be operated by Google Cloud Platform in various locations worldwide. By using cloud sync, you consent to the transfer of your data to these locations. We ensure that appropriate safeguards are in place to protect your data in accordance with this Privacy Policy.',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '10. Changes to This Privacy Policy',
                        'We may update this Privacy Policy from time to time to reflect changes in our practices or for legal, operational, or regulatory reasons. We will notify you of any material changes by:\n• Updating the "Last Updated" date at the top of this policy\n• Posting a notice in the app\n• Sending an email notification (if you have provided your email)\n\nYour continued use of the app after such changes constitutes acceptance of the updated Privacy Policy. We encourage you to review this policy periodically.',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        '11. Contact Information',
                        'If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us:\n\nEmail: privacy@soulsync.app\nSupport: support@soulsync.app\n\nWe are committed to addressing your concerns promptly and transparently. We typically respond to privacy-related inquiries within 5-7 business days.',
                        isLightTheme,
                        isDarkTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildFooterSection(isLightTheme, isDarkTheme),
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

  Widget _buildHeaderSection(bool isLightTheme, bool isDarkTheme) {
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
                  Icons.privacy_tip_rounded,
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
                      'Privacy Policy',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? const Color(0xFF5E3A9E) // Purple on white card for dark themes
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last Updated: December 2024',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: isDarkTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.7) // Purple on white card
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: isLightTheme
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            'Your privacy is important to us. This policy explains how we collect, use, and protect your personal information when you use SoulSync.',
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

  Widget _buildSection(String title, String content, bool isLightTheme, bool isDarkTheme) {
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

  Widget _buildFooterSection(bool isLightTheme, bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF5E3A9E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5E3A9E).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: const Color(0xFF5E3A9E),
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This Privacy Policy is effective as of the date listed above and applies to all users of SoulSync. By using our app, you acknowledge that you have read and understood this policy.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.5,
                color: isDarkTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on light background
                    : const Color(0xFF5E3A9E).withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
