import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soulsync_dairyapp/services/profile_service.dart';
import 'package:soulsync_dairyapp/widgets/profile_avatar.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String? _displayName;
  String? _email;
  String? _photoUrl;
  String? _username;
  String _bio = '';
  String? _localPhotoPath;
  String? _initialPhotoPath;
  bool _isLoading = true;
  bool _hasChanges = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _bioFocusNode = FocusNode();
  String? _initialName;
  String _initialBio = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final hasNameChanged = _nameController.text.trim() != (_initialName ?? '');
    final hasBioChanged = _bioController.text != _initialBio;
    // Also check if photo has changed
    final hasPhotoChanged = _localPhotoPath != _initialPhotoPath;
    setState(() {
      _hasChanges = hasNameChanged || hasBioChanged || hasPhotoChanged;
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _email = user.email;
      _displayName = user.displayName ?? _email?.split('@')[0] ?? 'User';
      _photoUrl = user.photoURL;
      _username = await ProfileService.getUsername();
      _bio = await ProfileService.getBio();
      _localPhotoPath = await ProfileService.getLocalPhotoPath();
      _initialPhotoPath = _localPhotoPath;

      // Set name with fallback to display name or default
      final nameToShow = _username ?? _displayName ?? 'Your Name';
      _nameController.text = nameToShow;
      _bioController.text = _bio;
      _initialName = nameToShow;
      _initialBio = _bio;
    }

    setState(() {
      _isLoading = false;
      _hasChanges = false;
    });
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath = path.join(appDir.path, fileName);
        final File localFile = File(localPath);
        await File(image.path).copy(localFile.path);

        await ProfileService.saveLocalPhotoPath(localPath);
        setState(() {
          _localPhotoPath = localPath;
          // Enable save button when photo changes
          _hasChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick image: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_hasChanges) {
      Navigator.pop(context, false);
      return;
    }

    if (_nameController.text.trim().isNotEmpty) {
      await ProfileService.updateUsername(_nameController.text.trim());
    }
    await ProfileService.updateBio(_bioController.text);

    if (mounted) {
      Navigator.pop(context, true);
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
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                )
              : Column(
                  children: [
                    // App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: isDarkTheme
                                  ? Colors.white
                                  : colorScheme.onSurface,
                              size: 24,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'Edit Profile',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isDarkTheme
                                    ? Colors.white
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _hasChanges ? _saveProfile : null,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _hasChanges
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: _hasChanges
                                      ? [
                                          BoxShadow(
                                            color: colorScheme.primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Save',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _hasChanges
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Profile Photo
                            ProfileAvatar(
                              localPhotoPath: _localPhotoPath,
                              photoUrl: _photoUrl,
                              size: 130,
                              showCameraIcon: true,
                              onTap: _pickProfilePhoto,
                            ),
                            const SizedBox(height: 32),
                            // Name Field
                            _buildNameField(colorScheme, isLightTheme, isDarkTheme),
                            const SizedBox(height: 20),
                            // Bio Field
                            _buildBioField(colorScheme, isLightTheme, isDarkTheme),
                            const SizedBox(height: 20),
                            // Email Field (Read-only)
                            _buildEmailField(colorScheme, isLightTheme, isDarkTheme),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildNameField(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightTheme
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: TextField(
        controller: _nameController,
        enabled: true,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: isDarkTheme
              ? Colors.white
              : colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: 'Your Name',
          labelStyle: GoogleFonts.poppins(
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.8)
                : colorScheme.onSurfaceVariant,
          ),
          hintStyle: GoogleFonts.poppins(
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.6)
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.8)
                : colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        onChanged: (value) {
          setState(() {
            _hasChanges = true;
          });
        },
      ),
    );
  }

  Widget _buildBioField(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightTheme
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: TextField(
        controller: _bioController,
        focusNode: _bioFocusNode,
        maxLines: null,
        minLines: 4,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: isDarkTheme
              ? Colors.white
              : colorScheme.onSurface,
          height: 1.5,
        ),
        decoration: InputDecoration(
          labelText: 'Bio',
          hintText: 'Write something about yourself...',
          labelStyle: GoogleFonts.poppins(
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.8)
                : colorScheme.onSurfaceVariant,
          ),
          hintStyle: GoogleFonts.poppins(
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.6)
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            height: 1.5,
          ),
          prefixIcon: Icon(
            Icons.edit_outlined,
            color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.8)
                : colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(20),
        ),
        onChanged: (value) {
          setState(() {
            _hasChanges = true;
          });
        },
      ),
    );
  }

  Widget _buildEmailField(ColorScheme colorScheme, bool isLightTheme, bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightTheme
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.email_outlined,
              color: isDarkTheme
                  ? Colors.white.withValues(alpha: 0.8)
                  : colorScheme.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDarkTheme
                        ? Colors.white.withValues(alpha: 0.8)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email ?? 'No email',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkTheme
                        ? Colors.white
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

