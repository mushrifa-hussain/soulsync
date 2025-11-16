import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_exceptions.dart';

/// Service class for handling Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up a new user with email and password
  /// Creates user in Firebase Auth and creates a Firestore document
  Future<User> signup(String email, String password) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        throw AuthException('Please enter a valid email address.', 'invalid-email');
      }

      // Validate password length
      if (password.length < 6) {
        throw AuthException(
          'Password must be at least 6 characters long.',
          'weak-password',
        );
      }

      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User user = userCredential.user!;

      // Create user document in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'email': email.trim(),
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    } catch (e) {
      throw AuthExceptionHandler.handleGenericException(e);
    }
  }

  /// Sign in an existing user with email and password
  Future<User> login(String email, String password) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        throw AuthException('Please enter a valid email address.', 'invalid-email');
      }

      // Sign in user
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthExceptionHandler.handleException(e);
    } catch (e) {
      throw AuthExceptionHandler.handleGenericException(e);
    }
  }

  /// Sign out the current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthExceptionHandler.handleGenericException(e);
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }
}

