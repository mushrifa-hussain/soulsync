import 'dart:io';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String? localPhotoPath;
  final String? photoUrl;
  final double size;
  final bool showCameraIcon;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.localPhotoPath,
    this.photoUrl,
    this.size = 120.0,
    this.showCameraIcon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    Widget avatarContent;

    if (localPhotoPath != null && File(localPhotoPath!).existsSync()) {
      avatarContent = Image.file(
        File(localPhotoPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(colorScheme),
      );
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatarContent = Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(colorScheme),
      );
    } else {
      avatarContent = _buildDefaultAvatar(colorScheme);
    }

    final avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarContent,
      ),
    );

    if (showCameraIcon && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Hero(
              tag: 'profile_avatar',
              child: avatarWidget,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: size * 0.15,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'profile_avatar',
          child: avatarWidget,
        ),
      );
    }

    return Hero(
      tag: 'profile_avatar',
      child: avatarWidget,
    );
  }

  Widget _buildDefaultAvatar(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.5,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

