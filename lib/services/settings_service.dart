import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings and preferences
class SettingsService {
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keySkipMoodSelection = 'skip_mood_selection';
  static const String _keyDisplayMoodOnCalendar = 'display_mood_on_calendar';
  static const String _keyThemeSoundEnabled = 'theme_sound_enabled';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  /// Get sound enabled state (global theme ambience)
  static Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySoundEnabled) ?? true; // Default: enabled
  }

  /// Set sound enabled state
  static Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, enabled);
  }

  /// Get skip mood selection page state
  static Future<bool> getSkipMoodSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySkipMoodSelection) ?? false; // Default: show mood selection
  }

  /// Set skip mood selection page state
  static Future<void> setSkipMoodSelection(bool skip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySkipMoodSelection, skip);
  }

  /// Get display mood on calendar state
  static Future<bool> getDisplayMoodOnCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDisplayMoodOnCalendar) ?? true; // Default: show mood
  }

  /// Set display mood on calendar state
  static Future<void> setDisplayMoodOnCalendar(bool display) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDisplayMoodOnCalendar, display);
  }

  /// Get theme sound enabled state (for theme selection page)
  static Future<bool> getThemeSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyThemeSoundEnabled) ?? true; // Default: enabled
  }

  /// Set theme sound enabled state
  static Future<void> setThemeSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyThemeSoundEnabled, enabled);
  }

  /// Get notifications enabled state
  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true; // Default: enabled
  }

  /// Set notifications enabled state
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }
}


