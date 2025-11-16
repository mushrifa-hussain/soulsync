import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soulsync_dairyapp/screens/personalization_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _skipButtonOpacity = 1.0;
  double _nextButtonOpacity = 1.0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to SoulSync',
      description:
          'Your personal space to capture thoughts, feelings, and memories in a beautiful, calming environment.',
      icon: Icons.favorite_outline,
      color: Color(0xFFFF6B9D),
    ),
    OnboardingPage(
      title: 'Track Your Moods',
      description:
          'Express how you feel each day with our intuitive mood tracking feature. Understand your emotional patterns over time.',
      icon: Icons.mood_outlined,
      color: Color(0xFF9B7BFF),
    ),
    OnboardingPage(
      title: 'Write Freely',
      description:
          'Pour your heart out in a safe, private space. Your thoughts are yours alone, beautifully preserved.',
      icon: Icons.edit_outlined,
      color: Color(0xFF6BC5FF),
    ),
    OnboardingPage(
      title: 'AI Companion',
      description:
          'Chat with your intelligent diary companion to reflect, gain insights, and discover patterns in your journey.',
      icon: Icons.psychology_outlined,
      color: Color(0xFFFFB84D),
    ),
    OnboardingPage(
      title: 'Start Your Journey',
      description:
          'Begin your journey of self-discovery and reflection with your SoulSync Journal. Every entry is a step towards understanding yourself better.',
      icon: Icons.rocket_launch_outlined,
      color: Color(0xFF5E3A9E),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    // Don't mark as complete here - only mark when theme is selected
    // This ensures app restarts from beginning if user closes before theme selection
    if (!mounted || !context.mounted) return;
    try {
      // Use instant transition - no fade, just immediate replacement
      // This matches the smooth personalization->theme selection transition
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PersonalizationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Return child immediately without any opacity animation
            // The screen is already fully opaque, so no fade needed
            return child;
          },
          transitionDuration: Duration.zero, // Instant transition
          reverseTransitionDuration: Duration.zero,
          opaque: true, // Ensure new screen is fully opaque
        ),
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFE5F1), // Soft pink
              const Color(0xFFE8D5FF), // Soft purple
              const Color(0xFFB8E6FF), // Sky blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              if (_currentPage < _pages.length - 1)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          _skipButtonOpacity = 0.5;
                        });
                      },
                      onTapUp: (_) {
                        setState(() {
                          _skipButtonOpacity = 1.0;
                        });
                        _completeOnboarding();
                      },
                      onTapCancel: () {
                        setState(() {
                          _skipButtonOpacity = 1.0;
                        });
                      },
                      child: AnimatedOpacity(
                        opacity: _skipButtonOpacity,
                        duration: const Duration(milliseconds: 100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: const Color(0xFF5E3A9E),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Page Indicator
              _buildPageIndicator(),

              // Next/Get Started Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildNavigationButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: page.color.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: page.color,
            ),
          ),
          const SizedBox(height: 60),
          // Title
          Text(
            page.title,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5E3A9E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            page.description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF5E3A9E),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? const Color(0xFF5E3A9E)
                : const Color(0xFFD4C5E8),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    // Both "Next" and "Continue" buttons as text-only with same styling
    return Center(
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _nextButtonOpacity = 0.5;
          });
        },
        onTapUp: (_) {
          setState(() {
            _nextButtonOpacity = 1.0;
          });
          _nextPage();
        },
        onTapCancel: () {
          setState(() {
            _nextButtonOpacity = 1.0;
          });
        },
        child: AnimatedOpacity(
          opacity: _nextButtonOpacity,
          duration: const Duration(milliseconds: 100),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Text(
              _currentPage == _pages.length - 1 ? 'Continue' : 'Next',
              style: TextStyle(
                color: const Color(0xFF5E3A9E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

