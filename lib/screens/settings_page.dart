import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:soulsync_dairyapp/services/settings_service.dart';
import 'package:soulsync_dairyapp/screens/lock_options_page.dart';
import 'package:soulsync_dairyapp/screens/theme_selection_page.dart';
import 'package:soulsync_dairyapp/screens/auth/auth_screen.dart';
import 'package:soulsync_dairyapp/screens/privacy_policy_page.dart';
import 'package:soulsync_dairyapp/screens/help_center_page.dart';
import 'package:soulsync_dairyapp/screens/donate_page.dart';
import 'package:soulsync_dairyapp/utils/auth_helper.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/services/export_import_service.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _soundEnabled = true;
  bool _skipMoodSelection = false;
  bool _displayMoodOnCalendar = true;
  bool _notificationsEnabled = true;
  String _appVersion = '1.0.0';
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _loadAuthStatus();
    // Listen to auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _userEmail = user?.email;
        });
      }
    });
  }

  void _loadAuthStatus() {
    setState(() {
      _userEmail = AuthHelper.getCurrentUserEmail();
    });
  }

  Future<void> _loadSettings() async {
    final soundEnabled = await SettingsService.getSoundEnabled();
    final skipMoodSelection = await SettingsService.getSkipMoodSelection();
    final displayMoodOnCalendar = await SettingsService.getDisplayMoodOnCalendar();
    final notificationsEnabled = await SettingsService.getNotificationsEnabled();

    if (mounted) {
      setState(() {
        _soundEnabled = soundEnabled;
        _skipMoodSelection = skipMoodSelection;
        _displayMoodOnCalendar = displayMoodOnCalendar;
        _notificationsEnabled = notificationsEnabled;
      });
    }
  }

  Future<void> _loadAppVersion() async {
    // Version from pubspec.yaml (1.0.0+1)
    if (mounted) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _handleSignIn() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
    );
    if (result == true && mounted) {
      _loadAuthStatus();
      // Trigger sync after sign in
      final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
      provider.loadEntries();
    }
  }

  Future<void> _handleBackupNow(BuildContext context) async {
    if (_userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please sign in to backup',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    try {
      final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Backing up to cloud...',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
      );

      await provider.backupNow();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup completed successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup failed: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreFromCloud(BuildContext context) async {
    if (_userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please sign in to restore',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Restore from Cloud',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will download all entries from cloud and merge with local entries. Continue?',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Restore',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B4C93),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldRestore != true) return;

    try {
      final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Restoring from cloud...',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
      );

      await provider.restoreFromCloud();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restore completed successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restore failed: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showExportImportDialog(BuildContext context, bool isLightTheme, bool isDarkTheme) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Export & Import',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5E3A9E),
          ),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE8D5FF).withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          Icons.upload_outlined,
                          size: 16,
                          color: const Color(0xFF5E3A9E),
                        ),
                      ),
                      title: Text(
                        'Export Entries',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5E3A9E),
                        ),
                      ),
                      subtitle: Text(
                        'Save all entries to a JSON file',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, 'export'),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE8D5FF).withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          Icons.download_outlined,
                          size: 16,
                          color: const Color(0xFF5E3A9E),
                        ),
                      ),
                      title: Text(
                        'Import Entries',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5E3A9E),
                        ),
                      ),
                      subtitle: Text(
                        'Import entries from a JSON file',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, 'import'),
                    ),
                  ],
                ),
              ),
              // Scroll indicator at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
          gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
            colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.8),
            ],
          ),
        ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (result == 'export') {
      await _handleExport(context);
    } else if (result == 'import') {
      await _handleImport(context);
    }
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Exporting entries...',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
      );

      await ExportImportService.exportEntries();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export completed successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show more detailed error message
        String errorMessage = 'Export failed';
        if (e.toString().contains('No entries')) {
          errorMessage = 'No entries to export';
        } else if (e.toString().contains('share')) {
          errorMessage = 'Failed to share file. Please try again.';
        } else if (e.toString().contains('permission') || e.toString().contains('Permission')) {
          errorMessage = 'Permission denied. Please grant storage permission.';
        } else {
          errorMessage = 'Export failed: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleImport(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Importing entries...',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
      );

      final result = await ExportImportService.importEntries();
      
      // Reload entries in provider
      final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
      await provider.loadEntries();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show result dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Import Complete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              result.summary,
              style: GoogleFonts.poppins(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5E3A9E),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import failed: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      // Update UI silently
      setState(() {
        _userEmail = null;
      });

      // Show toast message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signed out',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred while signing out. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildContent(context, isLightTheme, isDarkTheme, colorScheme);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isLightTheme, bool isDarkTheme, ColorScheme colorScheme) {
    return Scaffold(
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(isLightTheme, isDarkTheme),
              // Settings Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GENERAL Section
                      _buildSectionHeader('GENERAL', isLightTheme, isDarkTheme),
                      const SizedBox(height: 10),
                      _buildSettingTile(
                        context: context,
                        icon: Icons.lock_outline,
                        title: 'Diary Lock',
                        subtitle: 'Change PIN / Remove PIN',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LockOptionsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_userEmail != null) ...[
                        // Backup Now button (only when logged in)
                      _buildSettingTile(
                        context: context,
                        icon: Icons.cloud_upload_outlined,
                          title: 'Backup Now',
                          subtitle: 'Force sync to cloud',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                          onTap: () => _handleBackupNow(context),
                        ),
                        const SizedBox(height: 8),
                        // Restore from Cloud button (only when logged in)
                        _buildSettingTile(
                          context: context,
                          icon: Icons.cloud_download_outlined,
                          title: 'Restore from Cloud',
                          subtitle: 'Download all entries from cloud',
                          isLightTheme: isLightTheme,
                          isDarkTheme: isDarkTheme,
                          onTap: () => _handleRestoreFromCloud(context),
                              ),
                      ] else ...[
                        // Show message when not logged in
                      _buildSettingTile(
                        context: context,
                        icon: Icons.cloud_upload_outlined,
                        title: 'Backup & Restore',
                          subtitle: 'Sign in to sync your diary',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                          onTap: _handleSignIn,
                            ),
                      ],
                      const SizedBox(height: 8),
                      _buildSettingTile(
                        context: context,
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        subtitle: 'Choose your app theme',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ThemeSelectionPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildSettingTile(
                        context: context,
                        icon: Icons.import_export_outlined,
                        title: 'Export & Import',
                        subtitle: 'Export or import your entries',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () => _showExportImportDialog(context, isLightTheme, isDarkTheme),
                      ),
                      const SizedBox(height: 8),
                      _buildSettingTileWithToggle(
                        context: context,
                        icon: Icons.volume_up_outlined,
                        title: 'Sound',
                        subtitle: 'Theme ambience audio',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        value: _soundEnabled,
                        onChanged: (value) async {
                          await SettingsService.setSoundEnabled(value);
                          setState(() {
                            _soundEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      // DIARY PREFERENCES Section
                      _buildSectionHeader('DIARY PREFERENCES', isLightTheme, isDarkTheme),
                      const SizedBox(height: 10),
                      _buildSettingTileWithToggle(
                        context: context,
                        icon: Icons.skip_next_outlined,
                        title: 'Skip Mood Selection Page',
                        subtitle: 'Go directly to entry editor',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        value: _skipMoodSelection,
                        onChanged: (value) async {
                          await SettingsService.setSkipMoodSelection(value);
                          setState(() {
                            _skipMoodSelection = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildSettingTileWithToggle(
                        context: context,
                        icon: Icons.calendar_today_outlined,
                        title: 'Display Mood on Calendar',
                        subtitle: 'Show mood emojis on calendar dates',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        value: _displayMoodOnCalendar,
                        onChanged: (value) async {
                          await SettingsService.setDisplayMoodOnCalendar(value);
                          setState(() {
                            _displayMoodOnCalendar = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildSettingTileWithToggle(
                        context: context,
                        icon: Icons.notifications_outlined,
                        title: 'Notification',
                        subtitle: 'Enable or disable notifications',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        value: _notificationsEnabled,
                        onChanged: (value) async {
                          await SettingsService.setNotificationsEnabled(value);
                          setState(() {
                            _notificationsEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      // ABOUT Section
                      _buildSectionHeader('ABOUT', isLightTheme, isDarkTheme),
                      const SizedBox(height: 10),
                      _buildAboutSettingTile(
                        context: context,
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'View our privacy policy',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildAboutSettingTile(
                        context: context,
                        icon: Icons.star_outline,
                        title: 'Rate Us',
                        subtitle: 'Rate SoulSync on the app store',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Rate Us coming soon!',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildAboutSettingTile(
                        context: context,
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        subtitle: 'Get help and support',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpCenterPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildAboutSettingTile(
                        context: context,
                        icon: Icons.favorite_outline,
                        title: 'Donate',
                        subtitle: 'Support SoulSync development',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DonatePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // ACCOUNT Section
                      _buildSectionHeader('ACCOUNT', isLightTheme, isDarkTheme),
                      const SizedBox(height: 10),
                      if (_userEmail != null) ...[
                        // Show signed in status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isLightTheme
                                ? Colors.white.withValues(alpha: 0.95)
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLightTheme
                                  ? Colors.black.withValues(alpha: 0.12)
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
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Signed in as',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isDarkTheme
                                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on light card
                                            : (isLightTheme
                                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                                                : Colors.white.withValues(alpha: 0.7)),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _userEmail!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDarkTheme
                                            ? const Color(0xFF5E3A9E) // Purple on light card
                                            : (isLightTheme
                                                ? const Color(0xFF5E3A9E)
                                                : Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: 8),
                      _buildSettingTile(
                        context: context,
                          icon: Icons.logout,
                          title: 'Sign Out',
                          subtitle: 'Sign out of your account',
                        isLightTheme: isLightTheme,
                        isDarkTheme: isDarkTheme,
                          iconColor: Colors.red,
                          onTap: () => _handleLogout(context),
                        ),
                      ] else ...[
                        // Show sign in option
                        _buildSettingTile(
                          context: context,
                          icon: Icons.login,
                          title: 'Sign In to backup your data',
                          subtitle: 'Sync your diary across devices',
                          isLightTheme: isLightTheme,
                          isDarkTheme: isDarkTheme,
                          onTap: _handleSignIn,
                            ),
                      ],
                      const SizedBox(height: 20),
                      // Version
                      Center(
                        child: Text(
                          'Version $_appVersion',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: isDarkTheme
                                ? Colors.white.withValues(alpha: 0.8) // White on dark background
                                : (isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildAppBar(bool isLightTheme, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
              size: 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Settings',
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
    );
  }

  Widget _buildSectionHeader(String title, bool isLightTheme, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDarkTheme
              ? Colors.white.withValues(alpha: 0.9)
              : (isLightTheme
              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.8)),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLightTheme,
    required bool isDarkTheme,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final cardColor = isLightTheme
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLightTheme
                ? Colors.black.withValues(alpha: 0.12)
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
                color: isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ??
                    (isDarkTheme
                        ? const Color(0xFF5E3A9E) // Purple on light card
                        : (isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white)),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDarkTheme
                          ? const Color(0xFF5E3A9E) // Purple on light card
                          : (isLightTheme
                              ? const Color(0xFF5E3A9E)
                              : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isDarkTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on light card
                          : (isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.6) // Purple on light card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.5)),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLightTheme,
    required bool isDarkTheme,
    required VoidCallback onTap,
  }) {
    final cardColor = isLightTheme
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLightTheme
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDarkTheme
                    ? const Color(0xFF5E3A9E) // Purple on light card
                    : (isLightTheme
                    ? const Color(0xFF5E3A9E)
                        : Colors.white),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDarkTheme
                          ? const Color(0xFF5E3A9E) // Purple on light card
                          : (isLightTheme
                          ? const Color(0xFF5E3A9E)
                              : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isDarkTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on light card
                          : (isLightTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.6) // Purple on light card
                  : (isLightTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.5)),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTileWithToggle({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLightTheme,
    required bool isDarkTheme,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cardColor = isLightTheme
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLightTheme
              ? Colors.black.withValues(alpha: 0.12)
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
              color: isLightTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E) // Purple on light card
                  : (isLightTheme
                  ? const Color(0xFF5E3A9E)
                      : Colors.white),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDarkTheme
                        ? const Color(0xFF5E3A9E) // Purple on light card
                        : (isLightTheme
                        ? const Color(0xFF5E3A9E)
                            : Colors.white),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: isDarkTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on light card
                        : (isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF5E3A9E),
            ),
          ),
        ],
      ),
    );
  }
}

