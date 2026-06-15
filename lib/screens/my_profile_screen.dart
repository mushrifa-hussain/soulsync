import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:soulsync_dairyapp/services/profile_service.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String? _email;
  String? _photoUrl;
  String? _username;
  String _bio = 'Each day provides its own gifts.';
  String? _localPhotoPath;
  bool _isLoading = true;
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    _email = ProfileService.getEmail();
    _photoUrl = ProfileService.getPhotoUrl();
    _username = await ProfileService.getUsername();
    _bio = await ProfileService.getBio();
    _localPhotoPath = await ProfileService.getLocalPhotoPath();

    _usernameController.text = _username ?? '';
    _bioController.text = _bio;

    setState(() {
      _isLoading = false;
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
            backgroundColor: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.trim().isNotEmpty) {
      await ProfileService.updateUsername(_usernameController.text.trim());
    }
    await ProfileService.updateBio(_bioController.text);
    
    if (mounted) {
      Navigator.pop(context, true); // Return true to indicate changes were made
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.white.withValues(alpha: 0.5),
      child: const Icon(
        Icons.person,
        size: 50,
        color: Color(0xFF5E3A9E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLightTheme
                ? [
                    const Color(0xFFF8E7FF),
                    const Color(0xFFE8D5FF),
                    const Color(0xFFDDEBFF),
                  ]
                : [
                    const Color(0xFF2D1B3D),
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 16.0,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'My Profile',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _saveProfile,
                            child: Text(
                              'Save',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5E3A9E),
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
                            GestureDetector(
                              onTap: _pickProfilePhoto,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.9),
                                          Colors.white.withValues(alpha: 0.7),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _localPhotoPath != null &&
                                              File(_localPhotoPath!).existsSync()
                                          ? Image.file(
                                              File(_localPhotoPath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return _buildDefaultAvatar();
                                              },
                                            )
                                          : _photoUrl != null && _photoUrl!.isNotEmpty
                                              ? Image.network(
                                                  _photoUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return _buildDefaultAvatar();
                                                  },
                                                )
                                              : _buildDefaultAvatar(),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF5E3A9E), Color(0xFF9B7EDE)],
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
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
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Username Field
                            _buildTextField(
                              isLightTheme,
                              'Username',
                              _usernameController,
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 20),
                            // Bio Field
                            _buildTextField(
                              isLightTheme,
                              'Bio',
                              _bioController,
                              Icons.edit,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            // Email (View Only)
                            _buildEmailField(isLightTheme),
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

  Widget _buildTextField(
    bool isLightTheme,
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: isLightTheme
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            icon,
            color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildEmailField(bool isLightTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.06 : 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.email_outlined,
            color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
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
                    color: isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email ?? 'No email',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
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

