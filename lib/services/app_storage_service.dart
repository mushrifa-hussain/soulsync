import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app-level storage (first launch, theme completion, etc.)
class AppStorageService {
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _isThemeSelectedKey = 'is_theme_selected';

  /// Check if this is the first launch of the app
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true; // Default to true (first launch)
  }

  /// Check if user has completed theme selection
  /// This is the key check - app only goes to home after theme is selected
  static Future<bool> isThemeSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isThemeSelectedKey) ?? false; // Default to false
  }

  /// Mark that the app has been launched (not first launch anymore)
  /// NOTE: This is called when onboarding is viewed, but doesn't mark completion
  static Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  /// Mark that theme has been selected (onboarding fully complete)
  /// This is called when user selects a theme or clicks "Later"
  static Future<void> setThemeSelected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isThemeSelectedKey, true);
    // Also mark first launch as complete
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  /// Reset first launch flag (for testing/debugging)
  static Future<void> resetFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isFirstLaunchKey);
    await prefs.remove(_isThemeSelectedKey);
  }
}

