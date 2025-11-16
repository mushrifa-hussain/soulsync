import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user profile data
class ProfileService {
  static const String _keyUsername = 'profile_username';
  static const String _keyBio = 'profile_bio';
  static const String _keyLocalPhotoPath = 'profile_local_photo_path';

  /// Check if user is signed in (uses FirebaseAuth)
  static bool isSignedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Get display name (from FirebaseAuth)
  static String? getDisplayName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.displayName ?? user.email?.split('@')[0] ?? 'User';
  }

  /// Get email (from FirebaseAuth)
  static String? getEmail() {
    return FirebaseAuth.instance.currentUser?.email;
  }

  /// Get photo URL (from FirebaseAuth)
  static String? getPhotoUrl() {
    return FirebaseAuth.instance.currentUser?.photoURL;
  }

  /// Get username (editable)
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// Get bio (editable)
  static Future<String> getBio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBio) ?? 'Each day provides its own gifts.';
  }

  /// Get local photo path (from gallery)
  static Future<String?> getLocalPhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalPhotoPath);
  }

  /// Sync FirebaseAuth user data to local storage (for username/bio)
  static Future<void> syncFirebaseAuthUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final displayName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
    
    // Set username to display name if not already set
    if (prefs.getString(_keyUsername) == null) {
      await prefs.setString(_keyUsername, displayName);
    }
  }

  /// Update username
  static Future<void> updateUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  /// Update bio
  static Future<void> updateBio(String bio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBio, bio);
  }

  /// Save local photo path
  static Future<void> saveLocalPhotoPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalPhotoPath, path);
  }

  /// Log out (clear local profile data, FirebaseAuth handles auth logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyBio);
    await prefs.remove(_keyLocalPhotoPath);
  }

  /// Remove account data (clear everything)
  static Future<void> removeAccountData() async {
    await logout();
  }
}

