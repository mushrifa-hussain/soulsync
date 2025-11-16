/// Custom exception class for authentication errors
class AuthException implements Exception {
  final String message;
  final String code;

  AuthException(this.message, this.code);

  @override
  String toString() => message;
}

/// Maps Firebase Auth error codes to user-friendly messages
class AuthExceptionHandler {
  static AuthException handleException(dynamic exception) {
    if (exception is AuthException) {
      return exception;
    }

    final String errorCode = exception.code?.toString() ?? '';
    final String errorMessage = exception.message?.toString() ?? '';

    switch (errorCode) {
      case 'user-not-found':
        return AuthException(
          'No account found with this email address.',
          errorCode,
        );
      case 'wrong-password':
        return AuthException(
          'Incorrect password. Please try again.',
          errorCode,
        );
      case 'email-already-in-use':
        return AuthException(
          'An account already exists with this email address.',
          errorCode,
        );
      case 'weak-password':
        return AuthException(
          'Password is too weak. Please use at least 6 characters.',
          errorCode,
        );
      case 'invalid-email':
        return AuthException(
          'Invalid email address. Please check and try again.',
          errorCode,
        );
      case 'user-disabled':
        return AuthException(
          'This account has been disabled. Please contact support.',
          errorCode,
        );
      case 'too-many-requests':
        return AuthException(
          'Too many failed attempts. Please try again later.',
          errorCode,
        );
      case 'operation-not-allowed':
        return AuthException(
          'This operation is not allowed. Please contact support.',
          errorCode,
        );
      case 'network-request-failed':
      case 'network_error':
        return AuthException(
          'Network error. Please check your internet connection.',
          errorCode,
        );
      default:
        return AuthException(
          errorMessage.isNotEmpty
              ? errorMessage
              : 'An error occurred. Please try again.',
          errorCode,
        );
    }
  }

  /// Handle generic exceptions
  static AuthException handleGenericException(dynamic exception) {
    if (exception is AuthException) {
      return exception;
    }

    final String message = exception.toString();
    
    if (message.contains('network') || message.contains('internet')) {
      return AuthException(
        'Network error. Please check your internet connection.',
        'network_error',
      );
    }

    return AuthException(
      'An unexpected error occurred. Please try again.',
      'unknown_error',
    );
  }
}

