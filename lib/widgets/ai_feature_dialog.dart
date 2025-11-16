import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/auth/auth_screen.dart';

/// Dialog shown when user tries to access AI features without being logged in
class AIFeatureDialog extends StatelessWidget {
  const AIFeatureDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const AIFeatureDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Sign-in Required',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      content: Text(
        'You need an account to use AI-powered features.',
        style: GoogleFonts.poppins(
          fontSize: 16,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AuthScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B4C93),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Sign In',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

