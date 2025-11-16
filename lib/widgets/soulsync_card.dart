import 'package:flutter/material.dart';

class SoulSyncCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;
  final BoxBorder? border;

  const SoulSyncCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius = 24,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isLightTheme ? 0.5 : 0.25,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1.5,
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: card,
        ),
      );
    }

    return card;
  }
}

