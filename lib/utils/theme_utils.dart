import 'package:flutter/material.dart';
import 'package:soulsync_dairyapp/services/theme_storage_service.dart';

class ThemeUtils {
  /// Check if the current theme is one of the dark themes
  /// Returns true for theme_midnight_whispers and theme_butterfly_night
  static Future<bool> isDarkTheme() async {
    final themePath = await ThemeStorageService.getThemePath();
    if (themePath == null) return false;
    
    return themePath.contains('theme_midnight_whispers') ||
           themePath.contains('theme_butterfly_night');
  }

  /// Get appropriate text color for dark themes
  /// Returns white for dark themes, otherwise uses the provided color or theme default
  static Future<Color> getTextColor(BuildContext context, {Color? defaultColor}) async {
    final isDark = await isDarkTheme();
    if (isDark) {
      return Colors.white;
    }
    
    if (defaultColor != null) {
      return defaultColor;
    }
    
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    if (isLightTheme) {
      return const Color(0xFF5E3A9E); // Purple for light themes
    }
    return Colors.white;
  }

  /// Get text color for light backgrounds (like cards)
  /// Returns purple for dark themes on light backgrounds, otherwise uses theme default
  static Future<Color> getTextColorForLightBackground(BuildContext context) async {
    final isDark = await isDarkTheme();
    if (isDark) {
      return const Color(0xFF5E3A9E); // Purple on light backgrounds for dark themes
    }
    
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    if (isLightTheme) {
      return const Color(0xFF5E3A9E); // Purple for light themes
    }
    return Colors.white;
  }
  /// Get the bottom color from the currently selected theme
  /// This is used as the background for secondary screens
  /// Returns the theme's bottom color if available, otherwise falls back to default
  static Future<Color> getBottomGradientColor(BuildContext context) async {
    // Try to get the saved bottom color for the current theme
    final savedColor = await ThemeStorageService.getBottomColor();
    if (savedColor != null) {
      return savedColor;
    }
    
    // Fallback to default gradient bottom color
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    if (isLightTheme) {
      return const Color(0xFFDDEBFF); // Soft blue
    } else {
      return const Color(0xFF16213E); // Deep blue
    }
  }

  /// Get the lighter background color for secondary screens (same as new entry screen)
  /// For dark themes, this returns a lighter version of the bottom color
  /// For light themes, returns the same as getBottomGradientColor
  static Future<Color> getLighterBackgroundColor(BuildContext context) async {
    final isDark = await isDarkTheme();
    final bottomColor = await getBottomGradientColor(context);
    
    // For dark themes, apply the lighter calculation (same as new entry screen)
    if (isDark) {
      return Color.fromRGBO(
        ((bottomColor.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        ((bottomColor.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        ((bottomColor.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        1.0,
      );
    }
    
    // For light themes, return the bottom color as is
    return bottomColor;
  }

  /// Get the full gradient for primary screens (Home, Splash, Onboarding)
  static List<Color> getPrimaryGradient(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    if (isLightTheme) {
      return [
        const Color(0xFFF8E7FF), // Soft purple-pink
        const Color(0xFFE8D5FF), // Light purple
        const Color(0xFFDDEBFF), // Soft blue
      ];
    } else {
      return [
        const Color(0xFF2D1B3D),
        const Color(0xFF1A1A2E),
        const Color(0xFF16213E),
      ];
    }
  }
}

