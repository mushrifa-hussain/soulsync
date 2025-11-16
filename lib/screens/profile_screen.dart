import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:soulsync_dairyapp/services/profile_service.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/screens/settings_page.dart';
import 'package:soulsync_dairyapp/screens/my_profile_screen.dart';
import 'package:soulsync_dairyapp/screens/auth/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isSignedIn = false;
  String? _displayName;
  String? _email;
  String? _photoUrl;
  String? _username;
  String _bio = 'Each day provides its own gifts.';
  String? _localPhotoPath;
  bool _isLoading = true;
  
  // Mood statistics
  String _moodFilter = 'Last 7 days';
  Map<String, int> _moodCounts = {};
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _loadProfile();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _loadProfile();
      }
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final isSignedIn = user != null;
      
    if (isSignedIn) {
        _email = user.email;
        _displayName = user.displayName ?? _email?.split('@')[0] ?? 'User';
        _photoUrl = user.photoURL;
        
        try {
      _username = await ProfileService.getUsername();
      _bio = await ProfileService.getBio();
      _localPhotoPath = await ProfileService.getLocalPhotoPath();
        } catch (e) {
          debugPrint('🔥 [PROFILE] Error loading profile data: $e');
          // Continue with default values
          _username = _displayName;
          _bio = 'Each day provides its own gifts.';
        }
        
        _loadMoodStatistics();
      } else {
        setState(() {
          _moodCounts = {};
          _displayName = null;
          _email = null;
          _photoUrl = null;
          _username = null;
          _bio = 'Each day provides its own gifts.';
          _localPhotoPath = null;
        });
    }

    setState(() {
      _isSignedIn = isSignedIn;
      _isLoading = false;
    });
    } catch (e) {
      debugPrint('🔥 [PROFILE] Error in _loadProfile: $e');
      // Fallback to Firebase Auth data only
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _email = user.email;
        _displayName = user.displayName ?? _email?.split('@')[0] ?? 'User';
        _photoUrl = user.photoURL;
        _username = _displayName;
        _bio = 'Each day provides its own gifts.';
        _isSignedIn = true;
      } else {
        _isSignedIn = false;
        _email = null;
        _displayName = null;
        _photoUrl = null;
        _username = null;
        _bio = 'Each day provides its own gifts.';
        _localPhotoPath = null;
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
          ),
    ).then((_) {
      _loadProfile();
    });
  }

  Future<void> _signOut() async {
    try {
      debugPrint('🔥 [LOGOUT] Starting logout');
      await FirebaseAuth.instance.signOut();
      debugPrint('🔥 [LOGOUT] Logout successful');
      
      if (!mounted) return;
      
      // Update UI silently
      await _loadProfile();
      
      // Show toast message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
            'Signed out',
              style: GoogleFonts.poppins(color: Colors.white),
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
      debugPrint('🔥 [LOGOUT ERROR] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign out failed: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
          ),
        );
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        // Copy image to app directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath = path.join(appDir.path, fileName);
        final File localFile = File(localPath);
        await File(image.path).copy(localFile.path);

        await ProfileService.saveLocalPhotoPath(localPath);
        setState(() {
          _localPhotoPath = localPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick image: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
          ),
        );
      }
    }
  }

  Future<void> _editUsername() async {
    final TextEditingController controller = TextEditingController(text: _username);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditDialog(
        title: 'Edit Username',
        initialValue: _username ?? '',
        controller: controller,
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ProfileService.updateUsername(result);
      setState(() {
        _username = result;
      });
    }
  }

  Future<void> _editBio() async {
    final TextEditingController controller = TextEditingController(text: _bio);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditDialog(
        title: 'Edit Bio',
        initialValue: _bio,
        controller: controller,
        maxLines: 3,
      ),
    );

    if (result != null) {
      await ProfileService.updateBio(result);
      setState(() {
        _bio = result;
      });
    }
  }

  void _loadMoodStatistics() {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;

    // Filter entries based on selected period
    final now = DateTime.now();
    switch (_moodFilter) {
      case 'Last 7 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 7)))
        ).toList();
        break;
      case 'Last 30 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 30)))
        ).toList();
        break;
      case 'Last 90 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 90)))
        ).toList();
        break;
      case 'All':
      default:
        // Use all entries
        break;
    }

    // Count moods
    final Map<String, int> counts = {};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty) {
        counts[entry.mood] = (counts[entry.mood] ?? 0) + 1;
      }
    }

    setState(() {
      _moodCounts = counts;
    });
  }

  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8D5FF).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF5E3A9E)),
              title: Text(
                'Log out',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5E3A9E),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFF5E3A9E)),
              title: Text(
                'Remove account data',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5E3A9E),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeAccountData();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAccountData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Account Data',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will remove all your local profile data. Are you sure?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProfileService.removeAccountData();
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLightTheme
                ? [
                    const Color(0xFFF8E7FF), // Soft purple-pink
                    const Color(0xFFE8D5FF), // Light purple
                    const Color(0xFFDDEBFF), // Soft blue
                  ]
                : [
                    const Color(0xFF2D1B3D),
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                      child: Column(
                        children: [
                        // Back Button (always visible)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 16.0,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.arrow_back_rounded,
                                      color: isLightTheme
                                          ? const Color(0xFF5E3A9E)
                                          : Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                              if (_isSignedIn)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                    icon: Icon(
                                      Icons.settings_outlined,
                                      color: isLightTheme
                                          ? const Color(0xFF5E3A9E)
                                          : Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SettingsPage(),
                                        ),
                                      );
                                    },
                                    ),
                                  ),
                                  ),
                                ],
                              ),
                            ),
                        // Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Column(
                              children: [
                          // Profile Section (Sign-In or Profile Header)
                          _buildProfileSection(isLightTheme),
                                // Sign Out Button (only when signed in)
                                if (_isSignedIn) ...[
                                  _buildSignOutButton(isLightTheme),
                                ],
                          // Statistics Sections (only when signed in)
                          if (_isSignedIn) ...[
                                  const SizedBox(height: 24),
                            // Mood Analytics Section
                                  _buildMoodAnalyticsSection(isLightTheme),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isLightTheme) {
    if (!_isSignedIn) {
      // Compact Professional Sign-In Card
      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isLightTheme
              ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLightTheme
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
            // Profile Icon
            Container(
              width: 64,
              height: 64,
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
                Icons.person_outline,
                size: 32,
                color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
                        // Welcome Title
                        Text(
              'Welcome / Tap to Sign In',
                          style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                            color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                          ),
                        ),
            const SizedBox(height: 8),
                        // Subtitle
                        Text(
              'Sign in to sync your diary',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                fontSize: 14,
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
            const SizedBox(height: 20),
                        // Google Sign-In Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _signInWithGoogle,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                  height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                      Icon(
                        Icons.login,
                        size: 20,
                        color: const Color(0xFF6B4C93),
                                  ),
                      const SizedBox(width: 10),
                                  Text(
                        'Sign In / Sign Up',
                                    style: GoogleFonts.poppins(
                          fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F1F1F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
          ],
        ),
      );
    }

    // Compact Horizontal Profile Header Card
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightTheme
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.3),
            blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
              builder: (context) => const MyProfileScreen(),
                          ),
                        );
          if (result == true) {
            // Reload profile if changes were made
            await _loadProfile();
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
                    children: [
            // Profile Photo
                      Container(
              width: 56,
              height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.9),
                              Colors.white.withValues(alpha: 0.7),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white,
                  width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _localPhotoPath != null && File(_localPhotoPath!).existsSync()
                              ? Image.file(
                                  File(_localPhotoPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultAvatar();
                                  },
                                )
                              : _photoUrl != null && _photoUrl!.isNotEmpty
                                  ? Image.network(
                                      _photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildDefaultAvatar();
                                      },
                                    )
                                  : _buildDefaultAvatar(),
                        ),
                      ),
            const SizedBox(width: 16),
            // Username and Bio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _username ?? _displayName ?? 'User',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _bio,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isLightTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Right Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isLightTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(bool isLightTheme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: ElevatedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, size: 18),
        label: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.1),
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.white.withValues(alpha: 0.5),
      child: const Icon(
        Icons.person,
        size: 50,
        color: Color(0xFF5E3A9E),
      ),
    );
  }

  Widget _buildMoodAnalyticsSection(bool isLightTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mood Statistics Bar Chart
        _buildMoodStatisticsSection(isLightTheme),
        const SizedBox(height: 24),
        // Additional Analytics Cards Row
        Row(
          children: [
            Expanded(
              child: _buildMoodPercentageCard(isLightTheme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMoodStabilityCard(isLightTheme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBestDayInWeeksCard(isLightTheme),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodPercentageCard(bool isLightTheme) {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;
    
    // Filter entries based on selected period
    final now = DateTime.now();
    switch (_moodFilter) {
      case 'Last 7 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 7)))
        ).toList();
        break;
      case 'Last 30 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 30)))
        ).toList();
        break;
      case 'Last 90 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 90)))
        ).toList();
        break;
      case 'All':
      default:
        break;
    }
    
    if (entries.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
            padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                color: isLightTheme
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                  color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                              ),
                            ],
                          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 24,
                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
                          ),
                const SizedBox(height: 8),
                Text(
                  'No data',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final moodPercentages = <String, double>{};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty) {
        moodPercentages[entry.mood] = (moodPercentages[entry.mood] ?? 0) + 1;
      }
    }
    
    final totalEntries = entries.length;
    if (totalEntries == 0 || moodPercentages.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLightTheme
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 24,
                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'No data',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Convert to percentages
    moodPercentages.forEach((key, value) {
      moodPercentages[key] = (value / totalEntries) * 100;
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
                    boxShadow: [
                      BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
                      ),
                    ],
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                    children: [
                      Icon(
                    Icons.pie_chart_outline,
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    size: 18,
                      ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mood %',
                        style: GoogleFonts.poppins(
                        fontSize: 13,
                          fontWeight: FontWeight.w600,
                        color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                      ),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: PieChart(
                  PieChartData(
                    sections: _buildPieChartSections(moodPercentages),
                    centerSpaceRadius: 35,
                    sectionsSpace: 2,
                  ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodStabilityCard(bool isLightTheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_outlined,
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Stability',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: _buildMoodStabilityChartOnly(isLightTheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodStatisticsSection(bool isLightTheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mood Statistics',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _moodFilter,
                    items: const [
                      DropdownMenuItem(value: 'Last 7 days', child: Text('Last 7 days')),
                      DropdownMenuItem(value: 'Last 30 days', child: Text('Last 30 days')),
                      DropdownMenuItem(value: 'Last 90 days', child: Text('Last 90 days')),
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _moodFilter = value;
                        });
                        _loadMoodStatistics();
                      }
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                    underline: Container(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_moodCounts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 48,
                          color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No mood data available',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _moodCounts.values.isEmpty
                          ? 1.0
                          : _moodCounts.values.reduce((a, b) => a > b ? a : b).toDouble() + 1,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => const Color(0xFF5E3A9E).withValues(alpha: 0.9),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final moods = _moodCounts.keys.toList();
                              if (value.toInt() < moods.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    moods[value.toInt()],
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(0xFF5E3A9E).withValues(alpha: 0.7),
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 40,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.7),
                                ),
                              );
                            },
                            reservedSize: 30,
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _moodCounts.entries.map((entry) {
                        final index = _moodCounts.keys.toList().indexOf(entry.key);
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  const Color(0xFF5E3A9E),
                                  const Color(0xFF9B7EDE),
                                ],
                              ),
                              width: 24,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              // Mood emojis below chart
              if (_moodCounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _moodCounts.keys.map((mood) {
                    return Text(
                      mood,
                      style: const TextStyle(fontSize: 24),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodPercentageSection(bool isLightTheme) {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;
    
    // Filter entries based on selected period
    final now = DateTime.now();
    switch (_moodFilter) {
      case 'Last 7 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 7)))
        ).toList();
        break;
      case 'Last 30 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 30)))
        ).toList();
        break;
      case 'Last 90 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 90)))
        ).toList();
        break;
      case 'All':
      default:
        // Use all entries
        break;
    }
    
    final totalEntries = entries.length;
    
    if (totalEntries == 0) {
      return _buildEmptyStatCard(
        isLightTheme,
        'Moods Percentage',
        Icons.pie_chart_outline,
      );
    }

    final moodPercentages = <String, double>{};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty) {
        moodPercentages[entry.mood] = (moodPercentages[entry.mood] ?? 0) + 1;
      }
    }
    
    // Convert to percentages
    moodPercentages.forEach((key, value) {
      moodPercentages[key] = (value / totalEntries) * 100;
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Moods Percentage',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (moodPercentages.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No mood data',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: _buildPieChartSections(moodPercentages),
                      centerSpaceRadius: 60,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, double> percentages) {
    final colors = [
      const Color(0xFF5E3A9E),
      const Color(0xFFFFB6C1),
      const Color(0xFFB0E0E6),
      const Color(0xFFDDA0DD),
      const Color(0xFFFFE4B5),
      const Color(0xFF98FB98),
    ];
    
    final entries = percentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final moodEntry = entry.value;
      return PieChartSectionData(
        value: moodEntry.value,
        title: '${moodEntry.value.toStringAsFixed(0)}%',
        color: colors[index % colors.length],
        radius: 80,
        titleStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildMoodStabilityChartOnly(bool isLightTheme) {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;
    
    // Filter entries based on selected period
    final now = DateTime.now();
    switch (_moodFilter) {
      case 'Last 7 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 7)))
        ).toList();
        break;
      case 'Last 30 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 30)))
        ).toList();
        break;
      case 'Last 90 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 90)))
        ).toList();
        break;
      case 'All':
      default:
        break;
    }
    
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
          ),
        ),
      );
    }

    // Group entries by day and calculate average mood score
    final dayMoods = <DateTime, List<String>>{};
    for (final entry in entries) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (entry.mood.isNotEmpty) {
        dayMoods.putIfAbsent(day, () => []).add(entry.mood);
      }
    }

    if (dayMoods.isEmpty) {
      return Center(
        child: Text(
          'No mood data',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
          ),
        ),
      );
    }

    // Map moods to scores for trend calculation
    final moodScores = {
      '😊': 8.0, '😍': 9.0, '😎': 7.0, '🥰': 9.5, '😇': 7.5,
      '😋': 8.5, '😌': 6.5, '🤔': 5.0, '😢': 3.0, '😴': 4.0,
    };
    
    final sortedDays = dayMoods.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final moods = dayMoods[day]!;
      double avgScore = 0.0;
      int count = 0;
      
      for (final mood in moods) {
        if (moodScores.containsKey(mood)) {
          avgScore += moodScores[mood]!;
          count++;
        }
      }
      
      if (count > 0) {
        spots.add(FlSpot(i.toDouble(), avgScore / count));
      }
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5E3A9E),
                const Color(0xFF9B7EDE),
              ],
            ),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5E3A9E).withValues(alpha: 0.15),
                  Color(0xFF9B7EDE).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
        minY: 0,
        maxY: 10,
      ),
    );
  }

  Widget _buildMoodStabilityLineChart(bool isLightTheme) {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;
    
    // Filter entries based on selected period
    final now = DateTime.now();
    switch (_moodFilter) {
      case 'Last 7 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 7)))
        ).toList();
        break;
      case 'Last 30 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 30)))
        ).toList();
        break;
      case 'Last 90 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 90)))
        ).toList();
        break;
      case 'All':
      default:
        // Use all entries
        break;
    }
    
    if (entries.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLightTheme
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.show_chart_outlined,
                    size: 32,
                    color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No data',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Group entries by day and calculate average mood score
    final dayMoods = <DateTime, List<String>>{};
    for (final entry in entries) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (entry.mood.isNotEmpty) {
        dayMoods.putIfAbsent(day, () => []).add(entry.mood);
      }
    }

    if (dayMoods.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLightTheme
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'No mood data',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Map moods to scores for trend calculation
    final moodScores = {
      '😊': 8.0, '😍': 9.0, '😎': 7.0, '🥰': 9.5, '😇': 7.5,
      '😋': 8.5, '😌': 6.5, '🤔': 5.0, '😢': 3.0, '😴': 4.0,
    };
    
    final sortedDays = dayMoods.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final moods = dayMoods[day]!;
      double avgScore = 0.0;
      int count = 0;
      
      for (final mood in moods) {
        if (moodScores.containsKey(mood)) {
          avgScore += moodScores[mood]!;
          count++;
        }
      }
      
      if (count > 0) {
        spots.add(FlSpot(i.toDouble(), avgScore / count));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_outlined,
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mood Stability',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: false,
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF5E3A9E),
                            const Color(0xFF9B7EDE),
                          ],
                        ),
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: false,
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF5E3A9E).withValues(alpha: 0.15),
                              const Color(0xFF9B7EDE).withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                    ],
                    minY: 0,
                    maxY: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBestDayInWeeksCard(bool isLightTheme) {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;
    
    // Filter entries based on selected period
    final now = DateTime.now();
    switch (_moodFilter) {
      case 'Last 7 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 7)))
        ).toList();
        break;
      case 'Last 30 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 30)))
        ).toList();
        break;
      case 'Last 90 days':
        entries = entries.where((e) => 
          e.timestamp.isAfter(now.subtract(const Duration(days: 90)))
        ).toList();
        break;
      case 'All':
      default:
        // Use all entries
        break;
    }
    
    if (entries.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLightTheme
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                  size: 18,
                ),
                const SizedBox(height: 8),
                      Text(
                  'Best Day',
                        style: GoogleFonts.poppins(
                    fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                  'No data',
                        style: GoogleFonts.poppins(
                    fontSize: 11,
                          color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Find day with highest mood score in the selected period
    final moodScores = {
      '😊': 8.0, '😍': 9.0, '😎': 7.0, '🥰': 9.5, '😇': 7.5,
      '😋': 8.5, '😌': 6.5, '🤔': 5.0, '😢': 3.0, '😴': 4.0,
    };
    
    final dayScores = <DateTime, ({double score, String mood})>{};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty && moodScores.containsKey(entry.mood)) {
        final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
        final score = moodScores[entry.mood]!;
        if (!dayScores.containsKey(day) || dayScores[day]!.score < score) {
          dayScores[day] = (score: score, mood: entry.mood);
        }
      }
    }

    if (dayScores.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLightTheme
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                  size: 18,
                ),
                const SizedBox(height: 8),
                      Text(
                  'Best Day',
                        style: GoogleFonts.poppins(
                    fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                  'Keep writing',
                        style: GoogleFonts.poppins(
                    fontSize: 11,
                          color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bestDay = dayScores.entries.reduce((a, b) => a.value.score > b.value.score ? a : b);
    final dateFormat = DateFormat('MMM d');
    final bestDayText = dateFormat.format(bestDay.key);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  Icons.calendar_today_outlined,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                size: 18,
              ),
              const SizedBox(height: 8),
                    Text(
                'Best Day',
                      style: GoogleFonts.poppins(
                  fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                      ),
                    ),
              const SizedBox(height: 8),
                        Text(
                          bestDay.value.mood,
                style: const TextStyle(fontSize: 24),
                        ),
              const SizedBox(height: 4),
              Text(
                            bestDayText,
                            style: GoogleFonts.poppins(
                  fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isLightTheme
                                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.8),
                            ),
                textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreStatsSection(bool isLightTheme) {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    final entries = provider.entries;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More Stats',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatInfoCard(
                      isLightTheme,
                      'Longest Streak',
                      Icons.local_fire_department_outlined,
                      _calculateLongestStreak(entries).toString(),
                      'days',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatInfoCard(
                      isLightTheme,
                      'Most Common',
                      Icons.favorite_outline,
                      _getMostCommonEmotion(entries),
                      'emotion',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatInfoCard(
                      isLightTheme,
                      'Avg Feeling',
                      Icons.sentiment_satisfied_outlined,
                      _calculateAvgFeelingScore(entries).toStringAsFixed(1),
                      'score',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatInfoCard(
                      isLightTheme,
                      'Entries/Month',
                      Icons.insert_chart_outlined,
                      _calculateEntriesPerMonth(entries).toStringAsFixed(1),
                      'avg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Entries per month chart
              Text(
                'Entries Over Time',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: _buildEntriesPerMonthChart(isLightTheme, entries),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    bool isLightTheme,
    String title,
    IconData icon,
    String value,
    String subtitle,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
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
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStatCard(bool isLightTheme, String title, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLightTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatInfoCard(
    bool isLightTheme,
    String title,
    IconData icon,
    String value,
    String unit,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.grey.shade50
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFF5E3A9E).withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesPerMonthChart(bool isLightTheme, List<DiaryEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No entries yet',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
          ),
        ),
      );
    }

    // Group entries by month
    final monthCounts = <String, int>{};
    for (final entry in entries) {
      final monthKey = DateFormat('MMM yyyy').format(entry.timestamp);
      monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
    }

    final sortedMonths = monthCounts.keys.toList()..sort();
    final maxCount = monthCounts.values.isEmpty ? 1 : monthCounts.values.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < sortedMonths.length) {
                  final month = sortedMonths[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      month.split(' ')[0], // Just month name
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF5E3A9E).withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF5E3A9E).withValues(alpha: 0.7),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: sortedMonths.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                monthCounts[entry.value]!.toDouble(),
              );
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5E3A9E),
                const Color(0xFF9B7EDE),
              ],
            ),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF5E3A9E),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF5E3A9E).withValues(alpha: 0.2),
                  const Color(0xFF9B7EDE).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
        minY: 0,
        maxY: maxCount.toDouble() + 1,
      ),
    );
  }

  int _calculateLongestStreak(List<DiaryEntry> entries) {
    if (entries.isEmpty) return 0;
    
    final sortedEntries = List<DiaryEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    int longestStreak = 1;
    int currentStreak = 1;
    
    for (int i = 1; i < sortedEntries.length; i++) {
      final prevDate = DateTime(
        sortedEntries[i - 1].timestamp.year,
        sortedEntries[i - 1].timestamp.month,
        sortedEntries[i - 1].timestamp.day,
      );
      final currDate = DateTime(
        sortedEntries[i].timestamp.year,
        sortedEntries[i].timestamp.month,
        sortedEntries[i].timestamp.day,
      );
      
      final daysDiff = currDate.difference(prevDate).inDays;
      if (daysDiff == 1) {
        currentStreak++;
        longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;
      } else {
        currentStreak = 1;
      }
    }
    
    return longestStreak;
  }

  String _getMostCommonEmotion(List<DiaryEntry> entries) {
    if (entries.isEmpty) return '—';
    
    final moodCounts = <String, int>{};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty) {
        moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
      }
    }
    
    if (moodCounts.isEmpty) return '—';
    
    final mostCommon = moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return mostCommon.key;
  }

  double _calculateAvgFeelingScore(List<DiaryEntry> entries) {
    if (entries.isEmpty) return 0.0;
    
    // Map moods to scores (simple scoring system)
    final moodScores = {
      '😊': 8.0,
      '😍': 9.0,
      '😎': 7.0,
      '🥰': 9.5,
      '😇': 7.5,
      '😋': 8.5,
      '😌': 6.5,
      '🤔': 5.0,
      '😢': 3.0,
      '😴': 4.0,
    };
    
    double totalScore = 0.0;
    int count = 0;
    
    for (final entry in entries) {
      if (entry.mood.isNotEmpty && moodScores.containsKey(entry.mood)) {
        totalScore += moodScores[entry.mood]!;
        count++;
      }
    }
    
    return count > 0 ? totalScore / count : 0.0;
  }

  double _calculateEntriesPerMonth(List<DiaryEntry> entries) {
    if (entries.isEmpty) return 0.0;
    
    final sortedEntries = List<DiaryEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    final firstEntry = sortedEntries.first.timestamp;
    final lastEntry = sortedEntries.last.timestamp;
    final monthsDiff = (lastEntry.year - firstEntry.year) * 12 + 
                       (lastEntry.month - firstEntry.month) + 1;
    
    return monthsDiff > 0 ? entries.length / monthsDiff : entries.length.toDouble();
  }
}

class _EditDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final TextEditingController controller;
  final int maxLines;

  const _EditDialog({
    required this.title,
    required this.initialValue,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: widget.controller,
        maxLines: widget.maxLines,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, widget.controller.text),
          child: Text(
            'Save',
            style: GoogleFonts.poppins(color: const Color(0xFF5E3A9E)),
          ),
        ),
      ],
    );
  }
}
