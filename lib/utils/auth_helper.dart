import 'package:firebase_auth/firebase_auth.dart';

/// Helper class for authentication checks
class AuthHelper {
  /// Check if user is currently logged in
  static bool isLoggedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Get current user email
  static String? getCurrentUserEmail() {
    return FirebaseAuth.instance.currentUser?.email;
  }

  /// Get current user
  static User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }
}

