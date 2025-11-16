import 'package:flutter/material.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';

/// A widget that wraps content with the theme's bottom gradient color as background
/// This handles async loading of the theme color
class ThemeBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const ThemeBackgroundWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color>(
      future: ThemeUtils.getBottomGradientColor(context),
      builder: (context, snapshot) {
        final backgroundColor = snapshot.data ?? 
            (Theme.of(context).brightness == Brightness.light 
                ? const Color(0xFFDDEBFF) 
                : const Color(0xFF16213E));
        
        return Container(
          color: backgroundColor,
          child: child,
        );
      },
    );
  }
}

