import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service to store and retrieve the selected theme path in local storage
/// Uses shared_preferences for persistent storage
class ThemeStorageService {
  static const String _themePathKey = 'selected_theme_path';
  static const String _bottomColorKey = 'theme_bottom_color';

  /// Save the selected theme path to local storage
  /// 
  /// [themePath] - The path to the theme image (e.g., 'assets/themes/theme1.jpg')
  /// 
  /// To add more themes, simply add new image files to assets/themes/ folder
  /// and reference them with their full path
  static Future<void> saveThemePath(String themePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePathKey, themePath);
  }

  /// Get the saved theme path from local storage
  /// 
  /// Returns the theme path if found, null otherwise
  static Future<String?> getThemePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themePathKey);
  }

  /// Clear the saved theme path
  static Future<void> clearThemePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themePathKey);
    await prefs.remove(_bottomColorKey);
  }

  /// Save the bottom color for the current theme
  static Future<void> saveBottomColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bottomColorKey, color.value);
  }

  /// Get the saved bottom color for the current theme
  /// Returns null if no color is saved
  static Future<Color?> getBottomColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_bottomColorKey);
    if (colorValue != null) {
      return Color(colorValue);
    }
    return null;
  }
}
