import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:soulsync_dairyapp/services/theme_storage_service.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/screens/theme_selection_page.dart';
import 'package:soulsync_dairyapp/screens/new_entry_screen.dart';
import 'package:soulsync_dairyapp/screens/calendar_screen.dart';
import 'package:soulsync_dairyapp/screens/profile_overview.dart';
import 'package:soulsync_dairyapp/screens/pin_setup_page.dart';
import 'package:soulsync_dairyapp/screens/lock_options_page.dart';
import 'package:soulsync_dairyapp/services/lock_service.dart';
import 'package:soulsync_dairyapp/screens/reminders_page.dart';
import 'package:soulsync_dairyapp/screens/todo_list_page.dart';
import 'package:soulsync_dairyapp/screens/settings_page.dart';
import 'package:soulsync_dairyapp/screens/privacy_policy_page.dart';
import 'package:soulsync_dairyapp/screens/help_center_page.dart';
import 'package:soulsync_dairyapp/screens/donate_page.dart';
import 'package:soulsync_dairyapp/services/profile_service.dart';
import 'package:soulsync_dairyapp/services/export_import_service.dart';
import 'package:soulsync_dairyapp/services/settings_service.dart';
import 'package:soulsync_dairyapp/widgets/mood_selection_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String? _themePath;
  Color? _themeBackgroundColor;
  Color? _themeBottomColor;
  bool _isLightTheme = true; // Default theme is light
  bool _isLoading = true;
  String? _deletingEntryId; // Track entry being deleted for fade-out animation
  String _sortOrder = 'latest'; // 'latest' or 'oldest'
  String _searchQuery = ''; // Search text
  bool _isSearchActive = false; // Whether search bar is visible
  TextEditingController? _searchController;
  
  // Profile data (for future use)
  String? _profilePhotoPath;
  String? _profilePhotoUrl;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _blinkController;
  late AnimationController _glowPulseController;
  late AnimationController _quoteController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _blinkAnimation;
  late Animation<double> _glowPulseAnimation;
  late Animation<double> _quoteFadeAnimation;
  
  // Motivational quotes
  final List<String> _motivationalQuotes = [
    '~ Every day is a fresh start 🌸',
    '~ You are stronger than you think 💪',
    '~ Small steps lead to big changes ✨',
    '~ Your journey matters 🌟',
    '~ Believe in yourself 💜',
    '~ Today is full of possibilities 🌈',
    '~ You are enough just as you are 🌷',
    '~ Progress, not perfection 🌱',
    '~ Your story is still being written 📖',
    '~ Embrace the journey 🌸',
    '~ You have the power to change 💫',
    '~ Every moment is a new beginning 🌅',
    '~ Trust the process 🌊',
    '~ You are capable of amazing things ⭐',
    '~ Growth happens one day at a time 🌱',
    '~ Your feelings are valid 💙',
    '~ Tomorrow is a new opportunity 🌄',
    '~ You are worthy of happiness 💖',
    '~ Keep moving forward 🚶',
    '~ Self-care is not selfish 🌸',
    '~ You are braver than you believe 💪',
    '~ Every day brings new hope 🌅',
    '~ Your potential is limitless ✨',
    '~ Take it one step at a time 🦶',
    '~ You are doing better than you think 🌟',
    '~ Healing takes time, be patient 💜',
    '~ You deserve peace and joy 🌈',
    '~ Your voice matters 🗣️',
    '~ Keep going, you\'ve got this 💪',
    '~ Every challenge makes you stronger 🌳',
    '~ You are loved and valued 💖',
    '~ Today is a gift, that\'s why it\'s called present 🎁',
    '~ You are exactly where you need to be 📍',
    '~ Trust yourself 🌸',
    '~ Your dreams are valid 🌙',
    '~ Be kind to yourself today 💜',
    '~ You are making progress, even if it\'s small 🌱',
    '~ Every sunrise is a new beginning 🌅',
    '~ You have the strength to overcome 💪',
    '~ Your journey is unique and beautiful 🌟',
    '~ Take a deep breath, you\'re doing great 🫁',
    '~ You are not alone in this 💙',
    '~ Every day you grow stronger 🌳',
    '~ You deserve all the good things 💖',
    '~ Keep shining your light ✨',
    '~ Your story matters 📖',
    '~ You are becoming who you\'re meant to be 🌸',
    '~ Trust the timing of your life ⏰',
    '~ You are resilient and strong 💪',
    '~ Every moment is a chance to start fresh 🌅',
  ];
  
  int _currentQuoteIndex = 0;
  
  // Constants
  static const double _imageHeight = 280.0;
  static const double _heroSize = 75.0;
  static const double _buttonSize = 60.0;
  static const double _plusButtonSize = 80.0;
  static const double _drawerWidth = 0.70;

  @override
  void initState() {
    super.initState();
    
    // Check authentication - signup is mandatory
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User not logged in - redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return;
    }
    
    // Initialize fade-in + slide-up animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    
    // Initialize floating animation for hero
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Initialize blinking animation (4 second cycle)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000), // 4 seconds total
    )..repeat();
    _blinkAnimation = TweenSequence<double>([
      // Eyes open: 3 seconds (75%)
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 75.0,
      ),
      // Eyes closing: 0.3 seconds (7.5%)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 7.5,
      ),
      // Eyes closed: 0.4 seconds (10%)
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 10.0,
      ),
      // Eyes opening: 0.3 seconds (7.5%)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 7.5,
      ),
    ]).animate(_blinkController);
    
    // Initialize glow pulse animation (6 seconds)
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat(reverse: true);
    _glowPulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowPulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Initialize quote animation controller
    // Total duration: 1 minute (60 seconds) + fade in/out time
    _quoteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 63000), // 1 min stay + 3 sec fade transitions
    );
    _quoteFadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 2.38, // Fade in: 1.5 seconds
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 95.24, // Stay visible: 60 seconds (1 minute)
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 2.38, // Fade out: 1.5 seconds
      ),
    ]).animate(_quoteController);
    
    // Start quote animation cycle
    _startQuoteCycle();
    
    _loadTheme();
    _loadSortPreference();
    _loadProfileData();
    
    // Load entries from provider (provider loads automatically in main.dart)
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    if (provider.entries.isEmpty && !provider.isLoading) {
      provider.loadEntries();
    }
    
    // Start fade-in animation
    _fadeController.forward();
  }
  
  /// Start quote animation cycle
  void _startQuoteCycle() {
    _quoteController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Move to next quote
        setState(() {
          _currentQuoteIndex = (_currentQuoteIndex + 1) % _motivationalQuotes.length;
        });
        // Restart animation
        _quoteController.reset();
        _quoteController.forward();
      }
    });
    // Start the first quote
    _quoteController.forward();
  }
  
  /// Build motivational quote widget
  Widget _buildQuoteWidget() {
    final isDarkTheme = !_isLightTheme;
    final textColor = isDarkTheme 
        ? Colors.white 
        : const Color(0xFF5E3A9E); // Purple for light themes
    
    return FadeTransition(
      opacity: _quoteFadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          _motivationalQuotes[_currentQuoteIndex],
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: textColor,
            letterSpacing: 0.5,
            height: 1.4,
            shadows: isDarkTheme
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  /// Load profile data for display
  Future<void> _loadProfileData() async {
    final isSignedIn = ProfileService.isSignedIn();
    if (isSignedIn) {
      final localPhotoPath = await ProfileService.getLocalPhotoPath();
      final photoUrl = ProfileService.getPhotoUrl();
      
      setState(() {
        _profilePhotoPath = localPhotoPath;
        _profilePhotoUrl = photoUrl;
      });
    } else {
      setState(() {
        _profilePhotoPath = null;
        _profilePhotoUrl = null;
        // Profile username cleared
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _blinkController.dispose();
    _glowPulseController.dispose();
    _quoteController.dispose();
    _searchController?.dispose();
    super.dispose();
  }

  /// Load sort preference from storage
  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSort = prefs.getString('diary_sort_order');
    if (savedSort != null && (savedSort == 'latest' || savedSort == 'oldest')) {
      setState(() {
        _sortOrder = savedSort;
      });
    }
  }

  /// Save sort preference to storage
  Future<void> _saveSortPreference(String sortOrder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('diary_sort_order', sortOrder);
  }


  /// Load theme from storage and extract colors
  Future<void> _loadTheme() async {
    setState(() {
      _isLoading = true;
    });

    final savedThemePath = await ThemeStorageService.getThemePath();
    
    if (savedThemePath != null && savedThemePath.isNotEmpty) {
      setState(() {
        _themePath = savedThemePath;
      });
      
      await _extractThemeColor(savedThemePath);
    } else {
      // Default theme - treat as light theme
      setState(() {
        _themePath = null;
        _themeBackgroundColor = null;
        _isLightTheme = true; // Default theme is light
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Extract color from theme image for background blend
  Future<void> _extractThemeColor(String themePath) async {
    try {
      debugPrint('🎨 Starting color extraction for: $themePath');
      final imageProvider = AssetImage(themePath);
      final image = await _loadImageFromProvider(imageProvider);
      
      if (image == null) {
        debugPrint('❌ Warning: Theme image is null for $themePath');
        return;
      }
      
      debugPrint('✅ Image loaded: ${image.width}x${image.height}');
      
      // Use same extraction region as preview for all themes (including Cozy Evening Glow)
      // This ensures consistent color matching with the preview
      // Ensure region is within image bounds and uses integer coordinates
      final startY = (image.height * 0.60).round();
      final regionHeight = (image.height * 0.40).round();
      final bottomRegion = Rect.fromLTWH(
        0,
        startY.toDouble(),
        image.width.toDouble(),
        regionHeight.toDouble(),
      );
      
      // Ensure region is valid
      if (bottomRegion.bottom > image.height || bottomRegion.right > image.width) {
        debugPrint('❌ Invalid region: $bottomRegion (image size: ${image.width}x${image.height})');
        // Fallback to full image
        final paletteGenerator = await PaletteGenerator.fromImage(
          image,
          maximumColorCount: 10,
        );
        return _processPalette(paletteGenerator, themePath);
      }
      
      debugPrint('🎨 Extracting from region: $bottomRegion');
      
      // Try with region first
      PaletteGenerator paletteGenerator;
      try {
        paletteGenerator = await PaletteGenerator.fromImage(
          image,
          region: bottomRegion,
          maximumColorCount: 10,
        );
        
        // If no colors found, try without region
        if (paletteGenerator.colors.isEmpty) {
          debugPrint('⚠️ No colors found in region, trying full image');
          paletteGenerator = await PaletteGenerator.fromImage(
            image,
            maximumColorCount: 10,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error with region extraction, trying full image: $e');
        paletteGenerator = await PaletteGenerator.fromImage(
          image,
          maximumColorCount: 10,
        );
      }
      
      return _processPalette(paletteGenerator, themePath);
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error extracting theme color: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// Process palette and set colors in state
  Future<void> _processPalette(PaletteGenerator paletteGenerator, String themePath) async {
    Color? dominantColor = paletteGenerator.dominantColor?.color;
    
    if (dominantColor == null && paletteGenerator.vibrantColor != null) {
      dominantColor = paletteGenerator.vibrantColor!.color;
      debugPrint('🎨 Using vibrant color');
    }
    
    if (dominantColor == null && paletteGenerator.mutedColor != null) {
      dominantColor = paletteGenerator.mutedColor!.color;
      debugPrint('🎨 Using muted color');
    }
    
    if (dominantColor == null && paletteGenerator.colors.isNotEmpty) {
      dominantColor = paletteGenerator.colors.first;
      debugPrint('🎨 Using first palette color');
    }
    
    if (dominantColor == null) {
      debugPrint('❌ No color extracted from palette. Colors available: ${paletteGenerator.colors.length}');
      debugPrint('❌ Dominant: ${paletteGenerator.dominantColor}, Vibrant: ${paletteGenerator.vibrantColor}, Muted: ${paletteGenerator.mutedColor}');
      return;
    }
    
    debugPrint('✅ Dominant color extracted: $dominantColor');
    
    // Use same lightening formula as preview for all themes (including Cozy Evening Glow)
    // This ensures the background color matches the preview exactly
    final pageBackgroundColor = Color.fromRGBO(
      ((dominantColor.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
      ((dominantColor.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
      ((dominantColor.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
      1.0,
    );
    
    debugPrint('✅ Background color calculated: $pageBackgroundColor');
    
    final luminance = (0.299 * (dominantColor.r * 255.0) +
                      0.587 * (dominantColor.g * 255.0) +
                      0.114 * (dominantColor.b * 255.0)) / 255.0;
    final isLight = luminance >= 0.5;
    
    if (mounted) {
      setState(() {
        _themeBackgroundColor = pageBackgroundColor;
        _themeBottomColor = dominantColor; // Store exact extracted color
        _isLightTheme = isLight;
      });
      debugPrint('✅ Colors set in state - Background: $pageBackgroundColor, Bottom: $dominantColor');
    } else {
      debugPrint('❌ Widget not mounted, cannot set state');
    }
  }

  /// Load diary entries from storage
  // Removed _loadEntries - now using provider

  /// Load image from provider
  Future<ui.Image?> _loadImageFromProvider(ImageProvider provider) async {
    try {
      final completer = Completer<ui.Image>();
      final imageStream = provider.resolve(const ImageConfiguration());
      ImageStreamListener? listener;
      
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        imageStream.removeListener(listener!);
      }, onError: (exception, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
        imageStream.removeListener(listener!);
      });
      
      imageStream.addListener(listener);
      
      // Add timeout to prevent hanging
      final image = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          imageStream.removeListener(listener!);
          throw TimeoutException('Image loading timed out');
        },
      );
      
      return image;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading image: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE5F1),
                Color(0xFFE8D5FF),
                Color(0xFFB8E6FF),
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF5E3A9E),
            ),
          ),
        ),
      );
    }

    // Determine system UI style based on theme
    final systemIconBrightness = _isLightTheme ? Brightness.dark : Brightness.light;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Exit app when back button is pressed on Home screen
        SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: systemIconBrightness,
          statusBarBrightness: systemIconBrightness == Brightness.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: systemIconBrightness,
        ),
        child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        extendBodyBehindAppBar: true,
        drawerScrimColor: Colors.black.withValues(alpha: 0.12),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0),
              child: _GlassButton(
                size: 40.0,
                isLightTheme: _isLightTheme,
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Icon(
                  Icons.menu_rounded,
                  color: _isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          actions: [
            // Search icon
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 8.0),
              child: _GlassButton(
                size: 40.0,
                isLightTheme: _isLightTheme,
                onTap: () {
                  setState(() {
                    _isSearchActive = !_isSearchActive;
                    if (!_isSearchActive) {
                      _searchQuery = '';
                      _searchController?.clear();
                    } else {
                      // Initialize controller when search is activated
                      _searchController ??= TextEditingController(text: _searchQuery);
                    }
                  });
                },
                child: Icon(
                  _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                  color: _isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white,
                  size: 22,
                ),
              ),
            ),
            // Sort menu
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 8.0),
              child: _GlassButton(
                size: 40.0,
                isLightTheme: _isLightTheme,
                onTap: () {
                  // Show sort menu
                  showMenu<String>(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      MediaQuery.of(context).size.width - 200,
                      80,
                      16,
                      MediaQuery.of(context).size.height,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: _isLightTheme
                        ? const Color(0xFFF8F4FF)
                        : Colors.black.withValues(alpha: 0.85),
                    elevation: 8,
                    items: [
                      PopupMenuItem<String>(
                        value: 'latest',
                        child: Row(
                          children: [
                            if (_sortOrder == 'latest')
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: Color(0xFF5E3A9E),
                              )
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Latest',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'oldest',
                        child: Row(
                          children: [
                            if (_sortOrder == 'oldest')
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: Color(0xFF5E3A9E),
                              )
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Oldest',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).then((value) {
                    if (value != null) {
                      setState(() {
                        _sortOrder = value;
                      });
                      _saveSortPreference(value);
                    }
                  });
                },
                child: Icon(
                  Icons.more_vert_rounded,
                  color: _isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        drawer: _buildDreamyDrawer(),
        body: _isSearchActive ? _buildSearchPage() : Stack(
          fit: StackFit.expand,
          children: [
            // [0] Scrollable content (background image + entries)
            _buildScrollableContent(),
            // [1] Floating controls at bottom (fixed)
            _buildFloatingControls(),
            // [2] Duplicate AI face above profile icon (fixed)
            _buildProfileAIFace(),
          ],
        ),
      ),
      ),
    );
  }

  /// Build scrollable content (background image + entries)
  Widget _buildScrollableContent() {
    return Consumer<DiaryEntriesProvider>(
      builder: (context, provider, child) {
        final isDefaultTheme = _themePath == null;
        final isTheme6 = _themePath?.contains('theme_cozy_evening_glow') ?? false;
        // For theme 6, use lighter background color (same as preview) for soft pastel look
        // For other themes, use bottom color to match preview
        final bottomColor = isDefaultTheme
            ? const Color(0xFFB8E6FF) // Default gradient's bottom color (sky blue)
            : isTheme6
                ? (_themeBackgroundColor ?? const Color(0xFFE8D5FF)) // Theme 6: use lighter background color (matches preview)
                : (_themeBottomColor ?? _themeBackgroundColor ?? const Color(0xFFE8D5FF));
        
        final entries = provider.entries;
        
        return Container(
          // For default theme, use full gradient background matching preview exactly
          // For other themes, use bottom color to match preview
          decoration: isDefaultTheme
              ? const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFE5F1), // Soft pink
                      Color(0xFFE8D5FF), // Soft purple
                      Color(0xFFB8E6FF), // Sky blue
                    ],
                  ),
                )
              : BoxDecoration(
                  color: bottomColor,
                ),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(), // Prevent bouncing/stretching of background image
            slivers: [
              // Background image section - only for non-default themes
              // Default theme: add spacer to match other themes' image height for consistent entry positioning
              if (!isDefaultTheme)
                SliverToBoxAdapter(
                  child: _buildScrollableBackgroundImage(),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _imageHeight, // Match the image height used in other themes
                  ),
                ),
              // Content section (empty state or entries)
              if (entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyStateContent(),
                )
              else ...[
                _buildEntriesList(provider),
                // Fill remaining space with background to prevent black gap
                SliverFillRemaining(
                  hasScrollBody: false,
                  fillOverscroll: true,
                  child: isDefaultTheme
                      ? Container(
                          // Default theme: gradient continues naturally (no background needed)
                        )
                      : Container(
                          color: bottomColor, // Other themes: use bottom color
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build scrollable background image
  Widget _buildScrollableBackgroundImage() {
    if (_themePath != null) {
      return _buildScrollableThemeImage();
    } else {
      return _buildScrollableDefaultGradient();
    }
  }

  /// Build scrollable theme image background
  Widget _buildScrollableThemeImage() {
    // Determine theme index for matching gradient stops with preview
    // Theme paths: 0=default, 1-8=image themes
    // Index 4=angel_feathers, 5=butterfly_night, 7=cozy_evening_glow, 8=dreamy_dawn
    final isTheme4 = _themePath?.contains('theme_angel_feathers') ?? false;
    final isTheme6 = _themePath?.contains('theme_cozy_evening_glow') ?? false;
    final isTheme8 = _themePath?.contains('theme_dreamy_dawn') ?? false;
    
    // Debug: Print theme path and detection
    if (isTheme6) {
      debugPrint('🎨 Cozy Evening Glow detected! Theme path: $_themePath');
      debugPrint('🎨 Background color: $_themeBackgroundColor');
      debugPrint('🎨 Bottom color: $_themeBottomColor');
    }
    
    // For theme 6 (Cozy Evening Glow), use lighter background color (same as preview)
    // Preview uses _backgroundColorCache which is the lighter version - match that exactly
    // For other themes, use raw extracted bottom color
    final bottomColor = isTheme6
        ? (_themeBackgroundColor ?? const Color(0xFFFFE5F1)) // Theme 6: use lighter background color (matches preview)
        : (_themeBottomColor ?? _themeBackgroundColor ?? const Color(0xFFFFE5F1));
    
    // Use ClipRect to prevent image from stretching beyond its bounds
    return ClipRect(
      child: SizedBox(
        height: _imageHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _themePath!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return _buildScrollableDefaultGradient();
              },
            ),
            // Motivational quote - positioned a bit above the bottom
            Positioned(
              bottom: 50, // Positioned above the gradient overlay
              left: 0,
              right: 0,
              child: _buildQuoteWidget(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                // Match preview heights exactly - Cozy Evening Glow uses 130px like preview
                height: (isTheme4 || isTheme6 || isTheme8) ? 130.0 : 110.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isTheme6
                        ? [
                            // Cozy Evening Glow: match preview EXACTLY - same gradient structure
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.05),
                            bottomColor.withValues(alpha: 0.15),
                            bottomColor.withValues(alpha: 0.35),
                            bottomColor.withValues(alpha: 0.65),
                            bottomColor.withValues(alpha: 1.0),
                          ]
                        : _isLightTheme
                            ? [
                                // Light themes: use very light tint to prevent dark bands
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.05),
                                bottomColor.withValues(alpha: 0.15),
                                bottomColor.withValues(alpha: 0.35),
                                bottomColor.withValues(alpha: 0.65),
                                bottomColor.withValues(alpha: 1.0),
                              ]
                            : [
                                // Dark themes: use standard gradient
                                Colors.transparent,
                                bottomColor.withValues(alpha: 0.2),
                                bottomColor.withValues(alpha: 0.5),
                                bottomColor.withValues(alpha: 0.8),
                                bottomColor.withValues(alpha: 0.95),
                                bottomColor.withValues(alpha: 1.0),
                              ],
                    // Match preview stops EXACTLY for Cozy Evening Glow
                    stops: (isTheme4 || isTheme6)
                        ? const [0.0, 0.0, 0.05, 0.30, 0.50, 1.0] // Theme 4 and 6: smoother blending (matches preview exactly)
                        : isTheme8
                            ? const [0.0, 0.0, 0.02, 0.15, 0.30, 1.0] // Theme 8: start fade earlier
                            : const [0.0, 0.10, 0.3, 0.70, 0.8, 1.0], // Standard stops for other themes
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build scrollable default gradient background
  Widget _buildScrollableDefaultGradient() {
    return ClipRect(
      child: Container(
        height: _imageHeight,
        width: double.infinity,
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
        child: Stack(
          children: [
            // Motivational quote - positioned a bit above the bottom
            Positioned(
              bottom: 50, // Positioned above the bottom
              left: 0,
              right: 0,
              child: _buildQuoteWidget(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state content (centered)
  Widget _buildEmptyStateContent() {
    final isDefaultTheme = _themePath == null;
    final isTheme6 = _themePath?.contains('theme_cozy_evening_glow') ?? false;
    // For theme 6, use lighter background color (same as preview) for soft pastel look
    // For other themes, use bottom color to match preview
    final bottomColor = isDefaultTheme
        ? const Color(0xFFB8E6FF) // Default gradient's bottom color (sky blue)
        : isTheme6
            ? (_themeBackgroundColor ?? const Color(0xFFE8D5FF)) // Theme 6: use lighter background color (matches preview)
            : (_themeBottomColor ?? _themeBackgroundColor ?? const Color(0xFFE8D5FF));
    
    return Container(
      // For default theme, no background (gradient flows through from parent)
      // For other themes, use bottom color to match preview
      color: isDefaultTheme ? null : bottomColor,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating pen icon
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: _buildPenIcon(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Title text
                Text(
                  'Cherish every moment.',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.9)
                        : Colors.white,
                    letterSpacing: 0.2,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Subtitle text
                Text(
                  'Your diary is waiting for your first memory 🌷',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get filtered entries based on search query
  List<DiaryEntry> _getFilteredEntries(DiaryEntriesProvider provider) {
    final entries = provider.entries;
    if (_searchQuery.isEmpty) {
      return entries;
    }
    final query = _searchQuery.toLowerCase();
    return entries.where((entry) {
      return entry.title.toLowerCase().contains(query);
    }).toList();
  }

  /// Build search page overlay
  Widget _buildSearchPage() {
    final isDefaultTheme = _themePath == null;
    final isTheme6 = _themePath?.contains('theme_cozy_evening_glow') ?? false;
    final bottomColor = isDefaultTheme
        ? const Color(0xFFB8E6FF)
        : isTheme6
            ? (_themeBackgroundColor ?? const Color(0xFFE8D5FF))
            : (_themeBottomColor ?? _themeBackgroundColor ?? const Color(0xFFE8D5FF));
    
    // Only get filtered entries when there's a search query
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    final filteredEntries = _searchQuery.isNotEmpty ? _getFilteredEntries(provider) : <DiaryEntry>[];
    // Sort filtered entries
    final sortedEntries = List<DiaryEntry>.from(filteredEntries);
    if (_sortOrder == 'latest') {
      sortedEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      sortedEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    
    return Container(
      decoration: isDefaultTheme
          ? const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE5F1),
                  Color(0xFFE8D5FF),
                  Color(0xFFB8E6FF),
                ],
              ),
            )
          : BoxDecoration(
              color: bottomColor,
            ),
      child: SafeArea(
        child: Column(
          children: [
            // Search bar at top
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isLightTheme
                    ? const Color(0xFFF8F4FF)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isLightTheme ? 0.08 : 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: _isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      controller: _searchController ??= TextEditingController(text: _searchQuery),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by title...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          color: _isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      onSubmitted: (value) {
                        // Search is handled by onChanged
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController?.clear();
                        });
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: _isLightTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            // Search results list (only show when there's a search query)
            if (_searchQuery.isNotEmpty)
              Expanded(
                child: sortedEntries.isEmpty
                    ? Center(
                        child: Text(
                          'No entries found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: _isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sortedEntries.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildEntryCard(sortedEntries[index]),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  /// Group entries by year
  Map<int, List<DiaryEntry>> _groupEntriesByYear(DiaryEntriesProvider provider) {
    // Use provider's built-in grouping method
    return provider.groupEntriesByYear(sortOrder: _sortOrder);
  }


  /// Build entries list as Sliver with year grouping
  Widget _buildEntriesList(DiaryEntriesProvider provider) {
    final isDefaultTheme = _themePath == null;
    final isTheme6 = _themePath?.contains('theme_cozy_evening_glow') ?? false;
    // For theme 6, use lighter background color (same as preview) for soft pastel look
    // For other themes, use bottom color to match preview
    final bottomColor = isDefaultTheme
        ? const Color(0xFFB8E6FF) // Default gradient's bottom color (sky blue)
        : isTheme6
            ? (_themeBackgroundColor ?? const Color(0xFFE8D5FF)) // Theme 6: use lighter background color (matches preview)
            : (_themeBottomColor ?? _themeBackgroundColor ?? const Color(0xFFE8D5FF));
    
    // For default theme, use transparent so gradient flows through (matching preview)
    // For other themes, use bottom color to match preview
    final containerColor = isDefaultTheme ? Colors.transparent : bottomColor;
    
    final groupedEntries = _groupEntriesByYear(provider);
    // Sort years: Latest = descending (newest first), Oldest = ascending (oldest first)
    final years = groupedEntries.keys.toList()
      ..sort((a, b) => _sortOrder == 'latest' ? b.compareTo(a) : a.compareTo(b));
    
    if (years.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    // Build list of items (year headers + entries)
    final List<Widget> items = [];
    int itemIndex = 0;
    
    for (int yearIndex = 0; yearIndex < years.length; yearIndex++) {
      final year = years[yearIndex];
      final entriesForYear = groupedEntries[year]!;
      
      // Add year header
      items.add(
        Container(
          color: containerColor,
          padding: EdgeInsets.only(
            left: 20,
            top: yearIndex == 0 ? 20 : 20, // 20px spacing between year sections
            bottom: 12,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 200 + (yearIndex * 50)),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: Text(
                    year.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isLightTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      
      // Add entries for this year
      for (int entryIndex = 0; entryIndex < entriesForYear.length; entryIndex++) {
        final entry = entriesForYear[entryIndex];
        final isLastEntry = (yearIndex == years.length - 1) && 
                            (entryIndex == entriesForYear.length - 1);
        
        final isDeleting = _deletingEntryId == entry.id;
        items.add(
          // Container with background color to prevent black flash
          Container(
            color: containerColor,
            child: AnimatedOpacity(
              opacity: isDeleting ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: isDeleting ? 0.96 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Container(
                  color: containerColor,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 0,
                    bottom: isLastEntry ? 140 : 0, // Extra padding at bottom for floating buttons
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + (itemIndex * 30)),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: _buildEntryCard(entry),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        itemIndex++;
      }
    }
    
    return SliverPadding(
      padding: EdgeInsets.zero,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => items[index],
          childCount: items.length,
        ),
      ),
    );
  }



  /// Format date for display (day and month only, e.g., "11 Nov")
  String _formatDateForDisplay(DateTime date) {
    return DateFormat('d MMM').format(date);
  }

  /// Build entry card
  Widget _buildEntryCard(DiaryEntry entry) {
    final cardColor = _themeBottomColor != null
        ? Color.fromRGBO(
            ((_themeBottomColor!.r * 255.0) * 0.9 + 255 * 0.1).round().clamp(0, 255),
            ((_themeBottomColor!.g * 255.0) * 0.9 + 255 * 0.1).round().clamp(0, 255),
            ((_themeBottomColor!.b * 255.0) * 0.9 + 255 * 0.1).round().clamp(0, 255),
            1.0,
          )
        : const Color(0xFFE8D5FF).withValues(alpha: 0.9);

    return GestureDetector(
      onTap: () async {
        // Navigate to entry detail/edit screen
        final result = await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => NewEntryScreen(
              themeBottomColor: _themeBottomColor,
              isLightTheme: _isLightTheme,
              existingEntry: entry,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        
        // If entry was deleted, handle undo
        if (result is DiaryEntry) {
          _showUndoSnackbar(result);
        } else if (result == true) {
          // Entry was saved/updated - provider will automatically update
          // No need to reload manually
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isLightTheme
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isLightTheme ? 0.06 : 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date and mood row (mood on top-right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDateForDisplay(entry.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: _isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                entry.mood,
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Full title
          Text(
            entry.title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
          ),
          if (entry.content.isNotEmpty) ...[
            const SizedBox(height: 5),
            // Content (1-2 lines, trimmed if long)
            Text(
              entry.content,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.8),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      ),
    );
  }
  
  /// Show undo snackbar after deletion
  void _showUndoSnackbar(DiaryEntry deletedEntry) {
    // Animate fade-out
    setState(() {
      _deletingEntryId = deletedEntry.id;
    });
    
    // Wait for fade-out animation - provider will automatically update
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _deletingEntryId = null;
        });
      }
    });
    
    // Show undo snackbar with auto-dismiss after 4 seconds
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🗑 '),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Entry deleted. Undo?',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF9169DC).withValues(alpha: 0.85),
        duration: const Duration(seconds: 4), // Auto-dismiss after 4 seconds
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom + 100,
          left: 20,
          right: 20,
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () async {
            // Restore the deleted entry
            // Restore entry via provider
            final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
            await provider.saveEntry(deletedEntry);
          },
        ),
      ),
    );
  }

  /// Build minimal pen icon (center)
  Widget _buildPenIcon() {
    return Icon(
      Icons.edit_rounded,
      size: 34,
      color: _isLightTheme
          ? const Color(0xFF5E3A9E) // Soft purple for light themes
          : Colors.white, // White for dark themes
    );
  }

  /// Build animated dreamy face with blinking animation
  Widget _buildHeroIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_blinkAnimation, _glowPulseAnimation]),
      builder: (context, child) {
        final closedOpacity = _blinkAnimation.value;
        final openOpacity = 1.0 - closedOpacity;
        final glowIntensity = _glowPulseAnimation.value;
        
        return Container(
          width: _heroSize,
          height: _heroSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0x80CBB7F5).withValues(alpha: glowIntensity * 0.7),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Open eyes (base layer)
                Opacity(
                  opacity: openOpacity,
                  child: Image.asset(
                    'assets/images/ai_face_open.jpg',
                    width: _heroSize,
                    height: _heroSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: _heroSize,
                        height: _heroSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE8D5FF),
                        ),
                        child: const Icon(
                          Icons.face_outlined,
                          size: 40,
                          color: Color(0xFF5E3A9E),
                        ),
                      );
                    },
                  ),
                ),
                // Closed eyes (blink layer)
                Opacity(
                  opacity: closedOpacity,
                  child: Image.asset(
                    'assets/images/ai_face_closed.jpg',
                    width: _heroSize,
                    height: _heroSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: _heroSize,
                        height: _heroSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE8D5FF),
                        ),
                        child: const Icon(
                          Icons.face_outlined,
                          size: 40,
                          color: Color(0xFF5E3A9E),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build floating controls at bottom
  Widget _buildFloatingControls() {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    return Positioned(
      bottom: bottomPadding + 18,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Calendar button
            _GlassButton(
              size: _buttonSize,
              isLightTheme: _isLightTheme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarScreen()),
                );
              },
              child: Icon(
                Icons.calendar_today_outlined,
                size: 24,
                color: _isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
            // Center: Plus button (primary action) - larger with glow
            _PlusButton(
              size: _plusButtonSize,
              isLightTheme: _isLightTheme,
              onTap: () async {
                // Check if mood selection should be skipped
                final skipMoodSelection = await SettingsService.getSkipMoodSelection();
                String? selectedMood;
                
                // Show mood selection dialog if not skipped
                if (!skipMoodSelection) {
                  if (!mounted) return;
                  // Calculate background color to match the entry screen
                  Color? dialogBackgroundColor;
                  if (_themeBottomColor != null) {
                    final color = _themeBottomColor!;
                    dialogBackgroundColor = Color.fromRGBO(
                      ((color.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
                      ((color.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
                      ((color.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
                      1.0,
                    );
                  } else {
                    dialogBackgroundColor = const Color(0xFFE8D5FF);
                  }
                  selectedMood = await MoodSelectionDialog.show(context, backgroundColor: dialogBackgroundColor);
                  // If user cancelled mood selection, don't proceed
                  if (selectedMood == null || !mounted) return;
                }
                
                // Navigate to entry screen with selected mood
                if (!mounted) return;
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => NewEntryScreen(
                      themeBottomColor: _themeBottomColor,
                      isLightTheme: _isLightTheme,
                      initialMood: selectedMood, // Pass selected mood
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeOutCubic;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                ).then((result) {
                  // Reload entries after returning
                  if (result == true || result is DiaryEntry) {
                    // Provider will automatically update
                  }
                });
              },
            ),
            // Right: Profile button (always show icon, never photo)
            _GlassButton(
              size: _buttonSize,
              isLightTheme: _isLightTheme,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileOverviewPage()),
                );
                _loadProfileData(); // Reload profile after returning
              },
              child: Icon(
                Icons.person_outline_rounded,
                size: 24,
                color: _isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build duplicate AI face above profile icon
  Widget _buildProfileAIFace() {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    // Calculate position: above profile button (button height + 32px spacing + half face size for centering)
    final bottomPosition = bottomPadding + 18 + _buttonSize + 32;
    // Align horizontally with profile button center (24px padding from right + button center)
    final rightPosition = 24.0 + _buttonSize / 2 - _heroSize / 2;
    
    return Positioned(
      bottom: bottomPosition,
      right: rightPosition,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/ai-chat');
        },
        child: AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: _buildHeroIcon(),
            );
          },
        ),
      ),
    );
  }

  /// Build dreamy drawer menu
  Widget _buildDreamyDrawer() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Drawer(
      width: screenWidth * _drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with transparent background
                  Container(
                    height: 160,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App logo in circular container (transparent, filled)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE8D5FF).withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.jpg',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isLightTheme
                                        ? const Color(0xFFE8D5FF)
                                        : Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: Icon(
                                    Icons.book_outlined,
                                    color: _isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                        : Colors.white,
                                    size: 90,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 30),
                        // SoulSync text
                        _buildSoulSyncText(
                          fontSize: 30,
                          isLightTheme: _isLightTheme,
                        ),
                      ],
                    ),
                  ),
                  // Menu items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      children: [
                        // Top section items (grouped together)
                        _buildDrawerItem(
                          icon: Icons.palette_outlined,
                          title: 'Theme',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            // Navigate with smooth transition
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    const ThemeSelectionPage(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  // Smooth fade and slide transition
                                  const begin = Offset(0.0, 0.05); // Slight upward slide
                                  const end = Offset.zero;
                                  const curve = Curves.easeOutCubic;
                                  
                                  var slideTween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  var fadeTween = Tween(begin: 0.0, end: 1.0)
                                      .chain(CurveTween(curve: curve));
                                  
                                  return SlideTransition(
                                    position: animation.drive(slideTween),
                                    child: FadeTransition(
                                      opacity: animation.drive(fadeTween),
                                      child: child,
                                    ),
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                                reverseTransitionDuration: const Duration(milliseconds: 300),
                              ),
                            ).then((_) => _loadTheme());
                            // Precache theme images in background (non-blocking)
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
                            // Precache images in background without blocking (errors are ignored)
                            Future.wait(themePaths.map((path) => precacheImage(AssetImage(path), context).catchError((e) {
                              debugPrint('Error precaching theme image $path: $e');
                            })));
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.lock_outline,
                          title: 'Lock',
                          isLightTheme: _isLightTheme,
                          onTap: () async {
                            Navigator.pop(context);
                            if (!mounted) return;
                            final hasPin = await LockService.hasPin();
                            if (!mounted) return;
                            if (hasPin) {
                              // PIN exists, show options
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LockOptionsPage(),
                                ),
                              );
                            } else {
                              // No PIN, setup new PIN
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PinSetupPage(),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.notifications_outlined,
                          title: 'Reminders',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RemindersPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.checklist_rounded,
                          title: 'To-Do List',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TodoListPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.cloud_upload_outlined,
                          title: 'Backup',
                          isLightTheme: _isLightTheme,
                          onTap: () async {
                            Navigator.pop(context);
                            if (!mounted) return;
                            final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
                            try {
                              await provider.backupNow();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Backup completed successfully', style: GoogleFonts.poppins()),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Backup failed: ${e.toString()}', style: GoogleFonts.poppins()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.import_export_outlined,
                          title: 'Import & Export',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            _showExportImportDialog(context);
                          },
                        ),
                        // Divider line (80% width - 10% margin on each side)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0.1),
                          child: Center(
                            child: Container(
                              width: double.infinity,
                              margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.1),
                              height: 1,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    width: 0.5,
                                    color: _isLightTheme
                                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom section items (grouped together)
                        _buildDrawerItem(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PrivacyPolicyPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.star_outline,
                          title: 'Rate Us',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Rate Us coming soon!', style: GoogleFonts.poppins()),
                                backgroundColor: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.help_outline,
                          title: 'Help Center',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HelpCenterPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.favorite_outline,
                          title: 'Donate',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DonatePage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        _buildDrawerItem(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          isLightTheme: _isLightTheme,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsPage(),
                              ),
                            );
                          },
                        ),
                      ],
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

  /// Build drawer menu item (delegates to animated widget)
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isLightTheme,
    required VoidCallback onTap,
    bool useAIIcon = false,
  }) {
    return _DrawerItemWidget(
      icon: icon,
      title: title,
      isLightTheme: isLightTheme,
      onTap: onTap,
      useAIIcon: useAIIcon,
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

  /// Show export/import dialog
  Future<void> _showExportImportDialog(BuildContext context) async {
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

    if (!mounted) return;
    if (result == 'export') {
      await _handleExport(context);
    } else if (result == 'import') {
      await _handleImport(context);
    }
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
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
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
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
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${e.toString()}',
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

  Future<void> _handleImport(BuildContext context) async {
    try {
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
      
      if (!mounted) return;
      // Reload entries in provider
      final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
      await provider.loadEntries();
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
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

/// Reusable glassmorphism button widget
class _GlassButton extends StatefulWidget {
  final double size;
  final VoidCallback onTap;
  final Widget child;
  final bool isLightTheme;

  const _GlassButton({
    required this.size,
    required this.onTap,
    required this.child,
    required this.isLightTheme,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(widget.size / 2),
                  splashColor: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
                  highlightColor: const Color(0xFF5E3A9E).withValues(alpha: 0.05),
                  child: Center(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Drawer menu item with hover/tap animation
class _DrawerItemWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool _isLightTheme;
  final bool useAIIcon;

  const _DrawerItemWidget({
    required this.icon,
    required this.title,
    required this.onTap,
    required bool isLightTheme,
    this.useAIIcon = false,
  }) : _isLightTheme = isLightTheme;

  @override
  State<_DrawerItemWidget> createState() => _DrawerItemWidgetState();
}

class _DrawerItemWidgetState extends State<_DrawerItemWidget> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _scaleController.isAnimating
                ? [
                    BoxShadow(
                      color: widget._isLightTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: widget.useAIIcon
                ? Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B4C93).withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/ai_face_mouth.jpg',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE8D5FF).withValues(alpha: 0.2),
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget._isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white,
                              size: 18,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8D5FF).withValues(alpha: 0.2),
              ),
              child: Icon(
                widget.icon,
                color: widget._isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white,
                size: 18,
              ),
            ),
            title: Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: widget._isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Special plus button with glow effect
class _PlusButton extends StatefulWidget {
  final double size;
  final bool isLightTheme;
  final VoidCallback onTap;

  const _PlusButton({
    required this.size,
    required this.isLightTheme,
    required this.onTap,
  });

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
    
    // Glow pulse animation (2.5 seconds, gentle breathing)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: widget.isLightTheme
                      ? [
                          const ui.Color.fromARGB(255, 203, 200, 212).withValues(alpha: 0.85),  // Soft pastel lilac
                          const ui.Color.fromARGB(255, 183, 165, 219),/// Slightly lighter
                        ]
                      : [
                          const ui.Color.fromARGB(255, 171, 150, 216),// Brighter pastel for dark theme
                          const ui.Color.fromARGB(255, 116, 104, 145).withValues(alpha: 0.85), // Slightly lighter
                        ],
                ),
                boxShadow: [
                  // Gentle inner glow (soft, diffused)
                  BoxShadow(
                    color: widget.isLightTheme
                        ? const Color(0xFF9485B7).withValues(
                            alpha: 0.65 * _glowAnimation.value, // More visible on light
                          )
                        : const Color(0xFFCBB7F5).withValues(
                            alpha: 0.45 * _glowAnimation.value,
                          ),
                    blurRadius: 18 + (4 * _glowAnimation.value), // 16-20px soft blur
                    spreadRadius: 1 + (1 * _glowAnimation.value),
                  ),
                  // Very soft outer halo
                  BoxShadow(
                    color: widget.isLightTheme
                        ? const Color(0xFF9485B7).withValues(
                            alpha: 0.35 * _glowAnimation.value, // More visible on light
                          )
                        : const Color(0xFFCBB7F5).withValues(
                            alpha: 0.20 * _glowAnimation.value,
                          ),
                    blurRadius: 24 + (6 * _glowAnimation.value),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(widget.size / 2),
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: widget.isLightTheme
                          ? const Color(0xFF5E3A9E) // Deep purple for visibility
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
