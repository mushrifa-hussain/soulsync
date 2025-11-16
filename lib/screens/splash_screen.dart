import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soulsync_dairyapp/screens/onboarding_screen.dart';
import 'package:soulsync_dairyapp/screens/pin_unlock_page.dart';
import 'package:soulsync_dairyapp/screens/auth/login_screen.dart';
import 'package:soulsync_dairyapp/services/app_storage_service.dart';
import 'package:soulsync_dairyapp/services/lock_service.dart';
import 'package:soulsync_dairyapp/services/notification_service.dart';
import 'package:soulsync_dairyapp/services/reminder_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _textFadeIn;
  late final Animation<Offset> _textSlideUp;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _textSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // Check if first launch and navigate accordingly
    Future.delayed(const Duration(milliseconds: 3000), _checkFirstLaunch);
  }

  void _checkFirstLaunch() async {
    if (!mounted) return;
    
    // Initialize notifications and re-schedule reminders
    await _initializeNotifications();
    
    // Check if theme has been selected
    final isThemeSelected = await AppStorageService.isThemeSelected();
    
    if (isThemeSelected) {
      // Theme already selected - check authentication
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        // User not logged in - redirect to login (signup is mandatory)
        _goToLogin();
      } else {
        // User is logged in - proceed to home (with PIN check if exists)
        final hasPin = await LockService.hasPin();
        if (hasPin) {
          // PIN exists, show unlock screen
          _goToUnlock();
        } else {
          // No PIN, go directly to home screen
          _goToHome();
        }
      }
    } else {
      // Theme not selected - this only happens on FIRST INSTALL
      // If user closes app before selecting theme, they'll restart from onboarding
      // This restart behavior ONLY applies during first install, not after theme is selected
      _goToOnboarding();
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      // Initialize notification service
      final notificationService = NotificationService();
      await notificationService.initialize();
      
      // Re-schedule all future reminders
      final reminderService = ReminderService();
      await reminderService.rescheduleAllReminders();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  void _goToUnlock() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PinUnlockPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  void _goToOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  void _goToHome() {
    if (!mounted) return;
    // Navigate to Home and clear all previous routes to make Home the root
    // This ensures back button on Home will exit the app
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false, // Remove all previous routes
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE5F1), // Soft pink
              Color(0xFFE8D5FF), // Soft purple
              Color(0xFFB8E6FF), // Sky blue
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 100), // push logo slightly down
                  Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE8D5FF).withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFE5F1).withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          child: Transform.scale(
                            scale: 1.6, // logo bigger inside the same circle
                            child: Image.asset(
                              'assets/images/logo.jpg',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.book_outlined,
                                size: 100,
                                color: Color(0xFFFF6B9D),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 250),
                  SlideTransition(
                    position: _textSlideUp,
                    child: FadeTransition(
                      opacity: _textFadeIn,
                      child: _buildSoulSyncText(
                        fontSize: 47,
                        isLightTheme: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Intelligent Diary Companion',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF5E3A9E),
                      fontWeight: FontWeight.w500,
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

  /// Build styled SoulSync text with dreamy aesthetic
  Widget _buildSoulSyncText({
    required double fontSize,
    required bool isLightTheme,
  }) {
    return Text(
      'SoulSync',
      style: GoogleFonts.dancingScript(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.8,
        color: isLightTheme
            ? const Color(0xFF5E3A9E) // Deep purple
            : Colors.white,
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: 0.3),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
