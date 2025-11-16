import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/lock_service.dart';
import 'home_screen.dart';
import '../utils/theme_utils.dart';
import '../widgets/theme_background_wrapper.dart';

class PinRemovePage extends StatefulWidget {
  const PinRemovePage({super.key});

  @override
  State<PinRemovePage> createState() => _PinRemovePageState();
}

class _PinRemovePageState extends State<PinRemovePage> {
  String _pin = '';
  final int _pinLength = 4;
  bool _isLoading = false;
  String? _errorMessage;

  void _onNumberPressed(String number) {
    if (_pin.length < _pinLength && !_isLoading) {
      setState(() {
        _pin += number;
        _errorMessage = null;
      });

      // If PIN is complete, verify
      if (_pin.length == _pinLength) {
        _verifyAndRemovePin();
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

  Future<void> _verifyAndRemovePin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await LockService.verifyPin(_pin);

    if (!mounted) return;

    if (isValid) {
      // PIN is correct, remove it
      final success = await LockService.removePin();

      if (!mounted) return;

      if (success) {
        // Navigate back to home screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to remove PIN. Please try again.';
          _pin = '';
        });
      }
    } else {
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

    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                      MediaQuery.of(context).padding.top - 
                      MediaQuery.of(context).padding.bottom - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),
                    // Lock icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.3),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_open_outlined,
                        size: 40,
                        color: isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 30),
                    // Title
                    Text(
                      'Enter PIN to Remove',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Verify your PIN to remove app lock',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isLightTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 30 : 50),
                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pinLength,
                        (index) => Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _pin.length
                                ? (isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white)
                                : Colors.transparent,
                            border: Border.all(
                              color: index < _pin.length
                                  ? Colors.transparent
                                  : (isLightTheme
                                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.3)),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                            width: 1,
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
                      const CircularProgressIndicator(
                        color: Color(0xFF5E3A9E),
                      ),
                    ],
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),
                    // Numeric keypad
                    _buildKeypad(),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1'),
            const SizedBox(width: 20),
            _buildKeypadButton('2'),
            const SizedBox(width: 20),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 20),
        // Row 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4'),
            const SizedBox(width: 20),
            _buildKeypadButton('5'),
            const SizedBox(width: 20),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 20),
        // Row 3: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7'),
            const SizedBox(width: 20),
            _buildKeypadButton('8'),
            const SizedBox(width: 20),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 20),
        // Row 4: empty, 0, delete
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // Empty space
            const SizedBox(width: 20),
            _buildKeypadButton('0'),
            const SizedBox(width: 20),
            _buildDeleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String number) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: _isLoading ? null : () => _onNumberPressed(number),
      child: Opacity(
        opacity: _isLoading ? 0.5 : 1.0,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.3),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: _isLoading ? null : _onDeletePressed,
      child: Opacity(
        opacity: _isLoading ? 0.5 : 1.0,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.3),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.backspace_outlined,
            size: 28,
            color: isLightTheme
                ? const Color(0xFF5E3A9E)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

