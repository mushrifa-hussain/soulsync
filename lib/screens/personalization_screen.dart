import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:soulsync_dairyapp/services/personalization_service.dart';
import 'package:soulsync_dairyapp/screens/theme_selection_page.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  final PageController _pageController = PageController();
  final PersonalizationService _personalizationService = PersonalizationService();
  int _currentQuestion = 0;
  final List<int?> _selectedOptions = [null, null, null];

  final List<PersonalizationQuestion> _questions = [
    PersonalizationQuestion(
      question: 'What brings you to SoulSync today?',
      options: [
        PersonalizationOption(
          text: 'I want a safe space to express my thoughts',
          emoji: '💭',
        ),
        PersonalizationOption(
          text: 'I\'d like to reflect and grow emotionally',
          emoji: '🌱',
        ),
        PersonalizationOption(
          text: 'I need a friend who listens',
          emoji: '🤍',
        ),
        PersonalizationOption(
          text: 'I just love journaling',
          emoji: '✍️',
        ),
      ],
    ),
    PersonalizationQuestion(
      question: 'How do you like to write in your journal?',
      options: [
        PersonalizationOption(
          text: 'Freely — I just write whatever comes to mind',
          emoji: '🕊️',
        ),
        PersonalizationOption(
          text: 'Reflectively — I like to think and analyze',
          emoji: '🧠',
        ),
        PersonalizationOption(
          text: 'Emotionally — I write about how I feel',
          emoji: '💖',
        ),
        PersonalizationOption(
          text: 'Creatively — I enjoy writing with imagination',
          emoji: '🎨',
        ),
      ],
    ),
    PersonalizationQuestion(
      question: 'What do you hope SoulSync will help you with?',
      options: [
        PersonalizationOption(
          text: 'Understanding myself better',
          emoji: '🌿',
        ),
        PersonalizationOption(
          text: 'Managing emotions calmly',
          emoji: '☁️',
        ),
        PersonalizationOption(
          text: 'Staying consistent with journaling',
          emoji: '✨',
        ),
        PersonalizationOption(
          text: 'Feeling less alone',
          emoji: '💬',
        ),
      ],
    ),
  ];

  // Track if assets are preloaded
  bool _assetsPreloaded = false;
  // Preloaded first theme color for instant display
  Color? _firstThemeBackgroundColor;
  Color? _firstThemeDotColor;
  
  @override
  void initState() {
    super.initState();
    // Load saved answers if they exist
    for (int i = 0; i < _questions.length; i++) {
      final savedAnswer = _personalizationService.getAnswer(i);
      if (savedAnswer != null) {
        final index = _questions[i].options
            .indexWhere((option) => option.text == savedAnswer);
        if (index != -1) {
          _selectedOptions[i] = index;
        }
      }
    }
    
    // Preload theme images immediately in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadThemeSelectionAssets();
    });
  }
  
  /// Preload all theme images and first theme color before navigation
  Future<void> _preloadThemeSelectionAssets() async {
    if (_assetsPreloaded) return;
    
    try {
      // Preload all theme images
      final themePaths = [
        'assets/themes/theme_blossom_serenity.jpg',
        'assets/themes/theme_ocean_haze.jpg',
        'assets/themes/theme_midnight_whispers.jpg',
        'assets/themes/theme_rainbow_whispers.jpg',
        'assets/themes/theme_angel_feathers.jpg',
        'assets/themes/theme_butterfly_night.jpg',
        'assets/themes/theme_cozy_evening_glow.jpg',
        'assets/themes/theme_dreamy_dawn.jpg',
      ];
      
      // Precache all images in parallel
      final imageProviders = themePaths.map((path) => AssetImage(path));
      await Future.wait(
        imageProviders.map((provider) => precacheImage(provider, context)),
      );
      
      // Extract color from first theme image immediately for instant display
      await _extractFirstThemeColor(themePaths[0]);
      
      if (mounted) {
        setState(() {
          _assetsPreloaded = true;
        });
      }
      
      debugPrint('Theme images and first color preloaded successfully');
    } catch (e) {
      debugPrint('Error preloading theme images: $e');
      // Mark as preloaded even on error to allow navigation
      if (mounted) {
        setState(() {
          _assetsPreloaded = true;
        });
      }
    }
  }
  
  /// Extract color from first theme image for instant background display
  Future<void> _extractFirstThemeColor(String themePath) async {
    try {
      final imageProvider = AssetImage(themePath);
      final image = await _loadImageFromProvider(imageProvider);
      
      if (image == null) {
        debugPrint('Warning: First theme image is null');
        return;
      }
      
      // Extract color from bottom portion of image
      final bottomRegion = Rect.fromLTWH(
        0,
        image.height * 0.60,
        image.width.toDouble(),
        image.height * 0.40,
      );
      
      final paletteGenerator = await PaletteGenerator.fromImage(
        image,
        region: bottomRegion,
        maximumColorCount: 10,
      );
      
      Color? dominantColor = paletteGenerator.dominantColor?.color;
      
      if (dominantColor == null && paletteGenerator.vibrantColor != null) {
        dominantColor = paletteGenerator.vibrantColor!.color;
      }
      
      if (dominantColor == null && paletteGenerator.mutedColor != null) {
        dominantColor = paletteGenerator.mutedColor!.color;
      }
      
      if (dominantColor == null && paletteGenerator.colors.isNotEmpty) {
        dominantColor = paletteGenerator.colors.first;
      }
      
      if (dominantColor != null) {
        // Calculate page background color (slightly lighter)
        final pageBackgroundColor = Color.fromRGBO(
          ((dominantColor.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          ((dominantColor.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          ((dominantColor.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          1.0,
        );
        
        if (mounted) {
          _firstThemeBackgroundColor = pageBackgroundColor;
          _firstThemeDotColor = dominantColor;
        }
        
        debugPrint('First theme color extracted: ${pageBackgroundColor.toString()}');
      }
    } catch (e) {
      debugPrint('Error extracting first theme color: $e');
    }
  }
  
  /// Load image from provider
  Future<ui.Image?> _loadImageFromProvider(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    final imageStream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
    });
    imageStream.addListener(listener);
    final image = await completer.future;
    imageStream.removeListener(listener);
    return image;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onOptionSelected(int questionIndex, int optionIndex) {
    setState(() {
      _selectedOptions[questionIndex] = optionIndex;
      // Save the answer immediately
      final selectedAnswer = _questions[questionIndex].options[optionIndex].text;
      // Update the service if this is a new answer
      if (_personalizationService.getAnswer(questionIndex) != selectedAnswer) {
        // Clear subsequent answers if we're going back
        _personalizationService.removeAnswersFrom(questionIndex);
        // Set the answer
        _personalizationService.setAnswer(questionIndex, selectedAnswer);
      }
    });
  }

  void _continue() {
    if (_selectedOptions[_currentQuestion] == null) return;

    if (_currentQuestion < _questions.length - 1) {
      // Move to next question
      setState(() {
        _currentQuestion++;
      });

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to home screen
      _completePersonalization();
    }
  }

  void _completePersonalization() async {
    if (!mounted || !context.mounted) return;
    
    // Try to ensure images are preloaded, but don't block navigation too long
    // If preloading is still in progress, navigate anyway (images will load in background)
    if (!_assetsPreloaded) {
      // Wait a short time for preloading, but don't block more than 300ms
      await Future.any([
        _preloadThemeSelectionAssets(),
        Future.delayed(const Duration(milliseconds: 300)), // Max wait
      ]);
    }
    
    if (!mounted || !context.mounted) return;
    
    try {
      // Use instant transition - no fade, just immediate replacement
      // This matches the smooth onboarding->personalization transition
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ThemeSelectionPage(
                initialBackgroundColor: _firstThemeBackgroundColor,
                initialDotColor: _firstThemeDotColor,
              ),
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
              // Progress Indicator
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildProgressIndicator(),
              ),

              // Question Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentQuestion = index;
                    });
                  },
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    return _buildQuestionPage(_questions[index], index);
                  },
                ),
              ),

              // Continue Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildContinueButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: index < 2 ? 4 : 0),
          width: _currentQuestion == index ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentQuestion >= index
                ? const Color(0xFF5E3A9E)
                : const Color(0xFFD4C5E8),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPage(PersonalizationQuestion question, int questionIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Question Text
          Text(
            question.question,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5E3A9E),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 40),
          // Options
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = question.options[index];
                final isSelected = _selectedOptions[questionIndex] == index;
                return _buildOptionCard(
                  option,
                  questionIndex,
                  index,
                  isSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    PersonalizationOption option,
    int questionIndex,
    int optionIndex,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => _onOptionSelected(questionIndex, optionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5E3A9E)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 15 : 5,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Radio Button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF5E3A9E)
                      : const Color(0xFFD4C5E8),
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF5E3A9E)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Emoji
            Text(
              option.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Text(
                option.text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: const Color(0xFF5E3A9E),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final isEnabled = _selectedOptions[_currentQuestion] != null;
    final isLastQuestion = _currentQuestion == _questions.length - 1;
    
    if (isLastQuestion) {
      // "Get Started" button with filled background
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isEnabled ? _continue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5E3A9E),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFD4C5E8),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'Get Started',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    } else {
      // "Continue" button as text-only
      return Center(
        child: GestureDetector(
          onTap: isEnabled ? _continue : null,
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.4,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Text(
                'Next',
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
}

class PersonalizationQuestion {
  final String question;
  final List<PersonalizationOption> options;

  PersonalizationQuestion({
    required this.question,
    required this.options,
  });
}

class PersonalizationOption {
  final String text;
  final String emoji;

  PersonalizationOption({
    required this.text,
    required this.emoji,
  });
}

