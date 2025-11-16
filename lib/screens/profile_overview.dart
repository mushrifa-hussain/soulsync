import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:soulsync_dairyapp/services/profile_service.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/widgets/profile_card.dart';
import 'package:soulsync_dairyapp/widgets/mood_statistics.dart';
import 'package:soulsync_dairyapp/screens/edit_profile_page.dart';
import 'package:soulsync_dairyapp/screens/auth/auth_screen.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';

class ProfileOverviewPage extends StatefulWidget {
  const ProfileOverviewPage({super.key});

  @override
  State<ProfileOverviewPage> createState() => _ProfileOverviewPageState();
}

class _ProfileOverviewPageState extends State<ProfileOverviewPage>
    with SingleTickerProviderStateMixin {
  bool _isSignedIn = false;
  String? _displayName;
  String? _email;
  String? _photoUrl;
  String? _username;
  String _bio = '';
  String? _localPhotoPath;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
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
          debugPrint('Error loading profile data: $e');
          _username = _displayName;
          _bio = '';
        }
      } else {
        setState(() {
          _displayName = null;
          _email = null;
          _photoUrl = null;
          _username = null;
          _bio = '';
          _localPhotoPath = null;
        });
      }

      setState(() {
        _isSignedIn = isSignedIn;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error in _loadProfile: $e');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _email = user.email;
        _displayName = user.displayName ?? _email?.split('@')[0] ?? 'User';
        _photoUrl = user.photoURL;
        _username = _displayName;
        _bio = '';
        _isSignedIn = true;
      } else {
        _isSignedIn = false;
        _email = null;
        _displayName = null;
        _photoUrl = null;
        _username = null;
        _bio = '';
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
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
    if (result == true) {
      _loadProfile();
    }
  }

  // Mood filter is handled by MoodStatisticsWidget

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
    final iconColor = isDarkTheme
        ? Colors.white
        : colorScheme.onSurface;
    final textColor = isDarkTheme
        ? Colors.white
        : colorScheme.onSurface;
    
    return Scaffold(
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkTheme ? Colors.white : colorScheme.primary,
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // App Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: iconColor,
                                  size: 24,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  'Profile',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
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
                                const SizedBox(height: 8),
                                // Profile Section
                                if (!_isSignedIn)
                                  _buildSignInCard(colorScheme, isLightTheme, isDarkTheme)
                                else
                                  ProfileCard(
                                    name: _username ?? _displayName,
                                    bio: _bio,
                                    localPhotoPath: _localPhotoPath,
                                    photoUrl: _photoUrl,
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                              const EditProfilePage(),
                                          transitionsBuilder:
                                              (context, animation, secondaryAnimation, child) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0.0, 0.1),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                      if (result == true) {
                                        await _loadProfile();
                                      }
                                    },
                                  ),
                                // Statistics Sections (only when signed in)
                                if (_isSignedIn) ...[
                                  const SizedBox(height: 24),
                                  _buildMoodStatisticsCard(colorScheme, isLightTheme, isDarkTheme),
                                  const SizedBox(height: 16),
                                  _buildAnalyticsRow(colorScheme, isLightTheme, isDarkTheme),
                                ],
                                const SizedBox(height: 24),
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

  Widget _buildSignInCard(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _signInWithGoogle,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLightTheme
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
                blurRadius: 18,
                offset: const Offset(0, 5),
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome / Tap to Sign In',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme
                      ? const Color(0xFF5E3A9E) // Purple on light card
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to sync your diary',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDarkTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on light card
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodStatisticsCard(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme) {
    return MoodStatisticsWidget();
  }

  Widget _buildAnalyticsRow(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme) {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;

    // Note: We use all entries for analytics cards, not filtered
    // The mood statistics widget handles its own filtering

    return Row(
      children: [
        Expanded(
          child: _buildBestDayCard(colorScheme, isLightTheme, isDarkTheme, entries),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStabilityCard(colorScheme, isLightTheme, isDarkTheme, entries),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMoodPercentageCard(colorScheme, isLightTheme, isDarkTheme, entries),
        ),
      ],
    );
  }

  Widget _buildBestDayCard(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme, List<DiaryEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyInfoCard(colorScheme, isLightTheme, isDarkTheme, 'Best Day', Icons.calendar_today_outlined);
    }

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
      return _buildEmptyInfoCard(colorScheme, isLightTheme, isDarkTheme, 'Best Day', Icons.calendar_today_outlined);
    }

    final bestDay = dayScores.entries.reduce((a, b) => a.value.score > b.value.score ? a : b);
    final dateFormat = DateFormat('MMM d');
    final bestDayText = dateFormat.format(bestDay.key);

    return _buildInfoCard(
      colorScheme,
      isLightTheme,
      isDarkTheme,
      'Best Day',
      Icons.calendar_today_outlined,
      bestDay.value.mood,
      bestDayText,
    );
  }

  Widget _buildStabilityCard(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme, List<DiaryEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyInfoCard(colorScheme, isLightTheme, isDarkTheme, 'Stability', Icons.show_chart_outlined);
    }

    final moodScores = {
      '😊': 8.0, '😍': 9.0, '😎': 7.0, '🥰': 9.5, '😇': 7.5,
      '😋': 8.5, '😌': 6.5, '🤔': 5.0, '😢': 3.0, '😴': 4.0,
    };

    final dayMoods = <DateTime, List<String>>{};
    for (final entry in entries) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (entry.mood.isNotEmpty) {
        dayMoods.putIfAbsent(day, () => []).add(entry.mood);
      }
    }

    if (dayMoods.isEmpty) {
      return _buildEmptyInfoCard(colorScheme, isLightTheme, isDarkTheme, 'Stability', Icons.show_chart_outlined);
    }

    final sortedDays = dayMoods.keys.toList()..sort();
    final scores = <double>[];

    for (final day in sortedDays) {
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
        scores.add(avgScore / count);
      }
    }

    if (scores.isEmpty) {
      return _buildEmptyInfoCard(colorScheme, isLightTheme, isDarkTheme, 'Stability', Icons.show_chart_outlined);
    }

    final variance = _calculateVariance(scores);
    final stability = (10 - variance).clamp(0.0, 10.0);
    final stabilityText = stability >= 7 ? 'High' : stability >= 4 ? 'Medium' : 'Low';

    return _buildInfoCard(
      colorScheme,
      isLightTheme,
      isDarkTheme,
      'Stability',
      Icons.show_chart_outlined,
      stabilityText,
      '${stability.toStringAsFixed(1)}/10',
    );
  }

  Widget _buildMoodPercentageCard(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme, List<DiaryEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyInfoCard(colorScheme, isLightTheme, isDarkTheme, 'Mood %', Icons.pie_chart_outline);
    }

    final moodPercentages = <String, double>{};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty) {
        moodPercentages[entry.mood] = (moodPercentages[entry.mood] ?? 0) + 1;
      }
    }

    if (moodPercentages.isEmpty) {
      return _buildEmptyInfoCard(colorScheme, isLightTheme, isDarkTheme, 'Mood %', Icons.pie_chart_outline);
    }

    final totalEntries = entries.length;
    moodPercentages.forEach((key, value) {
      moodPercentages[key] = (value / totalEntries) * 100;
    });

    final mostCommon = moodPercentages.entries.reduce((a, b) => a.value > b.value ? a : b);

    return _buildInfoCard(
      colorScheme,
      isLightTheme,
      isDarkTheme,
      'Mood %',
      Icons.pie_chart_outline,
      mostCommon.key,
      '${mostCommon.value.toStringAsFixed(0)}%',
    );
  }

  Widget _buildInfoCard(
    ColorScheme colorScheme,
    bool isLightTheme,
    bool isDarkTheme,
    String title,
    IconData icon,
    String emoji,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLightTheme
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.8)
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDarkTheme
                  ? Colors.white
                  : colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDarkTheme
                  ? Colors.white.withValues(alpha: 0.8)
                  : colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInfoCard(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme, String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLightTheme
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.6)
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDarkTheme
                  ? Colors.white
                  : colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No data',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDarkTheme
                  ? Colors.white.withValues(alpha: 0.7)
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean)).toList();
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }
}

