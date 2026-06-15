import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/services/quill_migration_service.dart';
import 'package:soulsync_dairyapp/widgets/editor_toolbar.dart';
import 'package:soulsync_dairyapp/services/aiml_api_service.dart';

/// Simplified diary entry screen using pure Quill
/// All content (text, images, videos) handled by Quill's native embeds
/// Stickers remain as draggable overlay elements
class NewEntryScreen extends StatefulWidget {
  final Color? themeBottomColor;
  final bool isLightTheme;
  final DiaryEntry? existingEntry;
  final DateTime? initialDate;
  final MediaAttachment? scrollToMedia;
  final String? initialMood;
  final String? initialContent; // For AI summary or other initial text
  final bool navigateToHomeOnSave; // If true, navigate to home after saving instead of popping

  const NewEntryScreen({
    super.key,
    this.themeBottomColor,
    required this.isLightTheme,
    this.existingEntry,
    this.initialDate,
    this.scrollToMedia,
    this.initialMood,
    this.initialContent,
    this.navigateToHomeOnSave = false,
  });

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen>
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _contentFocusNode = FocusNode();
  
  // State
  String? _selectedMood;
  late DateTime _selectedDate;
  bool _showCalendar = false;
  bool _showFormattingToolbar = false;
  String? _selectedTool;

  // Sticker attachments (draggable overlay - kept as is)
  List<StickerAttachment> _stickerAttachments = [];
  int? _selectedStickerIndex;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _calendarController;
  late Animation<double> _calendarScaleAnimation;
  late Animation<double> _calendarOpacityAnimation;
  late AnimationController _hintAnimationController;
  late Animation<double> _hintFadeAnimation;
  late Animation<double> _hintScaleAnimation;
  
  // AI Face animation
  late AnimationController _aiBlinkController;
  late Animation<double> _aiBlinkAnimation;
  late AnimationController _aiGlowController;
  late Animation<double> _aiGlowAnimation;
  bool _aiIsActive = false; // Active/talking state
  
  bool _showEmojiHint = true;
  bool get _isEditing => widget.existingEntry != null;

  final List<String> _moods = [
    '😊',
    '😢',
    '😴',
    '😍',
    '🤔',
    '😌',
    '😎',
    '🥰',
    '😇',
    '😋',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    
    _hintAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _hintFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hintAnimationController, curve: Curves.easeOut),
    );
    _hintScaleAnimation = Tween<double>(begin: 1.1, end: 1.0).animate(
      CurvedAnimation(parent: _hintAnimationController, curve: Curves.easeOut),
    );
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _showEmojiHint && _selectedMood == null) {
        _hintAnimationController.forward();
      }
    });
    
    _calendarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _calendarScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _calendarController, curve: Curves.easeOutCubic),
    );
    _calendarOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _calendarController, curve: Curves.easeOut),
    );

    // Initialize AI face blinking animation (4 second cycle)
    _aiBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _aiBlinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 75.0), // Eyes open: 3s
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 7.5, // Closing: 0.3s
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 10.0), // Closed: 0.4s
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 7.5, // Opening: 0.3s
      ),
    ]).animate(_aiBlinkController);
    
    // Initialize AI glow pulse animation (6 seconds)
    _aiGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat(reverse: true);
    _aiGlowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _aiGlowController, curve: Curves.easeInOut),
    );

    // Initialize date and mood
    _selectedDate = widget.initialDate ?? DateTime.now();
    if (widget.initialMood != null) {
      _selectedMood = widget.initialMood;
    }

    // Load existing entry if editing
    if (widget.existingEntry != null) {
      _loadExistingEntry();
    } else if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      // Initialize with initial content (e.g., from AI summary)
      final document = quill.Document()..insert(0, widget.initialContent!);
      _quillController = quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillController = quill.QuillController.basic();
    }
  }

  void _loadExistingEntry() {
    final entry = widget.existingEntry!;
    _titleController.text = entry.title;
    _selectedMood = entry.mood;
    _selectedDate = entry.timestamp;
    _stickerAttachments = List<StickerAttachment>.from(
      entry.stickerAttachments,
    );

    // Load Quill content (handles text + images + videos)
    if (entry.quillDelta != null && entry.quillDelta!.containsKey('ops')) {
      try {
        final document = quill.Document.fromJson(
          entry.quillDelta!['ops'] as List,
        );
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        debugPrint('Error loading Quill delta: $e');
        // Fallback to plain text
        final document = quill.Document()..insert(0, entry.content);
        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else if (entry.content.isNotEmpty) {
      // Migrate old format to Quill
      final migratedEntry = QuillMigrationService.migrateEntry(entry);
      if (migratedEntry.quillDelta != null) {
        try {
          final document = quill.Document.fromJson(
            migratedEntry.quillDelta!['ops'] as List,
          );
          _quillController = quill.QuillController(
            document: document,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } catch (e) {
          debugPrint('Error loading migrated delta: $e');
          final document = quill.Document()..insert(0, entry.content);
          _quillController = quill.QuillController(
            document: document,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } else {
        final document = quill.Document()..insert(0, entry.content);
    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
      }
    } else {
      _quillController = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _contentFocusNode.dispose();
    _fadeController.dispose();
    _calendarController.dispose();
    _hintAnimationController.dispose();
    _aiBlinkController.dispose();
    _aiGlowController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    if (widget.themeBottomColor != null) {
      final color = widget.themeBottomColor!;
      return Color.fromRGBO(
        ((color.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        ((color.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        ((color.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        1.0,
      );
    }
    return const Color(0xFFE8D5FF);
  }

  String _getFormattedDate() {
    return DateFormat('d MMM yyyy').format(_selectedDate);
  }
  
  String _getFormattedDateForStorage() {
    return DateFormat('d MMM').format(_selectedDate);
  }
  
  void _toggleCalendar() {
    setState(() {
      _showCalendar = !_showCalendar;
      if (_showCalendar) {
        _calendarController.forward();
      } else {
        _calendarController.reverse();
      }
    });
  }
  
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _showCalendar = false;
      _calendarController.reverse();
    });
  }

  Future<void> _saveEntry() async {
    final plainText = _quillController.document.toPlainText();
    if (_titleController.text.trim().isEmpty && plainText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title or content')),
      );
      return;
    }

    // Get Quill delta (contains text + embedded images/videos)
    final deltaJson = _quillController.document.toDelta().toJson();
    final quillDelta = <String, dynamic>{'ops': deltaJson};
    
    final entry = DiaryEntry(
      id: _isEditing 
          ? widget.existingEntry!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      date: _getFormattedDateForStorage(),
      title: _titleController.text.trim().isEmpty
          ? 'Untitled'
          : _titleController.text.trim(),
      content: plainText.trim(),
      mood: _selectedMood ?? '😊',
      timestamp: _selectedDate,
      stickerAttachments: _stickerAttachments,
      quillDelta: quillDelta,
      userId: widget.existingEntry?.userId,
      cloudId: widget.existingEntry?.cloudId,
    );

    try {
      final provider = Provider.of<DiaryEntriesProvider>(
        context,
        listen: false,
      );
      await provider.saveEntry(entry);
      
      if (mounted) {
        _showSuccessAnimation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving entry: $e')));
      }
    }
  }

  void _showSuccessAnimation() {
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          builder: (context) => const _GlowAnimation(),
        );
        
    Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
        Navigator.of(context).pop(); // Close animation dialog
        
        if (widget.navigateToHomeOnSave) {
          // Navigate to home and remove all previous routes (including AI chat)
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false, // Remove all previous routes
          );
        } else {
          // Normal behavior - pop back to previous screen
          Navigator.of(context).pop(true);
        }
      }
    });
  }

  void _showMoodSelector() {
    if (_showEmojiHint) {
      _hintAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() => _showEmojiHint = false);
        }
      });
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "How's your day?",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: widget.isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _moods.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedMood = _moods[index]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedMood == _moods[index]
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMood == _moods[index]
                            ? const Color(0xFF5E3A9E)
                            : Colors.grey.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _moods[index],
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF8F4FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Entry',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5E3A9E),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this entry?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF5E3A9E).withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (!mounted) return;
              Navigator.of(context).pop();
              if (widget.existingEntry != null) {
                final provider = Provider.of<DiaryEntriesProvider>(
                  context,
                  listen: false,
                );
                await provider.deleteEntry(widget.existingEntry!.id);
                if (mounted && context.mounted) {
                  Navigator.of(context).pop(widget.existingEntry);
                }
              }
            },
            child: Text(
                          'Delete',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF5E3A9E),
                fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
      ),
    );
  }

  // Insert image using Quill's native embed
  Future<void> _insertImage() async {
    FocusScope.of(context).unfocus();

    final picker = ImagePicker();
    final source = await _showSourceDialog();
    if (source == null) return;

    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        // Copy to app directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(image.path);
        final savedPath = path.join(appDir.path, 'diary_media', fileName);
        final savedFile = File(savedPath);
        await savedFile.parent.create(recursive: true);
        await File(image.path).copy(savedPath);

        // Insert into Quill at cursor position
        final index = _quillController.selection.baseOffset;
        _quillController.document.insert(index, '\n');
        _quillController.document.insert(
          index + 1,
          quill.BlockEmbed.image(savedPath),
        );
        _quillController.updateSelection(
          TextSelection.collapsed(offset: index + 2),
          quill.ChangeSource.local,
        );

        setState(() => _selectedTool = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding image: $e')));
      }
    }
  }

  // Insert video using Quill's native embed
  Future<void> _insertVideo() async {
    FocusScope.of(context).unfocus();

    final picker = ImagePicker();
    final source = await _showSourceDialog();
    if (source == null) return;

    try {
      final XFile? video = await picker.pickVideo(source: source);
      if (video != null) {
        // Copy to app directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(video.path);
        final savedPath = path.join(appDir.path, 'diary_media', fileName);
        final savedFile = File(savedPath);
        await savedFile.parent.create(recursive: true);
        await File(video.path).copy(savedPath);

        // Insert into Quill at cursor position
        final index = _quillController.selection.baseOffset;
        _quillController.document.insert(index, '\n');
        _quillController.document.insert(
          index + 1,
          quill.BlockEmbed.video(savedPath),
        );
        _quillController.updateSelection(
          TextSelection.collapsed(offset: index + 2),
          quill.ChangeSource.local,
        );

        setState(() => _selectedTool = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding video: $e')));
      }
    }
  }

  Future<ImageSource?> _showSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isLightTheme
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.grey[900]!.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                    'Select Source',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                      fontWeight: FontWeight.w600,
                              color: widget.isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white,
                            ),
                          ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.camera_alt_rounded,
                            color: widget.isLightTheme
                          ? const Color(0xFF5E3A9E)
                          : Colors.white,
                    ),
                    title: Text(
                      'Camera',
                      style: GoogleFonts.poppins(
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library_rounded,
                      color: widget.isLightTheme
                          ? const Color(0xFF5E3A9E)
                          : Colors.white,
                    ),
                    title: Text(
                      'Gallery',
                      style: GoogleFonts.poppins(
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  void _handleToolSelection(String tool) {
    switch (tool) {
      case 'photo':
        _insertImage();
        break;
      case 'video':
        _insertVideo();
        break;
      case 'audio':
        _showAudioRecorder();
        break;
      case 'drawing':
        _showDrawingCanvas();
        break;
      case 'sticker':
        _showStickerPicker();
        break;
      case 'format':
        setState(() => _showFormattingToolbar = !_showFormattingToolbar);
        break;
    }
  }

  // Show audio recorder
  void _showAudioRecorder() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AudioRecordingWidget(
        isLightTheme: widget.isLightTheme,
        onAudioRecorded: (audioPath) {
          // Insert audio as an image placeholder in Quill
          // (Quill doesn't have native audio support, so we use a visual representation)
          _insertAudioAsImage(audioPath);
          setState(() => _selectedTool = null);
        },
        onClose: () {
          setState(() => _selectedTool = null);
        },
      ),
    );
  }

  // Insert audio as custom embed
  Future<void> _insertAudioAsImage(String audioPath) async {
    // Insert audio as custom Quill embed
    final index = _quillController.selection.baseOffset;
    final audioEmbed = quill.BlockEmbed.custom(AudioBlockEmbed(audioPath));
    _quillController.document.insert(index, '\n');
    _quillController.document.insert(index + 1, audioEmbed);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      quill.ChangeSource.local,
    );
  }

  // Show drawing canvas
  void _showDrawingCanvas() {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DrawingCanvasScreen(
          isLightTheme: widget.isLightTheme,
          onDrawingSaved: (imagePath, drawingDataPath) {
            // Insert drawing as image in Quill
            _insertDrawingAsImage(imagePath);
            setState(() => _selectedTool = null);
          },
        ),
      ),
    );
  }

  // Insert drawing as image
  void _insertDrawingAsImage(String imagePath) {
    final index = _quillController.selection.baseOffset;
    _quillController.document.insert(index, '\n');
    _quillController.document.insert(
      index + 1,
      quill.BlockEmbed.image(imagePath),
    );
    _quillController.updateSelection(
      TextSelection.collapsed(offset: index + 2),
      quill.ChangeSource.local,
    );
  }

  // Remove image embed from document
  void _removeImageEmbed(String imagePath) {
    final document = _quillController.document;
    final delta = document.toDelta();

    int currentOffset = 0;
    for (final op in delta.toList()) {
      if (op.data is Map) {
        final data = op.data as Map;
        if (data.containsKey('image') && data['image'] == imagePath) {
          _quillController.updateSelection(
            TextSelection(
              baseOffset: currentOffset,
              extentOffset: currentOffset + 1,
            ),
            quill.ChangeSource.local,
          );
          _quillController.document.delete(currentOffset, 1);
          return;
        }
      }
      if (op.data is String) {
        currentOffset += (op.data as String).length;
      } else {
        currentOffset += 1;
      }
    }
  }

  // Remove video embed from document
  void _removeVideoEmbed(String videoPath) {
    final document = _quillController.document;
    final delta = document.toDelta();

    int currentOffset = 0;
    for (final op in delta.toList()) {
      if (op.data is Map) {
        final data = op.data as Map;
        if (data.containsKey('video') && data['video'] == videoPath) {
          _quillController.updateSelection(
            TextSelection(
              baseOffset: currentOffset,
              extentOffset: currentOffset + 1,
            ),
            quill.ChangeSource.local,
          );
          _quillController.document.delete(currentOffset, 1);
          return;
        }
      }
      if (op.data is String) {
        currentOffset += (op.data as String).length;
      } else {
        currentOffset += 1;
      }
    }
  }

  // Show image fullscreen
  void _showImageFullScreen(String imagePath) {
    // Check if this is a drawing (drawings are saved in 'diary_drawings' folder)
    final isDrawing =
        imagePath.contains('diary_drawings') || imagePath.contains('drawing_');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDrawing ? Colors.white : Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(
                  File(imagePath),
                  fit: isDrawing ? BoxFit.contain : BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: isDrawing ? Colors.black : Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Show video fullscreen
  void _showVideoFullScreen(String videoPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
                  children: [
            Center(child: _VideoPlayerWidget(videoPath: videoPath)),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
    );
  }

  // Remove audio embed from document
  void _removeAudioEmbed(String audioPath) {
    final document = _quillController.document;
    final delta = document.toDelta();

    // Find the audio embed and calculate its position
    int currentOffset = 0;
    for (final op in delta.toList()) {
      if (op.data is Map) {
        final data = op.data as Map;
        if (data.containsKey('audio') && data['audio'] == audioPath) {
          // Delete the embed by selecting it and deleting
          _quillController.updateSelection(
            TextSelection(
              baseOffset: currentOffset,
              extentOffset: currentOffset + 1,
            ),
            quill.ChangeSource.local,
          );
          _quillController.document.delete(currentOffset, 1);
          return;
        }
      }
      // Calculate offset for next iteration
      if (op.data is String) {
        currentOffset += (op.data as String).length;
      } else {
        currentOffset += 1; // Embeds count as 1
      }
    }
  }

  void _showStickerPicker() {
    FocusScope.of(context).unfocus();

    // Categorized sticker picker
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _StickerPickerBottomSheet(
                        isLightTheme: widget.isLightTheme,
        onStickerSelected: (emoji) {
                              setState(() {
            _stickerAttachments.add(
              StickerAttachment(
                emoji: emoji,
                x: 0.5,
                y: 0.4,
                size: 1.0,
                rotation: 0.0,
              ),
            );
            _selectedTool = null;
                          });
                        },
                      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_showEmojiHint) {
            setState(() => _showEmojiHint = false);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: backgroundColor,
          resizeToAvoidBottomInset: true,
          appBar: _buildAppBar(),
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                              // Main content (title + Quill editor)
                        SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                    // Title field
                              Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 12,
                                      ),
                                child: TextField(
                                  controller: _titleController,
                                  onTap: () {
                                    if (_selectedStickerIndex != null) {
                                            setState(
                                              () =>
                                                  _selectedStickerIndex = null,
                                            );
                                    }
                                  },
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: widget.isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                        : Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Title',
                                    hintStyle: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                            color:
                                                (widget.isLightTheme
                                                        ? const Color(
                                                            0xFF5E3A9E,
                                                          )
                                              : Colors.white)
                                          .withValues(alpha: 0.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                ),
                              ),
                                    // Quill editor (handles all content)
                                    // Auto-size to content and scroll with parent
                                    GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        // Deselect sticker when tapping on editor
                                        if (_selectedStickerIndex != null) {
                                          setState(() {
                                            _selectedStickerIndex = null;
                                          });
                                        }
                                      },
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        ),
                                        child: DefaultTextStyle(
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: widget.isLightTheme
                                                ? const Color(0xFF5E3A9E)
                                                : Colors.white,
                                          ),
                                          child: quill.QuillEditor.basic(
                                            controller: _quillController,
                                            focusNode: _contentFocusNode,
                                            config: quill.QuillEditorConfig(
                                              padding: EdgeInsets.only(bottom: 100),
                                              scrollable: false, // Disable internal scrolling - let parent handle it
                                              placeholder: 'Start writing...',
                                              embedBuilders: [
                                              // Custom image embed with delete button
                                              ImageEmbedBuilder(
                                                isLightTheme: widget.isLightTheme,
                                                onDelete: (imagePath) =>
                                                    _removeImageEmbed(imagePath),
                                                onTap: (imagePath) =>
                                                    _showImageFullScreen(
                                                      imagePath,
                                                    ),
                                              ),
                                              // Custom video embed with delete button
                                              VideoEmbedBuilder(
                                                isLightTheme: widget.isLightTheme,
                                                onDelete: (videoPath) =>
                                                    _removeVideoEmbed(videoPath),
                                                onTap: (videoPath) =>
                                                    _showVideoFullScreen(
                                                      videoPath,
                                                    ),
                                              ),
                                              // Audio embed
                                              AudioEmbedBuilder(
                                                isLightTheme: widget.isLightTheme,
                                                onDelete: (audioPath) =>
                                                    _removeAudioEmbed(audioPath),
                                              ),
                              ],
                            ),
                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Draggable stickers overlay
                              ..._stickerAttachments.asMap().entries.map((
                                entry,
                              ) {
                          final index = entry.key;
                          final sticker = entry.value;
                          return _DraggableStickerWidget(
                            key: ValueKey('sticker_$index'),
                            sticker: sticker,
                            index: index,
                            isLightTheme: widget.isLightTheme,
                            isSelected: _selectedStickerIndex == index,
                                  contentWidth: constraints.maxWidth,
                                  contentHeight: constraints.maxHeight,
                            onSelect: () {
                              FocusScope.of(context).unfocus();
                                    setState(
                                      () => _selectedStickerIndex = index,
                                    );
                            },
                            onDeselect: () {
                                    setState(
                                      () => _selectedStickerIndex = null,
                                    );
                            },
                            onUpdate: (updatedSticker) {
                              setState(() {
                                      _stickerAttachments[index] =
                                          updatedSticker;
                              });
                            },
                            onDelete: () {
                              setState(() {
                                _stickerAttachments.removeAt(index);
                                if (_selectedStickerIndex == index) {
                                  _selectedStickerIndex = null;
                                      } else if (_selectedStickerIndex !=
                                              null &&
                                          _selectedStickerIndex! > index) {
                                        _selectedStickerIndex =
                                            _selectedStickerIndex! - 1;
                                }
                              });
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              _buildBottomToolbar(),
            ],
          ),
        ),
            if (_showFormattingToolbar)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: EditorToolbar(
                  controller: _quillController,
                    isLightTheme: widget.isLightTheme,
                    onDone: () =>
                        setState(() => _showFormattingToolbar = false),
          ),
        ),
            if (_showCalendar)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                      FocusScope.of(context).unfocus();
                    _toggleCalendar();
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
            if (_showCalendar)
              Center(
                child: FadeTransition(
                  opacity: _calendarOpacityAnimation,
                  child: ScaleTransition(
                    scale: _calendarScaleAnimation,
                    child: _SoulSyncCalendar(
                      selectedDate: _selectedDate,
                      onDateSelected: (date) {
                          FocusScope.of(context).unfocus();
                        _selectDate(date);
                      },
                      isLightTheme: widget.isLightTheme,
                    ),
                  ),
                ),
              ),
            // AI Face Assistant at bottom
            _buildAIFaceAssistant(),
          ],
        ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isEditing)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
            color: const Color(0xFFF8F4FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFF5E3A9E),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF5E3A9E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') _showDeleteConfirmation();
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and Save button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _toggleCalendar();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getFormattedDate(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color:
                          (widget.isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white)
                              .withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (_selectedMood != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _selectedMood!,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _saveEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E3A9E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'SAVE',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mood selector
          GestureDetector(
            onTap: _showMoodSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    'How are you feeling?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color:
                          (widget.isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white)
                              .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showEmojiHint && _selectedMood == null)
            _EmojiHintBubble(
              fadeAnimation: _hintFadeAnimation,
              scaleAnimation: _hintScaleAnimation,
              isLightTheme: widget.isLightTheme,
              onTap: () {
                _hintAnimationController.reverse().then((_) {
                  if (mounted) setState(() => _showEmojiHint = false);
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color:
                (widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white)
                    .withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarIcon(
            icon: Icons.image_rounded,
            tool: 'photo',
            label: 'Photo',
          ),
          _buildToolbarIcon(
            icon: Icons.videocam_rounded,
            tool: 'video',
            label: 'Video',
          ),
          _buildToolbarIcon(
            icon: Icons.mic_rounded,
            tool: 'audio',
            label: 'Audio',
          ),
          _buildToolbarIcon(
            icon: Icons.brush_rounded,
            tool: 'drawing',
            label: 'Draw',
          ),
          _buildToolbarIcon(
            icon: Icons.star_rounded,
            tool: 'sticker',
            label: 'Sticker',
          ),
          _buildToolbarIcon(
            icon: Icons.text_fields_rounded,
            tool: 'format',
            label: 'Format',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarIcon({
    required IconData icon,
    required String tool,
    required String label,
  }) {
    final isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _selectedTool = isSelected ? null : tool;
        });
        _handleToolSelection(tool);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isLightTheme
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.2))
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (widget.isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.3))
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
        ),
      ),
    );
  }

  /// Build AI Face Assistant at bottom of screen
  Widget _buildAIFaceAssistant() {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    const aiFaceSize = 64.0;
    
    return Positioned(
      bottom: bottomPadding + 80, // Above bottom toolbar
      right: 20,
      child: GestureDetector(
        onTap: _handleAIFaceTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_aiBlinkAnimation, _aiGlowAnimation]),
          builder: (context, child) {
            final closedOpacity = _aiIsActive ? 0.0 : _aiBlinkAnimation.value; // No blinking when active
            final openOpacity = _aiIsActive ? 1.0 : (1.0 - closedOpacity);
            final glowIntensity = _aiGlowAnimation.value;
            
            return Container(
              width: aiFaceSize,
              height: aiFaceSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x80CBB7F5).withValues(alpha: glowIntensity * (_aiIsActive ? 1.0 : 0.7)),
                    blurRadius: _aiIsActive ? 25 : 20,
                    spreadRadius: _aiIsActive ? 5 : 3,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Open eyes (base layer)
                    Opacity(
                      opacity: openOpacity,
                      child: Image.asset(
                        'assets/images/ai_face_open.jpg',
                        width: aiFaceSize,
                        height: aiFaceSize,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: aiFaceSize,
                            height: aiFaceSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE8D5FF),
                            ),
                            child: const Icon(
                              Icons.face_outlined,
                              size: 32,
                              color: Color(0xFF5E3A9E),
                            ),
                          );
                        },
                      ),
                    ),
                    // Closed eyes (blink layer)
                    Opacity(
                      opacity: closedOpacity,
                      child: Image.asset(
                        'assets/images/ai_face_closed.jpg',
                        width: aiFaceSize,
                        height: aiFaceSize,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: aiFaceSize,
                            height: aiFaceSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE8D5FF),
                            ),
                            child: const Icon(
                              Icons.face_outlined,
                              size: 32,
                              color: Color(0xFF5E3A9E),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Handle AI face tap - read diary text and get reflection
  Future<void> _handleAIFaceTap() async {
    // Set active state
    setState(() {
      _aiIsActive = true;
    });
    
    // Read current diary text
    final diaryText = _quillController.document.toPlainText().trim();
    
    // If empty, show gentle prompt
    if (diaryText.isEmpty) {
      setState(() {
        _aiIsActive = false;
      });
      _showAIPromptDialog('Start writing your thoughts, and I\'ll be here to listen and reflect with you 💜');
      return;
    }
    
    // Don't check backend availability here - let the API call handle it
    // This prevents false negatives from health check timeouts
    
    // Show thinking indicator
    _showAIThinkingDialog();
    
    try {
      // Call reflection endpoint
      final reflection = await AIMLApiService().getReflection(diaryText);
      
      // Close thinking dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show reflection response
      if (mounted) {
        _showAIReflectionDialog(reflection);
      }
    } catch (e) {
      debugPrint('🔥 [NEW ENTRY] AI reflection error: $e');
      
      // Close thinking dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Check if it's a connection error
      final errorString = e.toString().toLowerCase();
      String errorMessage;
      
      if (errorString.contains('connection') || 
          errorString.contains('network') || 
          errorString.contains('unavailable') ||
          errorString.contains('refused') ||
          errorString.contains('timeout')) {
        errorMessage = 'I\'m having trouble connecting to the AI server. 💜 Please make sure the backend is running (python run_api.py in ai_engine folder) and try again.';
      } else {
        errorMessage = 'I encountered an issue processing your entry. 💜 Please try again.';
      }
      
      // Show error message
      if (mounted) {
        _showAIPromptDialog(errorMessage);
      }
    } finally {
      // Reset active state after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _aiIsActive = false;
          });
        }
      });
    }
  }

  /// Show AI thinking dialog
  void _showAIThinkingDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isLightTheme ? Colors.white : Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF6B4C93),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reading your entry...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show AI reflection dialog
  void _showAIReflectionDialog(String reflection) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isLightTheme ? Colors.white : Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI face icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6B4C93),
                      const Color(0xFF8B6FA8),
                    ],
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/ai_face_mouth.jpg',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.face_outlined, color: Colors.white, size: 30);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Reflection text
              Text(
                reflection,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  height: 1.5,
                  color: widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Close button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4C93).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Got it',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C93),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show AI prompt dialog (for empty text or errors)
  void _showAIPromptDialog(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isLightTheme ? Colors.white : Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C93),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Keep existing helper widgets: _GlowAnimation, _EmojiHintBubble, _SoulSyncCalendar, _DraggableStickerWidget
// These remain unchanged from the original file

class _GlowAnimation extends StatefulWidget {
  const _GlowAnimation();

  @override
  State<_GlowAnimation> createState() => _GlowAnimationState();
}

class _GlowAnimationState extends State<_GlowAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
            child: Container(
                padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 10,
                  ),
                ],
              ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.green,
                  size: 48,
            ),
          ),
        ),
          );
        },
      ),
    );
  }
}

class _EmojiHintBubble extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<double> scaleAnimation;
  final bool isLightTheme;
  final VoidCallback onTap;

  const _EmojiHintBubble({
    required this.fadeAnimation,
    required this.scaleAnimation,
    required this.isLightTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: GestureDetector(
          onTap: onTap,
            child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
              color: const Color(0xFF5E3A9E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                const Text('👆', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                  Text(
                  'Tap to select your mood',
                    style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF5E3A9E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Calendar widget (simplified - can be copied from original)
class _SoulSyncCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final bool isLightTheme;

  const _SoulSyncCalendar({
    required this.selectedDate,
    required this.onDateSelected,
    required this.isLightTheme,
  });

  @override
  State<_SoulSyncCalendar> createState() => _SoulSyncCalendarState();
}

class _SoulSyncCalendarState extends State<_SoulSyncCalendar> {
  late DateTime _viewingMonth;

  @override
  void initState() {
    super.initState();
    _viewingMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  void _previousMonth() {
          setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month - 1);
    });
  }

  void _nextMonth() {
          setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1);
    });
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_viewingMonth.year, _viewingMonth.month, 1);
    final lastDay = DateTime(_viewingMonth.year, _viewingMonth.month + 1, 0);
    final startOffset = firstDay.weekday % 7;

    final days = <DateTime>[];
    for (int i = 0; i < startOffset; i++) {
      days.add(DateTime(0));
    }
    for (int day = 1; day <= lastDay.day; day++) {
      days.add(DateTime(_viewingMonth.year, _viewingMonth.month, day));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isLightTheme
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.grey[900]!.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _previousMonth,
                    color: widget.isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white,
                  ),
                    Text(
                    DateFormat('MMMM yyyy').format(_viewingMonth),
                      style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _nextMonth,
                    color: widget.isLightTheme
                                ? const Color(0xFF5E3A9E)
                        : Colors.white,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  if (day.year == 0) return const SizedBox.shrink();

                  final isSelected =
                      day.year == widget.selectedDate.year &&
                      day.month == widget.selectedDate.month &&
                      day.day == widget.selectedDate.day;

                  return GestureDetector(
                    onTap: () => widget.onDateSelected(day),
          child: Container(
            decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5E3A9E)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : (widget.isLightTheme
                                      ? const Color(0xFF5E3A9E)
                                      : Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Draggable sticker widget (copy from original - keep as is for now)
class _DraggableStickerWidget extends StatefulWidget {
  final StickerAttachment sticker;
  final int index;
  final bool isLightTheme;
  final bool isSelected;
  final double contentWidth;
  final double contentHeight;
  final VoidCallback onSelect;
  final VoidCallback onDeselect;
  final Function(StickerAttachment) onUpdate;
  final VoidCallback onDelete;

  const _DraggableStickerWidget({
    super.key,
    required this.sticker,
    required this.index,
    required this.isLightTheme,
    required this.isSelected,
    required this.contentWidth,
    required this.contentHeight,
    required this.onSelect,
    required this.onDeselect,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_DraggableStickerWidget> createState() =>
      _DraggableStickerWidgetState();
}

class _DraggableStickerWidgetState extends State<_DraggableStickerWidget> {
  late double _x;
  late double _y;
  late double _size;
  late double _rotation;
  bool _isDragging = false;
  bool _isResizing = false;
  bool _isRotating = false;
  bool _isDeleting = false;

  final double _baseSize = 80.0;
  final double _minSize = 0.5;
  final double _maxSize = 3.0;
  final double _deleteButtonSize = 32.0;
  final double _deleteButtonHitboxPadding = 12.0;

  double _initialSize = 1.0;
  double _initialRotation = 0.0;
  double _initialTwoFingerRotation = 0.0;
  double _initialTwoFingerDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _x = widget.sticker.x.clamp(0.0, 1.0);
    _y = widget.sticker.y.clamp(0.0, 1.0);
    _size = widget.sticker.size.isFinite 
        ? widget.sticker.size.clamp(_minSize, _maxSize) 
        : 1.0;
    _rotation = widget.sticker.rotation.isFinite 
        ? widget.sticker.rotation % 360 
        : 0.0;
    if (_rotation < 0) _rotation += 360;
  }

  @override
  void didUpdateWidget(_DraggableStickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected && oldWidget.isSelected) {
      _isDragging = false;
      _isResizing = false;
      _isRotating = false;
      _isDeleting = false;
    }
  }

  void _updateSticker() {
    widget.onUpdate(
      widget.sticker.copyWith(x: _x, y: _y, size: _size, rotation: _rotation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = widget.contentWidth;
    final contentHeight = widget.contentHeight;
    
    if (contentWidth <= 0 || contentHeight <= 0) {
      return const SizedBox.shrink();
    }
    
    final stickerSize = _baseSize * _size;
    final left = _x * contentWidth - stickerSize / 2;
    final top = _y * contentHeight - stickerSize / 2;
    final maxLeft = (contentWidth - stickerSize).clamp(0.0, double.infinity);
    final maxTop = (contentHeight - stickerSize).clamp(0.0, double.infinity);
    final clampedLeft = left.clamp(0.0, maxLeft);
    final clampedTop = top.clamp(0.0, maxTop);
    
    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: GestureDetector(
        behavior:
            widget.isSelected ||
                _isDragging ||
                _isRotating ||
                _isResizing ||
                _isDeleting
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        onTap: () {
          if (_isResizing || _isRotating || _isDeleting) return;
          if (widget.isSelected) {
            widget.onDeselect();
          } else {
            widget.onSelect();
          }
        },
          onScaleStart: (details) {
          if (_isResizing || _isRotating || _isDeleting) return;

            if (details.pointerCount == 2 && widget.isSelected) {
              _initialSize = _size;
              _initialRotation = _rotation;
              
            final stickerSize = _baseSize * _size;
              final focalPoint = details.focalPoint;
              final localFocalPoint = details.localFocalPoint;
              final stickerCenter = Offset(stickerSize / 2, stickerSize / 2);
              final initialVector = focalPoint - (localFocalPoint + stickerCenter);
              
              if (initialVector.distance > 0) {
                _initialTwoFingerRotation = initialVector.direction;
                _initialTwoFingerDistance = initialVector.distance;
              } else {
                _initialTwoFingerDistance = 0.0;
              }
              
              setState(() {
                _isDragging = false;
                _isRotating = true;
              });
          } else if (details.pointerCount == 1) {
              if (widget.isSelected) {
                FocusScope.of(context).unfocus();
              setState(() => _isDragging = true);
              } else {
                widget.onSelect();
              }
            }
          },
          onScaleUpdate: (details) {
          if (_isResizing || _isRotating || _isDeleting) return;
            
            final stickerSize = _baseSize * _size;
            
            if (details.pointerCount == 2 && widget.isSelected) {
              final scaleChange = details.scale;
              final scaleChangeAbs = (scaleChange - 1.0).abs();
              
              // Calculate angle change for rotation detection
              final focalPoint = details.focalPoint;
              final localFocalPoint = details.localFocalPoint;
              final stickerCenter = Offset(stickerSize / 2, stickerSize / 2);
              final currentVector = focalPoint - (localFocalPoint + stickerCenter);
              
              if (currentVector.distance > 0 && _initialTwoFingerDistance > 0) {
                final currentAngle = currentVector.direction;
                final angleDelta = (currentAngle - _initialTwoFingerRotation) * 180 / 3.14159;
                double normalizedAngle = angleDelta;
                while (normalizedAngle > 180) {
                  normalizedAngle -= 360;
                }
                while (normalizedAngle < -180) {
                  normalizedAngle += 360;
                }
                final normalizedAngleAbs = normalizedAngle.abs();
                
                // Check if rotation is more significant than scaling
                // Use rotation if angle change is significant relative to scale change
                if (normalizedAngleAbs > 3.0 && normalizedAngleAbs > scaleChangeAbs * 50) {
                  // Rotation mode - prioritize rotation
                  if (normalizedAngle.isFinite) {
                    setState(() {
                      final newRotation = (_initialRotation + normalizedAngle) % 360;
                      _rotation = newRotation < 0 ? newRotation + 360 : newRotation;
                      _isRotating = true;
                    });
                    _updateSticker();
                  }
                } else if (scaleChangeAbs > 0.01) {
                  // Scale mode - prioritize resizing
                  final newSize = _initialSize * scaleChange;
                  if (newSize.isFinite) {
                    setState(() {
                      _size = newSize.clamp(_minSize, _maxSize);
                      _isRotating = false;
                    });
                    _updateSticker();
                  }
                } else if (normalizedAngleAbs > 2.0) {
                  // Small rotation when scale change is minimal
                  if (normalizedAngle.isFinite) {
                    setState(() {
                      final newRotation = (_initialRotation + normalizedAngle) % 360;
                      _rotation = newRotation < 0 ? newRotation + 360 : newRotation;
                      _isRotating = true;
                    });
                    _updateSticker();
                  }
                }
              }
          } else if (_isDragging && details.pointerCount == 1) {
              if (contentWidth > 0 && contentHeight > 0) {
                final deltaX = details.focalPointDelta.dx / contentWidth;
                final deltaY = details.focalPointDelta.dy / contentHeight;
                
                if (deltaX.isFinite && deltaY.isFinite) {
                  setState(() {
                    final newX = _x + deltaX;
                    final newY = _y + deltaY;
                    if (newX.isFinite && newY.isFinite) {
                      _x = newX.clamp(0.0, 1.0);
                      _y = newY.clamp(0.0, 1.0);
                    }
                  });
                  _updateSticker();
                }
              }
            }
          },
          onScaleEnd: (details) {
            if (!_isResizing && !_isRotating && !_isDeleting) {
              setState(() {
                _isDragging = false;
                if (details.pointerCount == 2) {
                  _isRotating = false;
                }
                _initialTwoFingerDistance = 0.0;
              });
            }
          },
          child: AnimatedScale(
            scale: _isDragging ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Transform.rotate(
              angle: _rotation * 3.14159 / 180,
              child: Container(
              width: stickerSize,
              height: stickerSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(stickerSize / 2),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Text(
                      widget.sticker.emoji,
                      style: TextStyle(fontSize: stickerSize * 0.7),
                    ),
                  ),
                  if (widget.isSelected)
                    Positioned(
                      top:
                          -(_deleteButtonSize / 2) - _deleteButtonHitboxPadding,
                      left:
                          -(_deleteButtonSize / 2) - _deleteButtonHitboxPadding,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          setState(() {
                            _isDeleting = true;
                            _isDragging = false;
                            _isResizing = false;
                            _isRotating = false;
                          });
                        },
                        onTap: () {
                          widget.onDelete();
                          setState(() => _isDeleting = false);
                        },
                        onTapCancel: () {
                          setState(() => _isDeleting = false);
                        },
                        child: Container(
                          width:
                              _deleteButtonSize +
                              (_deleteButtonHitboxPadding * 2),
                          height:
                              _deleteButtonSize +
                              (_deleteButtonHitboxPadding * 2),
                          alignment: Alignment.center,
                          child: Container(
                            width: _deleteButtonSize,
                            height: _deleteButtonSize,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Sticker Picker Bottom Sheet with Categories
class _StickerPickerBottomSheet extends StatefulWidget {
  final bool isLightTheme;
  final Function(String) onStickerSelected;

  const _StickerPickerBottomSheet({
    required this.isLightTheme,
    required this.onStickerSelected,
  });

  @override
  State<_StickerPickerBottomSheet> createState() => _StickerPickerBottomSheetState();
}

class _StickerPickerBottomSheetState extends State<_StickerPickerBottomSheet> {
  int _selectedCategory = 0;

  // Sticker categories with lots of cute stickers
  static const Map<String, List<String>> stickerCategories = {
    'Hearts': [
      '💜', '❤️', '🧡', '💛', '💚', '💙', '💖', '💗', '💘', '💝', '💞', '💟',
      '❤️‍🔥', '❤️‍🩹', '💕', '💓', '💔', '❣️', '💌', '🫶', '🤍', '🤎', '🖤', '💋', '👄',
    ],
    'Nature': [
      '🌞', '☁️', '🦋', '🌸', '🌈', '🌙', '⭐', '🪐', '❄️', '🌺', '🌻', '🌷', '🌼', '🌊', '🌿', '🌵', '🌴', '🌾', '🌱', '🌲',
      '🌍', '🌎', '🌏', '🌤️', '⛅', '🌦️', '🌧️', '⛈️', '🌩️', '🌨️', '☀️', '🌝', '🌚', '🌛', '🌜', '🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘',
      '🍄', '🍀', '🍃', '🍂', '🍁', '🌰', '🌾', '🌽', '🌹', '🌻', '🌷', '🌺', '🌼', '🌸',
    ],
    'Animals': [
      '🦄', '🦢', '🐰', '🦩', '🐱', '🐶', '🐨', '🐼', '🦁', '🐯', '🐸', '🐷',
      '🐭', '🐹', '🐻', '🐻‍❄️', '🐮', '🐽', '🐊', '🐢', '🦎', '🐍', '🐲', '🐉', '🦕', '🦖',
      '🐳', '🐋', '🐬', '🐟', '🐠', '🐡', '🦈', '🐙', '🐚', '🐌', '🐛', '🐜', '🐝', '🐞', '🦗', '🕷️', '🦂', '🦟',
      '🐴', '🦓', '🦌', '🦬', '🐂', '🐃', '🐄', '🐖', '🐗', '🐏', '🐑', '🐐', '🐪', '🐫', '🦙', '🦒', '🐘', '🦣', '🦏', '🦛',
      '🐁', '🐀', '🐿️', '🦫', '🦔', '🦇', '🦥', '🦦', '🦨', '🦘', '🦡',
      '🐔', '🐓', '🐣', '🐤', '🐥', '🦆', '🦅', '🦉', '🐺',
    ],
    'Objects': [
      '🧸', '🎈', '🎀', '🎁', '🎂', '🍰', '🍭', '🍬', '🍫', '☕', '🍵', '🌮',
      '🎪', '🎭', '🎨', '🖼️', '🖌️', '🖍️', '✏️', '✒️', '🖊️', '🖋️', '📝', '💼', '📁', '📂', '🗂️', '📅', '📆', '🗒️', '🗓️',
      '📇', '📈', '📉', '📊', '📋', '📌', '📍', '📎', '🖇️', '📏', '📐', '✂️', '🗑️', '📦', '📫', '📪', '📬', '📭', '📮', '🗳️',
      '💌', '💍', '💎', '🔮', '🎉', '🎊', '🎋', '🎍', '🎎', '🎏', '🎐', '🎑', '🧧',
      '🎆', '🎇', '✨', '🎃', '🎄', '🎅', '🤶', '🧑‍🎄',
    ],
    'Symbols': [
      '💫', '✨', '🌟', '⭐', '💎', '🔮', '🎪', '🎨', '🎭', '🎬', '🎵', '🎶',
      '☀️', '☄️', '💥', '🔥', '💧', '💦', '☔', '☂️', '⚡', '☃️', '⛄', '🌪️',
      '☮️', '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎',
      '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓',
      '💯', '🔰', '♻️', '✅', '❇️', '✳️', '❎', '🌐', '💠', 'Ⓜ️', '🌀', '💤',
    ],
  };

  List<String> get _currentStickers {
    if (_selectedCategory >= 0 && _selectedCategory < stickerCategories.length) {
      return stickerCategories.values.elementAt(_selectedCategory);
    }
    return stickerCategories.values.first;
  }
  
  List<String> get _categoryNames => stickerCategories.keys.toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: widget.isLightTheme
            ? const Color(0xFFF8F4FF).withValues(alpha: 0.95)
            : Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Stickers',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: widget.isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white,
                  ),
                ),
              ),
              // Category tabs (horizontally scrollable)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categoryNames.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (widget.isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white)
                              : (widget.isLightTheme
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (widget.isLightTheme
                                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.3)),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                        _categoryNames[index],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? (widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E))
                                  : (widget.isLightTheme
                                      ? const Color(0xFF5E3A9E)
                                      : Colors.white),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Sticker grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _currentStickers.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onStickerSelected(_currentStickers[index]);
                  },
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.isLightTheme
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _currentStickers[index],
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
      ),
    );
  }
}

// Audio Recording Widget
class _AudioRecordingWidget extends StatefulWidget {
  final bool isLightTheme;
  final Function(String) onAudioRecorded;
  final VoidCallback onClose;

  const _AudioRecordingWidget({
    required this.isLightTheme,
    required this.onAudioRecorded,
    required this.onClose,
  });

  @override
  State<_AudioRecordingWidget> createState() => _AudioRecordingWidgetState();
}

class _AudioRecordingWidgetState extends State<_AudioRecordingWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final filePath = path.join(appDir.path, 'diary_audio', fileName);
        await Directory(path.dirname(filePath)).create(recursive: true);

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _audioRecorder.stop();
      _recordingTimer?.cancel();
      setState(() {
        _isRecording = false;
      });

      if (filePath != null && mounted) {
        widget.onAudioRecorded(filePath);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error stopping recording: $e')));
      }
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(filePath);
        final savedPath = path.join(appDir.path, 'diary_audio', fileName);
        await Directory(path.dirname(savedPath)).create(recursive: true);
        await File(filePath).copy(savedPath);

        if (!mounted) return;
        widget.onAudioRecorded(savedPath);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking audio file: $e')));
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: widget.isLightTheme
            ? const Color(0xFFF8F4FF).withValues(alpha: 0.95)
            : Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Recording',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: widget.isLightTheme
              ? const Color(0xFF5E3A9E)
              : Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isRecording) ...[
                      GestureDetector(
                        onTap: _startRecording,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to start recording',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _pickAudioFile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isLightTheme
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.isLightTheme
                                  ? const Color(
                                      0xFF5E3A9E,
                                    ).withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                color: widget.isLightTheme
                ? const Color(0xFF5E3A9E)
                                    : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add Audio File',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: widget.isLightTheme
            ? const Color(0xFF5E3A9E)
            : Colors.white,
      ),
                              ),
                            ],
                  ),
                ),
              ),
                    ] else ...[
                      Text(
                        _formatDuration(_recordingDuration),
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E)
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _stopRecording,
              child: Container(
                width: 80,
                height: 80,
                          decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
        );
  }
}

// Drawing data model
class DrawingPoint {
  final Offset point;
  final Paint paint;

  DrawingPoint(this.point, this.paint);

  Map<String, dynamic> toJson() {
    return {
      'x': point.dx,
      'y': point.dy,
      'color':
          paint.color.r.toInt() << 16 |
          paint.color.g.toInt() << 8 |
          paint.color.b.toInt(),
      'strokeWidth': paint.strokeWidth,
    };
  }

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      Offset(json['x'] as double, json['y'] as double),
      Paint()
        ..color = Color(json['color'] as int)
        ..strokeWidth = json['strokeWidth'] as double
        ..strokeCap = StrokeCap.round,
    );
  }
}

// Drawing Canvas Screen
class _DrawingCanvasScreen extends StatefulWidget {
  final bool isLightTheme;
  final Function(String, String?) onDrawingSaved;

  const _DrawingCanvasScreen({
    required this.isLightTheme,
    required this.onDrawingSaved,
  });

  @override
  State<_DrawingCanvasScreen> createState() => _DrawingCanvasScreenState();
}

class _DrawingCanvasScreenState extends State<_DrawingCanvasScreen> {
  List<DrawingPoint?> _points = [];
  Color _currentColor = Colors.black;
  double _strokeWidth = 3.0;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveDrawing() async {
    try {
      final boundary =
          _canvasKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = path.join(
        appDir.path,
        'diary_drawings',
        'drawing_$timestamp.png',
      );
      await Directory(path.dirname(imagePath)).create(recursive: true);
      await File(imagePath).writeAsBytes(pngBytes);

      if (!mounted) return;
      widget.onDrawingSaved(imagePath, null);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving drawing: $e')));
      }
    }
  }

  void _clearCanvas() {
      setState(() {
      _points.clear();
    });
  }

  void _undo() {
    if (_points.isEmpty) return;
      setState(() {
      // Remove points until we hit a null (which marks the end of a stroke)
      do {
        _points.removeLast();
      } while (_points.isNotEmpty && _points.last != null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isLightTheme ? Colors.white : Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Draw',
                            style: GoogleFonts.poppins(
            color: widget.isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                              fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              color: widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
            onPressed: _undo,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
            onPressed: _clearCanvas,
                    ),
                    IconButton(
            icon: Icon(
              Icons.check_rounded,
              color: widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
            onPressed: _saveDrawing,
                    ),
                  ],
                ),
      body: Column(
        children: [
          // Color picker
                  Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Color:',
                                style: GoogleFonts.poppins(
                    color: widget.isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                            Colors.black,
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.yellow,
                            Colors.orange,
                            Colors.purple,
                            Colors.pink,
                            Colors.brown,
                            Colors.grey,
                          ].map((color) {
                        return GestureDetector(
                              onTap: () =>
                                  setState(() => _currentColor = color),
                          child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 36,
                                height: 36,
                            decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _currentColor == color
                                        ? (widget.isLightTheme
                                              ? const Color(0xFF5E3A9E)
                                              : Colors.white)
                                  : Colors.transparent,
                                    width: 3,
                              ),
                            ),
                          ),
                        );
                          }).toList(),
                    ),
                    ),
                  ),
                ],
            ),
          ),
          // Stroke width slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Size:',
                                style: GoogleFonts.poppins(
                    color: widget.isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white,
                                  fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 1.0,
                    max: 10.0,
                    activeColor: widget.isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white,
                    onChanged: (value) => setState(() => _strokeWidth = value),
                  ),
                ),
              ],
            ),
          ),
          // Canvas
          Expanded(
                      child: Container(
              margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _points.add(
                          DrawingPoint(
                            details.localPosition,
                            Paint()
                              ..color = _currentColor
                              ..strokeWidth = _strokeWidth
                              ..strokeCap = StrokeCap.round,
                          ),
                        );
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _points.add(
                          DrawingPoint(
                            details.localPosition,
                            Paint()
                              ..color = _currentColor
                              ..strokeWidth = _strokeWidth
                              ..strokeCap = StrokeCap.round,
                          ),
                        );
                      });
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _points.add(null);
                      });
                    },
                    child: CustomPaint(
                      painter: _DrawingPainter(_points),
                      child: Container(),
                    ),
            ),
          ),
        ),
            ),
          ),
        ],
      ),
    );
  }
}

// Drawing Painter
class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  _DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.point,
          points[i + 1]!.point,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}

// Custom Audio Block Embed
class AudioBlockEmbed extends quill.CustomBlockEmbed {
  const AudioBlockEmbed(String value) : super(audioType, value);

  static const String audioType = 'audio';

  String get audioPath => data;
}

// Audio Embed Builder
class AudioEmbedBuilder extends quill.EmbedBuilder {
  final bool isLightTheme;
  final Function(String) onDelete;

  AudioEmbedBuilder({required this.isLightTheme, required this.onDelete});

  @override
  String get key => 'audio';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final audioPath = embedContext.node.value.data as String;
    return _AudioPlayerWidget(
      audioPath: audioPath,
      isLightTheme: isLightTheme,
      onDelete: () => onDelete(audioPath),
    );
  }
}

// Audio Player Widget
class _AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final bool isLightTheme;
  final VoidCallback onDelete;

  const _AudioPlayerWidget({
    required this.audioPath,
    required this.isLightTheme,
    required this.onDelete,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
          setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      } else {
      await _audioPlayer.play(DeviceFileSource(widget.audioPath));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final audioWidth = screenWidth * 0.75;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Container(
            width: audioWidth,
            padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isLightTheme
                  ? const Color(0xFFF8F4FF).withValues(alpha: 0.8)
                  : Colors.grey[900]!.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isLightTheme
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isLightTheme ? 0.08 : 0.2,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
            children: [
                // Play/Pause button
                GestureDetector(
                  onTap: _togglePlayback,
                  child: Container(
                width: 40,
                    height: 40,
                decoration: BoxDecoration(
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: widget.isLightTheme
                          ? Colors.white
                          : const Color(0xFF5E3A9E),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Audio info and progress
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Recording',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isLightTheme
                                        ? const Color(0xFF5E3A9E)
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_duration.inSeconds > 0)
                        Row(
                                children: [
                                  Text(
                              _formatDuration(_position),
                                    style: GoogleFonts.poppins(
                                fontSize: 11,
                                color:
                                    (widget.isLightTheme
                                              ? const Color(0xFF5E3A9E)
                                            : Colors.white)
                                        .withValues(alpha: 0.6),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _duration.inSeconds > 0
                                    ? _position.inSeconds.toDouble()
                                    : 0.0,
                                min: 0.0,
                                max: _duration.inSeconds.toDouble(),
                                onChanged: (value) {
                                  _audioPlayer.seek(
                                    Duration(seconds: value.toInt()),
                                  );
                                },
                                activeColor: widget.isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white,
                                inactiveColor:
                                    (widget.isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                        : Colors.white)
                                        .withValues(alpha: 0.3),
                              ),
                            ),
                                  Text(
                              _formatDuration(_duration),
                                    style: GoogleFonts.poppins(
                                fontSize: 11,
                                color:
                                    (widget.isLightTheme
                                              ? const Color(0xFF5E3A9E)
                                            : Colors.white)
                                        .withValues(alpha: 0.6),
                                      ),
                                    ),
                                ],
                        )
                      else
                      Text(
                          'Tap to play',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                (widget.isLightTheme
                                            ? const Color(0xFF5E3A9E)
                                            : Colors.white)
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                // Delete button
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Custom Image Embed Builder
// ============================================================================

class ImageEmbedBuilder extends quill.EmbedBuilder {
  final bool isLightTheme;
  final Function(String) onDelete;
  final Function(String) onTap;

  ImageEmbedBuilder({
    required this.isLightTheme,
    required this.onDelete,
    required this.onTap,
  });

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final imagePath = embedContext.node.value.data as String;
    final screenWidth = MediaQuery.of(context).size.width;
    final mediaWidth = screenWidth * 0.75; // ¾ of screen width
    const mediaHeight = 230.0; // Fixed height for landscape rectangular

    // Check if this is a drawing (drawings are saved in 'diary_drawings' folder)
    final isDrawing =
        imagePath.contains('diary_drawings') || imagePath.contains('drawing_');

    // Use white background for drawings, themed background for regular images
    final containerColor = isDrawing
        ? Colors.white
        : (isLightTheme
              ? const Color(0xFFF8F4FF).withValues(alpha: 0.8)
              : Colors.grey[900]!.withValues(alpha: 0.6));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: GestureDetector(
            onTap: () => onTap(imagePath),
            child: Container(
              width: mediaWidth,
              height: mediaHeight,
      decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
        color: isLightTheme
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isLightTheme ? 0.08 : 0.2,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
            children: [
                    // White background for drawings
                    if (isDrawing)
              Container(
                        width: mediaWidth,
                        height: mediaHeight,
                        color: Colors.white,
                      ),
                    // Image
                    SizedBox(
                      width: mediaWidth,
                      height: mediaHeight,
                      child: Image.file(
                        File(imagePath),
                        width: mediaWidth,
                        height: mediaHeight,
                        fit: isDrawing ? BoxFit.contain : BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: mediaWidth,
                          height: mediaHeight,
                    color: isLightTheme
                              ? Colors.grey.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.4),
                          child: Icon(
                            Icons.image_rounded,
                            size: 48,
                            color: isLightTheme
                                ? Colors.grey[600]
                                : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
                    ),
                    // Delete button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => onDelete(imagePath),
                      child: Container(
                          padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Custom Video Embed Builder
// ============================================================================

class VideoEmbedBuilder extends quill.EmbedBuilder {
  final bool isLightTheme;
  final Function(String) onDelete;
  final Function(String) onTap;

  VideoEmbedBuilder({
    required this.isLightTheme,
    required this.onDelete,
    required this.onTap,
  });

  @override
  String get key => 'video';
  
  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final videoPath = embedContext.node.value.data as String;
    final screenWidth = MediaQuery.of(context).size.width;
    final mediaWidth = screenWidth * 0.75; // ¾ of screen width
    const mediaHeight = 230.0; // Fixed height for landscape rectangular

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: GestureDetector(
            onTap: () => onTap(videoPath),
            child: Container(
              width: mediaWidth,
              height: mediaHeight,
      decoration: BoxDecoration(
                color: isLightTheme
                    ? const Color(0xFFF8F4FF).withValues(alpha: 0.8)
                    : Colors.grey[900]!.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLightTheme
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isLightTheme ? 0.08 : 0.2,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Video thumbnail
                    SizedBox(
                      width: mediaWidth,
                      height: mediaHeight,
                      child: _VideoThumbnailWidget(videoPath: videoPath),
                    ),
                    // Play icon overlay
                    Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_filled_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                    // Delete button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => onDelete(videoPath),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Video Thumbnail Widget
// ============================================================================

class _VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;

  const _VideoThumbnailWidget({required this.videoPath});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  File? _thumbnailFile;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 800,
        quality: 90,
        timeMs: 100,
      );
      if (mounted && thumbnailPath != null) {
        setState(() {
          _thumbnailFile = File(thumbnailPath);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 230,
        color: Colors.grey.withValues(alpha: 0.2),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_thumbnailFile != null && _thumbnailFile!.existsSync()) {
      return Image.file(
        _thumbnailFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 230,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: 230,
      color: Colors.grey.withValues(alpha: 0.3),
      child: const Icon(
        Icons.video_file_rounded,
        size: 48,
        color: Colors.white,
      ),
    );
  }
}

// ============================================================================
// Video Player Widget (for fullscreen)
// ============================================================================

class _VideoPlayerWidget extends StatefulWidget {
  final String videoPath;

  const _VideoPlayerWidget({required this.videoPath});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoPath = widget.videoPath;

      // Check if it's a URL (cloud storage) or local file path
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        // Cloud URL - use network controller
        _controller = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        // Local file path
        final file = File(videoPath);
        if (!await file.exists()) {
    setState(() {
            _hasError = true;
            _errorMessage = 'Video file not found';
          });
          return;
        }
        _controller = VideoPlayerController.file(file);
      }

      await _controller!.initialize();

      if (mounted) {
      setState(() {
          _isInitialized = true;
        });
        _controller!.play();
      }
    } catch (e) {
      debugPrint('🔥 [VIDEO PLAYER ERROR] Failed to initialize video: $e');
      if (mounted) {
    setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Error loading video',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
