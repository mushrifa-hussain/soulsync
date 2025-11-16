import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/lock_service.dart';
import '../widgets/theme_background_wrapper.dart';
import '../utils/theme_utils.dart';

class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage({super.key});

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> with SingleTickerProviderStateMixin {
  String _pin = '';
  final int _pinLength = 4;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_pin.length < _pinLength && !_isLoading) {
      setState(() {
        _pin += number;
        _errorMessage = null; // Clear error when typing
      });

      // If PIN is complete, verify
      if (_pin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty && !_isLoading) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await LockService.verifyPin(_pin);

    if (!mounted) return;

    if (isValid) {
      // PIN is correct, navigate to home screen
      // Navigate to Home and clear all previous routes to make Home the root
      // This ensures back button on Home will exit the app
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false, // Remove all previous routes
      );
    } else {
      // Shake animation for error
      _shakeController.forward(from: 0.0);
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect PIN. Please try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildContent(context, isLightTheme, isDarkTheme);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isLightTheme, bool isDarkTheme) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const SizedBox(height: 40),
                  // Lock icon with smooth animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: Container(
                          width: 100,
                          height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.4),
                                Colors.white.withValues(alpha: 0.2),
                              ],
                            ),
                        border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                        ),
                            ],
                      ),
                      child: Icon(
                            Icons.lock_outline_rounded,
                            size: 48,
                        color: isDarkTheme
                            ? Colors.white
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                      ),
                    ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                    // Title
                    Text(
                      'Enter Your PIN',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.white
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                      ),
                    ),
                  const SizedBox(height: 6),
                    // Subtitle
                    Text(
                      'Unlock your diary',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDarkTheme
                            ? Colors.white.withValues(alpha: 0.9)
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                  const SizedBox(height: 40),
                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pinLength,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _pin.length
                                ? (isDarkTheme
                                    ? Colors.white
                                    : (isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                        : Colors.white))
                                : Colors.transparent,
                            border: Border.all(
                              color: index < _pin.length
                                  ? Colors.transparent
                                  : (isDarkTheme
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : (isLightTheme
                                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.3))),
                              width: 2,
                            ),
                          boxShadow: index < _pin.length
                              ? [
                                  BoxShadow(
                                    color: (isDarkTheme
                                            ? Colors.white
                                            : (isLightTheme
                                                ? const Color(0xFF5E3A9E)
                                                : Colors.white))
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                          ),
                        ),
                      ),
                    ),
                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          width: 1.5,
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    // Loading indicator
                    if (_isLoading) ...[
                      const SizedBox(height: 24),
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDarkTheme
                            ? Colors.white
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                      ),
                      ),
                    ],
                  const SizedBox(height: 50),
                    // Numeric keypad
                  _buildKeypad(isLightTheme, isDarkTheme),
                  const SizedBox(height: 40),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isLightTheme, bool isDarkTheme) {
    return Column(
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1', isLightTheme, isDarkTheme),
            const SizedBox(width: 24),
            _buildKeypadButton('2', isLightTheme, isDarkTheme),
            const SizedBox(width: 24),
            _buildKeypadButton('3', isLightTheme, isDarkTheme),
          ],
        ),
        const SizedBox(height: 20),
        // Row 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4', isLightTheme, isDarkTheme),
            const SizedBox(width: 24),
            _buildKeypadButton('5', isLightTheme, isDarkTheme),
            const SizedBox(width: 24),
            _buildKeypadButton('6', isLightTheme, isDarkTheme),
          ],
        ),
        const SizedBox(height: 20),
        // Row 3: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7', isLightTheme, isDarkTheme),
            const SizedBox(width: 24),
            _buildKeypadButton('8', isLightTheme, isDarkTheme),
            const SizedBox(width: 24),
            _buildKeypadButton('9', isLightTheme, isDarkTheme),
          ],
        ),
        const SizedBox(height: 20),
        // Row 4: empty, 0, delete
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // Empty space
            const SizedBox(width: 24),
            _buildKeypadButton('0', isLightTheme, isDarkTheme),
            const SizedBox(width: 24),
            _buildDeleteButton(isLightTheme, isDarkTheme),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String number, bool isLightTheme, bool isDarkTheme) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _onNumberPressed(number),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.4),
              Colors.white.withValues(alpha: 0.2),
            ],
          ),
            border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: isDarkTheme
                    ? Colors.white
                    : (isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(bool isLightTheme, bool isDarkTheme) {
    return GestureDetector(
      onTap: _isLoading ? null : _onDeletePressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.4),
              Colors.white.withValues(alpha: 0.2),
            ],
          ),
            border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          ),
          child: Icon(
            Icons.backspace_outlined,
            size: 28,
            color: isDarkTheme
                ? Colors.white
                : (isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white),
        ),
      ),
    );
  }
}
