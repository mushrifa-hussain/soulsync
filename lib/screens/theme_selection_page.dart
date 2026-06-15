import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soulsync_dairyapp/services/theme_storage_service.dart';
import 'package:soulsync_dairyapp/services/app_storage_service.dart';

/// Theme Selection Page - Displays theme previews in a diary page style
/// 
/// To modify theme images:
/// 1. Add theme images to assets/themes/ folder
/// 2. Update the _themePaths list below with the new paths
/// 3. Update the _themeCount if you add/remove themes
class ThemeSelectionPage extends StatefulWidget {
  final Color? initialBackgroundColor;
  final Color? initialDotColor;
  final bool isFirstTime; // True if this is the first time selecting theme (during onboarding)
  
  const ThemeSelectionPage({
    super.key,
    this.initialBackgroundColor,
    this.initialDotColor,
    this.isFirstTime = false, // Default to false (not first time)
  });

  @override
  State<ThemeSelectionPage> createState() => _ThemeSelectionPageState();
}

class _ThemeSelectionPageState extends State<ThemeSelectionPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentIndex = 0;
  Color _currentBackgroundColor = const Color(0xFFFFE5F1);
  // Apply button color is always constant purple (SoulSync brand color)
  static const Color _constantApplyButtonColor = Color(0xFF7A49A5);
  Color _currentDotColor = const Color(0xFF6B4C93);
  
  // Cache for bottom colors of each theme
  final Map<int, Color> _bottomColorCache = {};
  final Map<int, Color> _backgroundColorCache = {};
  final Map<int, bool> _isDarkThemeCache = {}; // Cache for dark/light theme detection
  
  // Unified animation controller for app bar and body color sync
  late AnimationController _colorAnimationController;
  late Animation<Color?> _backgroundColorAnimation;
  
  // Button animation controllers
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  // Fixed image height for consistent alignment
  static const double _imageHeight = 280.0;

  // Theme paths - Update these when adding new themes
  // Add your theme images to assets/themes/ folder
  // Note: Update file extensions (.jpg/.png) and names to match your actual files
  static const List<String> _themePaths = [
    'assets/themes/theme_blossom_serenity.jpg',
    'assets/themes/theme_ocean_haze.jpg',
    'assets/themes/theme_midnight_whispers.jpg',
    'assets/themes/theme_rainbow_whispers.jpg',
    'assets/themes/theme_angel_feathers.jpg',
    'assets/themes/theme_butterfly_night.jpg',
    'assets/themes/theme_cozy_evening_glow.jpg',
    'assets/themes/theme_dreamy_dawn.jpg',
  ];

  static const int _themeCount = 9; // 8 image themes + 1 default theme

  @override
  void initState() {
    super.initState();
    
    // Initialize unified color animation controller for perfect sync
    _colorAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Optimized duration
      reverseDuration: const Duration(milliseconds: 600),
    );
    
    // Create color animation with fastOutSlowIn for smoother feel
    _backgroundColorAnimation = ColorTween(
      begin: const Color(0xFFFFE5F1),
      end: const Color(0xFFFFE5F1),
    ).animate(CurvedAnimation(
      parent: _colorAnimationController,
      curve: Curves.fastOutSlowIn, // Smoother curve
    ));
    
    // Set animation to end state initially (no animation on first load)
    _colorAnimationController.value = 1.0;
    
    // Initialize button animation
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Initialize colors synchronously - MUST be ready on first build
    // Index 0 is default theme - use default gradient colors
    _currentIndex = 0;
    // Default theme uses soft purple color from gradient
    final defaultColor = const Color(0xFFE8D5FF); // Soft purple from default gradient
    _currentBackgroundColor = defaultColor;
    _currentDotColor = defaultColor;
    
    // Cache default theme colors (index 0)
    _backgroundColorCache[0] = defaultColor;
    _bottomColorCache[0] = defaultColor;
    _isDarkThemeCache[0] = false; // Default theme is light
    
    // Update animation tween to match initial state immediately
    // Set both begin and end to the same color to prevent animation on first build
    _backgroundColorAnimation = ColorTween(
      begin: defaultColor,
      end: defaultColor,
    ).animate(CurvedAnimation(
      parent: _colorAnimationController,
      curve: Curves.fastOutSlowIn,
    ));
    
    // Ensure animation is at end state immediately (no animation on first render)
    _colorAnimationController.value = 1.0;
    
    // Add listener to page controller for real-time color updates during swipe
    _pageController.addListener(_onPageControllerChanged);
    
    // Start color extraction AFTER first frame (completely non-blocking)
    // Use a small delay to ensure UI renders first, then load colors in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add a small delay to ensure smooth navigation
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Preload remaining theme colors in background
          _preloadAllThemeColors();
        }
      });
    });
  }
  
  /// Preload colors for all themes to ensure smooth transitions
  Future<void> _preloadAllThemeColors() async {
    // Preload all themes in parallel for faster loading
    // Skip index 0 (default theme - no image to extract)
    final futures = <Future>[];
    for (int i = 1; i < _themeCount; i++) {
      // Skip if already cached
      if (!_backgroundColorCache.containsKey(i)) {
        futures.add(_extractColorFromImage(i));
      }
    }
    // Wait for all to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    // Colors are already set in initState, no need to update again
  }
  
  /// Handle page controller changes for real-time color updates
  void _onPageControllerChanged() {
    if (!_pageController.position.haveDimensions) return;
    
    final page = _pageController.page;
    if (page == null) return;
    
    final newIndex = page.round().clamp(0, _themeCount - 1);
    
    // Update colors immediately when page changes (including during swipe)
    // Only update if index actually changed to avoid unnecessary animations
    if (newIndex != _currentIndex && newIndex >= 0 && newIndex < _themeCount) {
      // Ensure colors are loaded for this index
      if (!_backgroundColorCache.containsKey(newIndex) || !_bottomColorCache.containsKey(newIndex)) {
        // Extract colors asynchronously, but update immediately with defaults
        _extractColorFromImage(newIndex);
      }
      // Update immediately with synchronized animation
      _updateColorsForIndex(newIndex);
    }
  }
  
  /// Update colors for a specific index (synchronized for app bar and body)
  void _updateColorsForIndex(int index) {
    if (index < 0 || index >= _themeCount) return;
    
    // Get cached colors or use defaults
    Color backgroundColor;
    Color dotColor;
    
    // Index 0 is default theme - use default gradient color
    if (index == 0) {
      backgroundColor = const Color(0xFFE8D5FF);
      dotColor = const Color(0xFFE8D5FF);
    } else if (_backgroundColorCache.containsKey(index) && _bottomColorCache.containsKey(index)) {
      backgroundColor = _backgroundColorCache[index]!;
      dotColor = _bottomColorCache[index]!;
    } else {
      // If not cached, use defaults immediately (extraction will happen in background)
      backgroundColor = const Color(0xFFFFE5F1);
      dotColor = const Color(0xFF6B4C93);
      // Trigger extraction in background (will update when complete)
      _extractColorFromImage(index);
    }
    
    // Update color animation with new target color for perfect sync
    final previousColor = _currentBackgroundColor;
    
    // For default theme (index 0), use specific colors
    final finalBackgroundColor = index == 0 
        ? const Color(0xFFE8D5FF) 
        : backgroundColor;
    final finalDotColor = index == 0 
        ? const Color(0xFFE8D5FF) 
        : dotColor;
    
    if (mounted) {
      // Update state first
      setState(() {
        _currentIndex = index;
        _currentBackgroundColor = finalBackgroundColor;
        _currentDotColor = finalDotColor;
      });
      
      // Update animation tween and animate
      _backgroundColorAnimation = ColorTween(
        begin: previousColor,
        end: finalBackgroundColor,
      ).animate(CurvedAnimation(
        parent: _colorAnimationController,
        curve: Curves.fastOutSlowIn,
      ));
      
      // Animate color change with unified controller (reset and forward for smooth transition)
      _colorAnimationController.reset();
      _colorAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageControllerChanged);
    _pageController.dispose();
    _colorAnimationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  /// Preload colors for adjacent themes for smoother transitions
  Future<void> _preloadAdjacentColors(int index) async {
    // Skip index 0 (default theme) for color extraction
    if (index > 1) {
      _extractColorFromImage(index - 1);
    }
    if (index < _themeCount - 1) {
      _extractColorFromImage(index + 1);
    }
  }

  /// Check if a color is dark (for text color selection)
  bool _isDarkColor(Color color) {
    // Calculate relative luminance
    final luminance = (0.299 * (color.r * 255.0) + 
                      0.587 * (color.g * 255.0) + 
                      0.114 * (color.b * 255.0)) / 255.0;
    return luminance < 0.5;
  }

  /// Extract dominant color from the bottom of the theme image
  Future<void> _extractColorFromImage(int index) async {
    // Skip index 0 (default theme - no image)
    if (index == 0 || index < 0 || index >= _themeCount) return;
    // Adjust index for theme paths (index 1+ maps to themePaths 0+)
    final themePathIndex = index - 1;
    if (themePathIndex < 0 || themePathIndex >= _themePaths.length) return;
    
    // Return cached color if available
    if (_backgroundColorCache.containsKey(index)) {
      if (index == _currentIndex && mounted) {
        setState(() {
          _currentBackgroundColor = _backgroundColorCache[index]!;
        });
      }
      return;
    }

    try {
      final imageProvider = AssetImage(_themePaths[themePathIndex]);
      final image = await _loadImageFromProvider(imageProvider);
      
      if (image == null) {
        debugPrint('Warning: Image is null for index $index');
        // Cache default colors for this index
        final defaultColor = const Color(0xFFFFE5F1);
        _bottomColorCache[index] = const Color(0xFF6B4C93);
        _backgroundColorCache[index] = defaultColor;
        _isDarkThemeCache[index] = false;
        
        // Update UI if this is the current theme
        if (index == _currentIndex && mounted) {
          _updateColorsForIndex(index);
        }
        return;
      }

      // Extract color from bottom portion of image
      // Use same region as Home Screen for all themes (including Theme 7) to match exactly
      final bottomRegion = Rect.fromLTWH(
        0,
        image.height * 0.60, // Same as Home Screen
        image.width.toDouble(),
        image.height * 0.40, // Same as Home Screen
      );

      final paletteGenerator = await PaletteGenerator.fromImage(
        image,
        region: bottomRegion,
        maximumColorCount: 10, // Further increased for better color detection
      );

      Color? dominantColor = paletteGenerator.dominantColor?.color;
      
      // Use exact same color extraction logic as Home Screen for all themes
      if (dominantColor == null && paletteGenerator.vibrantColor != null) {
        dominantColor = paletteGenerator.vibrantColor!.color;
      }
      
      if (dominantColor == null && paletteGenerator.mutedColor != null) {
        dominantColor = paletteGenerator.mutedColor!.color;
      }
      
      if (dominantColor == null && paletteGenerator.colors.isNotEmpty) {
        // Use the most saturated color from the palette (same as Home Screen)
        dominantColor = paletteGenerator.colors.first;
      }

      if (dominantColor != null) {
        final finalDominantColor = dominantColor; // Non-null local variable
        
        // For all themes (including Theme 7), use extracted colors
        // For card background, use the actual bottom color (not pastel) for perfect matching
        // Create a slightly lighter version only for page background
        // Use exact same conversion as Home Screen for all themes
        final pageBackgroundColor = Color.fromRGBO(
          ((finalDominantColor.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          ((finalDominantColor.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          ((finalDominantColor.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          1.0,
        );

        // Detect if theme is dark or light
        final isDark = _isDarkColor(finalDominantColor);

        // Cache the colors - use exact bottom color for card, pastel for page
        final cardBottomColor = finalDominantColor;
        
        _bottomColorCache[index] = cardBottomColor;
        _backgroundColorCache[index] = pageBackgroundColor; // For page background
        _isDarkThemeCache[index] = isDark;

        // Update UI if this is the current theme (colors are cached, update immediately)
        if (index == _currentIndex && mounted) {
          setState(() {
            // Use cached colors for all themes
            _currentBackgroundColor = _backgroundColorCache[index] ?? const Color(0xFFFFE5F1);
            _currentDotColor = _bottomColorCache[index] ?? const Color(0xFF6B4C93);
          });
        }
      } else {
        // If color extraction fails, set default colors but still cache them
        debugPrint('Warning: Color extraction failed for index $index, using defaults');
        final defaultColor = const Color(0xFFFFE5F1);
        _bottomColorCache[index] = const Color(0xFF6B4C93);
        _backgroundColorCache[index] = defaultColor;
        _isDarkThemeCache[index] = false;
        
        if (index == _currentIndex && mounted) {
          _updateColorsForIndex(index);
        }
      }
    } catch (e) {
      debugPrint('Error extracting color for index $index: $e');
      // Always cache default colors for this index, even on error
      final defaultColor = const Color(0xFFFFE5F1);
      _bottomColorCache[index] = const Color(0xFF6B4C93);
      _backgroundColorCache[index] = defaultColor;
      _isDarkThemeCache[index] = false;
      
      // Update UI if this is the current theme
      if (index == _currentIndex && mounted) {
        _updateColorsForIndex(index);
      }
    }
  }


  /// Load image from ImageProvider
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


  void _onPageChanged(int index) {
    // Ensure index is valid
    final validIndex = index.clamp(0, _themeCount - 1);
    
    // Ensure colors are loaded for this index
    if (!_backgroundColorCache.containsKey(validIndex)) {
      _extractColorFromImage(validIndex);
    }
    
    // Update colors immediately when page changes
    _updateColorsForIndex(validIndex);
    
    // Preload adjacent colors for smoother transitions
    _preloadAdjacentColors(validIndex);
  }

  Future<void> _onApplyPressed() async {
    // Button scale animation
    _buttonAnimationController.forward().then((_) {
      _buttonAnimationController.reverse();
    });
    
    // Index 0 is the default theme - clear theme path (same as "Later")
    if (_currentIndex == 0) {
      await ThemeStorageService.clearThemePath();
      // Save default bottom color
      await ThemeStorageService.saveBottomColor(const Color(0xFFDDEBFF));
    } else {
      // Other themes - save theme path (adjusted index -1)
      final selectedPath = _themePaths[_currentIndex - 1];
      await ThemeStorageService.saveThemePath(selectedPath);
      
      // Save the bottom color for this theme
      // For Theme 7 (Cozy Evening Glow), use hardcoded peachy-orange color to match Home Screen
      Color bottomColorToSave;
      if (_currentIndex == 7) {
        // Theme 7 uses hardcoded peachy-orange color
        bottomColorToSave = const Color(0xFFFFE5CC);
      } else {
        // For other themes, use cached color or extract it
        final bottomColor = _bottomColorCache[_currentIndex];
        if (bottomColor != null) {
          bottomColorToSave = bottomColor;
        } else {
          // If color not cached yet, extract it now
          await _extractColorFromImage(_currentIndex);
          final extractedColor = _bottomColorCache[_currentIndex];
          if (extractedColor != null) {
            bottomColorToSave = extractedColor;
          } else {
            // Fallback to default
            bottomColorToSave = const Color(0xFFDDEBFF);
          }
        }
      }
      await ThemeStorageService.saveBottomColor(bottomColorToSave);
    }
    
    // Mark theme as selected (onboarding complete)
    await AppStorageService.setThemeSelected();
    
    // Show success snackbar
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🌸'),
              const SizedBox(width: 8),
              Text(
                'Theme applied successfully',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: _constantApplyButtonColor.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Navigate based on authentication status
      // If user is already logged in, go back to home (clear stack to make Home root)
      // Otherwise, go to signup (first time setup)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && context.mounted) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // User is already logged in, go back to home and clear navigation stack
            // This ensures Home is the root and back button will exit app
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false, // Remove all previous routes
            );
          } else {
            // User not logged in, go to signup (first time setup)
            Navigator.of(context).pushReplacementNamed('/signup');
          }
        }
      });
    }
  }

  void _onLaterPressed() async {
    // Button scale animation
    _buttonAnimationController.forward().then((_) {
      _buttonAnimationController.reverse();
    });
    
    // Only set default theme if this is the first time (during onboarding)
    if (widget.isFirstTime) {
      // Clear theme path to use default gradient
      await ThemeStorageService.clearThemePath();
      // Save default bottom color
      await ThemeStorageService.saveBottomColor(const Color(0xFFDDEBFF));
      
      // Mark theme as selected (onboarding complete) - "Later" also counts as selection
      await AppStorageService.setThemeSelected();
      
      // Navigate based on authentication status
      // If user is already logged in, go back to home (clear stack to make Home root)
      // Otherwise, go to signup (first time setup)
      if (mounted && context.mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // User is already logged in, go back to home and clear navigation stack
          // This ensures Home is the root and back button will exit app
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false, // Remove all previous routes
          );
        } else {
          // User not logged in, go to signup (first time setup)
          Navigator.of(context).pushReplacementNamed('/signup');
        }
      }
    } else {
      // Not first time - just close without changing theme
      if (mounted && context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Get last three dates for diary preview
  List<DateTime> _getLastThreeDates() {
    final now = DateTime.now();
    return [
      now.subtract(const Duration(days: 2)),
      now.subtract(const Duration(days: 1)),
      now,
    ];
  }

  /// Get day name from weekday number
  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  /// Get month name from month number
  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    // Determine if current theme is dark for app bar text color
    final isDarkTheme = _isDarkThemeCache[_currentIndex] ?? false;
    final appBarTextColor = isDarkTheme ? Colors.white : const Color(0xFF6B4C93);
    
    // Use current background color immediately (no waiting for async)
    // Always use a valid color - default to soft purple if not set
    final displayBackgroundColor = _currentBackgroundColor;
    
    return Scaffold(
      // Set scaffold background immediately to prevent blank frame
      // Use a stable default color that matches the default theme
      backgroundColor: displayBackgroundColor,
      appBar: AppBar(
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          child: Text(
            'Choose Your Theme',
            style: GoogleFonts.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: appBarTextColor,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparent to blend with body
        elevation: 0,
        actions: const [], // Removed sound toggle
        flexibleSpace: AnimatedBuilder(
          animation: _colorAnimationController,
          builder: (context, child) {
            // Use animated color for perfect sync
            final animatedColor = _backgroundColorAnimation.value ?? _currentBackgroundColor;
            return Container(
              decoration: BoxDecoration(
                // For dark themes, use exact same color as body (no gradient, no alpha) to remove separation
                // For light themes, use subtle gradient
                color: isDarkTheme 
                    ? animatedColor // Exact match for dark themes
                    : null,
                gradient: isDarkTheme 
                    ? null 
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          animatedColor,
                          animatedColor.withValues(alpha: 0.95),
                        ],
                      ),
              ),
            );
          },
        ),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: Container(
        // Fully opaque container to prevent transparency during transition
        // Use stable default color immediately to prevent visual jumps
        color: displayBackgroundColor,
        child: AnimatedBuilder(
          animation: _colorAnimationController,
          builder: (context, child) {
            // Use animated color for perfect sync with app bar
            // Fallback to currentBackgroundColor immediately if animation not ready
            final animatedColor = _backgroundColorAnimation.value ?? displayBackgroundColor;
            return Container(
              key: const ValueKey('theme_body'), // Stable key for performance
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    animatedColor,
                    animatedColor.withValues(alpha: 0.95),
                    animatedColor.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Theme Preview PageView with cinematic transitions
                    Expanded(
                      child: RepaintBoundary(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemCount: _themeCount,
                          physics: const ClampingScrollPhysics(),
                          // Ensure smooth initial render
                          allowImplicitScrolling: false,
                          itemBuilder: (context, index) {
                            // Index 0 is the default theme (no image, gradient only)
                            if (index == 0) {
                              return _buildAnimatedThemeCard(null, index); // null indicates default theme
                            }
                            // Other themes use image paths (adjusted index -1)
                            return _buildAnimatedThemeCard(_themePaths[index - 1], index);
                          },
                        ),
                      ),
                    ),

                    // Page Indicator with theme-colored dots
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _themeCount,
                          (index) => _buildAnimatedDot(index),
                        ),
                      ),
                    ),

                    // Action Buttons - More compact and centered
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0), // Reduced vertical padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Later Button - Text-only style
                          _buildLaterButton(),
                          const SizedBox(width: 16),
                          // Apply Button - Reduced width
                          SizedBox(
                            width: 180,
                            child: _buildApplyButton(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build animated theme card with cinematic scale, fade, and blur effects
  Widget _buildAnimatedThemeCard(String? themePath, int index) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          double value = 0.0;
          // Check if page controller is ready and has dimensions
          final hasDimensions = _pageController.hasClients && _pageController.position.haveDimensions;
          if (hasDimensions) {
            final page = _pageController.page ?? index.toDouble();
            value = (1 - (page - index).abs()).clamp(0.0, 1.0);
            // Use easeInOut for smoother, more cinematic feel
            value = Curves.easeInOut.transform(value);
          } else {
            // If page controller not ready, show first card at full opacity
            // This prevents the "half-open" stutter on initial render
            value = (index == 0) ? 1.0 : 0.4;
          }

          // Scale: inactive cards at 0.9x, centered card at 1.05x
          final scale = 0.9 + (value * 0.15);
          
          // Opacity: inactive cards dimmed to 0.4, centered card at 1.0
          final opacity = 0.4 + (value * 0.6);
          
          // Blur: inactive cards slightly blurred
          final blur = (1 - value) * 3.0;
          
          // Check if this is the current centered card
          final isCurrent = _currentIndex == index;
          
          // For light themes, skip BackdropFilter when centered to prevent darkening
          final isLightTheme = !(_isDarkThemeCache[index] ?? false);
          // Only apply blur for inactive cards or dark themes (prevents dark line on light images)
          final shouldApplyBlur = blur > 0.1 && (!isLightTheme || !isCurrent);
          
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: shouldApplyBlur
                      ? BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                          child: _buildThemeCard(themePath, index, value),
                        )
                      : _buildThemeCard(themePath, index, value),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build theme card with fixed image height, perfect gradient blend, and diary preview
  Widget _buildThemeCard(String? themePath, int index, double animationValue) {
    final isCurrent = _currentIndex == index;
    final isDefaultTheme = themePath == null; // Index 0 is default theme
    
    // Default theme uses gradient colors
    if (isDefaultTheme) {
      return _buildDefaultThemeCard(index, animationValue);
    }
    
    // For Theme 7 (Cozy Evening Glow), use hardcoded peachy-orange colors to match Home Screen
    // Home screen uses peachy-orange gradient, not the extracted pinkish color
    final bottomColor = index == 7 
        ? const Color(0xFFFFE5CC) // Soft peachy-orange to match Home Screen gradient
        : (_bottomColorCache[index] ?? _currentBackgroundColor);
    final isDark = _isDarkThemeCache[index] ?? false;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    // Calculate border color - very soft, subtle border for gentle card definition
    // Use a neutral tone that works for both light and dark themes
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12) // Very soft white for dark themes
        : Colors.black.withValues(alpha: 0.08); // Very soft black for light themes
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
          width: 0.9, // Soft, subtle border width
        ),
        boxShadow: [
          // Very soft pastel shadow for subtle floating effect
          // Lighter shadows for light themes to prevent dark artifacts
          BoxShadow(
            color: isDark
                ? bottomColor.withValues(alpha: 0.15)
                : bottomColor.withValues(alpha: 0.08), // Much lighter for light themes
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          // Soft pastel glow for centered card - lighter for light themes
          if (isCurrent)
            BoxShadow(
              color: isDark
                  ? bottomColor.withValues(alpha: 0.3 * animationValue)
                  : bottomColor.withValues(alpha: 0.12 * animationValue), // Lighter for light themes
              blurRadius: 35,
              spreadRadius: 6,
              offset: const Offset(0, 8),
            ),
          if (isCurrent)
            BoxShadow(
              color: isDark
                  ? bottomColor.withValues(alpha: 0.2 * animationValue)
                  : bottomColor.withValues(alpha: 0.08 * animationValue), // Lighter for light themes
              blurRadius: 20,
              spreadRadius: 3,
              offset: const Offset(0, 4),
            ),
          // Removed black shadow to prevent dark line artifacts
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          // Use exact bottom color for card background to match perfectly
          color: bottomColor,
          child: Column(
            children: [
              // Theme Image at Top - Fixed height for consistent alignment
              SizedBox(
                height: _imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image with cover fit to fill the fixed height
                    // Use RepaintBoundary for performance optimization
                    RepaintBoundary(
                      child: Image.asset(
                        themePath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter, // Align to top to show full image
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFFFE5F1),
                                  const Color(0xFFE8D5FF),
                                  const Color(0xFFB8E6FF),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Color(0xFF8B7BA6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Ultra-smooth gradient fade for seamless blend - matches Home Screen exactly
                    // For light themes, use lighter gradient to prevent dark bands
                    // Theme 5 (Angel Feather) - start fade earlier (10-15% higher) with adjusted stops
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: (index == 7 || index == 4 || index == 5 || index == 8) ? 130.0 : 110.0, // Theme 4, 5, 7, and 8 use taller gradient (130) for smoother blending
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: index == 7 // Theme 7 - use extracted bottomColor to match Home Screen exactly
                                ? [
                                    // Theme 7: use extracted bottomColor (same as Home Screen) for perfect match
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.05),
                                    bottomColor.withValues(alpha: 0.15),
                                    bottomColor.withValues(alpha: 0.35),
                                    bottomColor.withValues(alpha: 0.65),
                                    bottomColor.withValues(alpha: 1.0),
                                  ]
                                : isDark
                                    ? [
                                        // Dark themes: use standard gradient
                                        Colors.transparent,
                                        bottomColor.withValues(alpha: 0.2),
                                        bottomColor.withValues(alpha: 0.5),
                                        bottomColor.withValues(alpha: 0.8),
                                        bottomColor.withValues(alpha: 0.95),
                                        bottomColor.withValues(alpha: 1.0), // Perfect match
                                      ]
                                    : [
                                        // Light themes: use very light tint to prevent dark bands (matches Home Screen)
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.05),
                                        bottomColor.withValues(alpha: 0.15),
                                        bottomColor.withValues(alpha: 0.35),
                                        bottomColor.withValues(alpha: 0.65),
                                        bottomColor.withValues(alpha: 1.0),
                                      ],
                            stops: (index == 7 || index == 4)
                                ? const [0.0, 0.0, 0.05, 0.30, 0.50, 1.0] // Theme 4 and 7: smoother blending
                                : (index == 5 || index == 8)
                                    ? const [0.0, 0.0, 0.02, 0.15, 0.30, 1.0] // Theme 5 and 8: start fade earlier
                                    : const [0.0, 0.10, 0.3, 0.70, 0.8, 1.0], // Standard stops for other themes
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Gradient continuation section - seamless blend (no gap)
              Container(
                height: 35,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bottomColor.withValues(alpha: 1.0),
                      bottomColor.withValues(alpha: 1.0), // Perfect match
                      bottomColor.withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
              
              // Diary Preview Section - perfectly matching background
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: bottomColor, // Exact match, no transparency
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Date cards
                      ..._getLastThreeDates().reversed.map((date) {
                        final dayName = _getDayName(date.weekday);
                        final dateStr = '${date.day} ${_getMonthName(date.month)}';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.65),
                              width: 1,
                            ),
                            // Soft shadow for depth
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                dayName,
                                style: GoogleFonts.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColor.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dateStr,
                                  style: GoogleFonts.quicksand(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: textColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      
                      // Placeholder lines for diary entries
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlaceholderLine(isDark, textColor, 0.4),
                            const SizedBox(height: 6),
                            _buildPlaceholderLine(isDark, textColor, 0.3),
                            const SizedBox(height: 6),
                            _buildPlaceholderLine(isDark, textColor, 0.5),
                          ],
                        ),
                      ),
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

  /// Build default theme card with gradient background (no image)
  Widget _buildDefaultThemeCard(int index, double animationValue) {
    final isCurrent = _currentIndex == index;
    final defaultColor = const Color(0xFFE8D5FF); // Soft purple from default gradient
    final isDark = false; // Default theme is light
    final textColor = Colors.black87;
    
    // Calculate border color - very soft, subtle border
    final borderColor = Colors.black.withValues(alpha: 0.08);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: defaultColor.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          if (isCurrent)
            BoxShadow(
              color: defaultColor.withValues(alpha: 0.12 * animationValue),
              blurRadius: 35,
              spreadRadius: 6,
              offset: const Offset(0, 8),
            ),
          if (isCurrent)
            BoxShadow(
              color: defaultColor.withValues(alpha: 0.08 * animationValue),
              blurRadius: 20,
              spreadRadius: 3,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          // Use full gradient background matching Home Screen exactly
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
          child: Column(
            children: [
              // Default gradient section at top (no image, just label)
              // Gradient flows naturally from parent Container
              SizedBox(
                height: _imageHeight,
                width: double.infinity,
                child: Center(
                  child: Text(
                    'Default',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C93),
                    ),
                  ),
                ),
              ),
              // Diary Preview Section - gradient continues naturally from parent
              Expanded(
                child: Container(
                  // No background - parent gradient flows through naturally
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Date cards
                      ..._getLastThreeDates().reversed.map((date) {
                        final dayName = _getDayName(date.weekday);
                        final dateStr = '${date.day} ${_getMonthName(date.month)}';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                dayName,
                                style: GoogleFonts.quicksand(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dateStr,
                                  style: GoogleFonts.quicksand(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: textColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlaceholderLine(isDark, textColor, 0.4),
                            const SizedBox(height: 6),
                            _buildPlaceholderLine(isDark, textColor, 0.3),
                            const SizedBox(height: 6),
                            _buildPlaceholderLine(isDark, textColor, 0.5),
                          ],
                        ),
                      ),
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

  /// Build placeholder line for diary entry preview
  Widget _buildPlaceholderLine(bool isDark, Color textColor, double width) {
    return Container(
      height: 3,
      width: MediaQuery.of(context).size.width * width * 0.3,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.2)
            : textColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Build animated dot indicator with theme color
  Widget _buildAnimatedDot(int index) {
    final isActive = _currentIndex == index;
    final dotColor = isActive 
        ? _currentDotColor 
        : const Color(0xFFD4C5E8);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }

  /// Build Later button with scale animation on tap - Text-only style
  Widget _buildLaterButton() {
    return AnimatedBuilder(
      animation: _buttonScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonScaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onLaterPressed,
              borderRadius: BorderRadius.circular(16),
              splashColor: const Color(0xFF6B4C93).withValues(alpha: 0.1),
              highlightColor: const Color(0xFF6B4C93).withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                child: Text(
                  'Later',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    // White text for dark themes, purple for light themes
                    color: (_isDarkThemeCache[_currentIndex] ?? false)
                        ? Colors.white
                        : const Color(0xFF6B4C93),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build Apply button with scale animation and color brighten
  Widget _buildApplyButton() {
    return AnimatedBuilder(
      animation: _buttonScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonScaleAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800), // Unified duration
            curve: Curves.easeInOut, // Unified curve
            height: 50, // Reduced height for more refined appearance
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _onApplyPressed,
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withValues(alpha: 0.4),
                highlightColor: Colors.white.withValues(alpha: 0.3),
                child: Container(
                  decoration: BoxDecoration(
                    // Always use constant purple color, not theme-adaptive
                    color: _constantApplyButtonColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _constantApplyButtonColor.withValues(alpha: 0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Apply',
                      style: GoogleFonts.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
