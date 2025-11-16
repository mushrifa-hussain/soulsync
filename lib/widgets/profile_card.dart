import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_avatar.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';

class ProfileCard extends StatelessWidget {
  final String? name;
  final String? bio;
  final String? localPhotoPath;
  final String? photoUrl;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    this.name,
    this.bio,
    this.localPhotoPath,
    this.photoUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildCard(context, colorScheme, isLightTheme, isDarkTheme);
      },
    );
  }
  
  Widget _buildCard(BuildContext context, ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLightTheme
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
                blurRadius: 18,
                offset: const Offset(0, 5),
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            children: [
              ProfileAvatar(
                localPhotoPath: localPhotoPath,
                photoUrl: photoUrl,
                size: 70,
                onTap: null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name ?? 'Your Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.white
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio?.isNotEmpty == true
                          ? bio!
                          : 'Tap to edit your profile',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDarkTheme
                            ? Colors.white.withValues(alpha: 0.8)
                            : (bio?.isNotEmpty == true
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        fontStyle: bio?.isNotEmpty == true ? null : FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

