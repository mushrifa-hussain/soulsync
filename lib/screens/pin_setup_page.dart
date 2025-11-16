import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pin_confirm_page.dart';
import '../utils/theme_utils.dart';
import '../widgets/theme_background_wrapper.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String _pin = '';
  final int _pinLength = 4;

  void _onNumberPressed(String number) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number;
      });

      // If PIN is complete, navigate to confirm page
      if (_pin.length == _pinLength) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PinConfirmPage(pin: _pin),
            ),
          ).then((_) {
            // Clear PIN when returning
            if (mounted) {
              setState(() {
                _pin = '';
              });
            }
          });
        });
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildContent(context, isLightTheme, isDarkTheme, colorScheme);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isLightTheme, bool isDarkTheme, ColorScheme colorScheme) {
    return Scaffold(
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
                    const SizedBox(height: 40),
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
                    Icons.lock_outline,
                    size: 40,
                    color: isDarkTheme
                        ? Colors.white
                        : (isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white),
                  ),
                ),
                const SizedBox(height: 40),
                // Title
                Text(
                  'Set Your PIN',
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
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  'Enter a 4-digit PIN to secure your diary',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isDarkTheme
                        ? Colors.white.withValues(alpha: 0.9)
                        : (isLightTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.8)),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
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
                      ),
                    ),
                  ),
                ),
                    const SizedBox(height: 20),
                    // Numeric keypad
                    _buildKeypad(isDarkTheme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isDarkTheme) {
    return Column(
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1', isDarkTheme),
            const SizedBox(width: 20),
            _buildKeypadButton('2', isDarkTheme),
            const SizedBox(width: 20),
            _buildKeypadButton('3', isDarkTheme),
          ],
        ),
        const SizedBox(height: 20),
        // Row 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4', isDarkTheme),
            const SizedBox(width: 20),
            _buildKeypadButton('5', isDarkTheme),
            const SizedBox(width: 20),
            _buildKeypadButton('6', isDarkTheme),
          ],
        ),
        const SizedBox(height: 20),
        // Row 3: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7', isDarkTheme),
            const SizedBox(width: 20),
            _buildKeypadButton('8', isDarkTheme),
            const SizedBox(width: 20),
            _buildKeypadButton('9', isDarkTheme),
          ],
        ),
        const SizedBox(height: 20),
        // Row 4: empty, 0, delete
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // Empty space
            const SizedBox(width: 20),
            _buildKeypadButton('0', isDarkTheme),
            const SizedBox(width: 20),
            _buildDeleteButton(isDarkTheme),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String number, bool isDarkTheme) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: () => _onNumberPressed(number),
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

  Widget _buildDeleteButton(bool isDarkTheme) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: _onDeletePressed,
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

