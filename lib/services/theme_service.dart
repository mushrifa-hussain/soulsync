import 'package:flutter/material.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Store selected theme index
  int? _selectedThemeIndex;

  // Theme data - Photo themes first, then gradient themes
  final List<DiaryTheme> themes = [
    // Photo-based themes (appear first)
    DiaryTheme(
      name: 'Peaceful Morning',
      assetPath: 'assets/photo_theme1.jpg',
      color: const Color(0xFFFFB3D9), // Soft pink
      isPhotoTheme: true,
    ),
    DiaryTheme(
      name: 'Sunset Serenity',
      assetPath: 'assets/photo_theme2.jpg',
      color: const Color(0xFFFFC5E1), // Light pink
      isPhotoTheme: true,
    ),
    DiaryTheme(
      name: 'Ocean Calm',
      assetPath: 'assets/photo_theme3.jpg',
      color: const Color(0xFFE8D5FF), // Soft purple
      isPhotoTheme: true,
    ),
    DiaryTheme(
      name: 'Floral Dreams',
      assetPath: 'assets/photo_theme4.jpg',
      color: const Color(0xFFFFB3D9), // Soft pink
      isPhotoTheme: true,
    ),
    DiaryTheme(
      name: 'Nature\'s Embrace',
      assetPath: 'assets/photo_theme5.jpg',
      color: const Color(0xFFB8E6FF), // Sky blue
      isPhotoTheme: true,
    ),
    // Gradient-based themes (appear after photo themes)
    DiaryTheme(
      name: 'Serene Sunset',
      assetPath: 'assets/theme1.jpg',
      color: const Color(0xFFFF6B9D),
      isPhotoTheme: false,
    ),
    DiaryTheme(
      name: 'Lavender Dreams',
      assetPath: 'assets/theme2.jpg',
      color: const Color(0xFF9B7BFF),
      isPhotoTheme: false,
    ),
    DiaryTheme(
      name: 'Ocean Breeze',
      assetPath: 'assets/theme3.jpg',
      color: const Color(0xFF6BC5FF),
      isPhotoTheme: false,
    ),
    DiaryTheme(
      name: 'Peach Blossom',
      assetPath: 'assets/theme4.jpg',
      color: const Color(0xFFFFB84D),
      isPhotoTheme: false,
    ),
    DiaryTheme(
      name: 'Mint Fresh',
      assetPath: 'assets/theme5.jpg',
      color: const Color(0xFF4ECDC4),
      isPhotoTheme: false,
    ),
  ];

  int? get selectedThemeIndex => _selectedThemeIndex;
  
  DiaryTheme? get selectedTheme {
    if (_selectedThemeIndex != null && 
        _selectedThemeIndex! >= 0 && 
        _selectedThemeIndex! < themes.length) {
      return themes[_selectedThemeIndex!];
    }
    return null;
  }

  void setSelectedTheme(int index) {
    if (index >= 0 && index < themes.length) {
      _selectedThemeIndex = index;
    }
  }

  void clearSelection() {
    _selectedThemeIndex = null;
  }
}

class DiaryTheme {
  final String name;
  final String assetPath;
  final Color color;
  final bool isPhotoTheme;

  DiaryTheme({
    required this.name,
    required this.assetPath,
    required this.color,
    this.isPhotoTheme = false,
  });
}
