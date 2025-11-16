import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing app lock PIN securely
class LockService {
  static const _storage = FlutterSecureStorage();
  static const String _pinKey = 'app_lock_pin';

  /// Check if a PIN exists
  static Future<bool> hasPin() async {
    try {
      final pin = await _storage.read(key: _pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the stored PIN
  static Future<String?> getPin() async {
    try {
      return await _storage.read(key: _pinKey);
    } catch (e) {
      return null;
    }
  }

  /// Save a new PIN
  static Future<bool> savePin(String pin) async {
    try {
      if (pin.isEmpty || pin.length != 4) {
        debugPrint('❌ LockService: Invalid PIN length: ${pin.length}');
        return false;
      }
      await _storage.write(key: _pinKey, value: pin);
      // Verify it was saved
      final savedPin = await _storage.read(key: _pinKey);
      if (savedPin == pin) {
        debugPrint('✅ LockService: PIN saved successfully');
        return true;
      } else {
        debugPrint('❌ LockService: PIN verification failed after save');
        return false;
      }
    } catch (e) {
      debugPrint('❌ LockService: Error saving PIN: $e');
      return false;
    }
  }

  /// Verify if the entered PIN matches the stored PIN
  static Future<bool> verifyPin(String enteredPin) async {
    try {
      final storedPin = await _storage.read(key: _pinKey);
      return storedPin == enteredPin;
    } catch (e) {
      return false;
    }
  }

  /// Remove the PIN (unlock the app)
  static Future<bool> removePin() async {
    try {
      await _storage.delete(key: _pinKey);
      return true;
    } catch (e) {
      return false;
    }
  }
}

