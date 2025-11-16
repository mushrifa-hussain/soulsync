import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/services/quill_migration_service.dart';
import 'package:soulsync_dairyapp/widgets/quill_text_editor.dart';
import 'package:soulsync_dairyapp/widgets/editor_toolbar.dart';

/// Text formatting data class
class TextFormat {
  final int start;
  final int end;
  final String fontFamily;
  final String fontSize;
  final Color color;
  final TextAlign alignment;

  TextFormat({
    required this.start,
    required this.end,
    required this.fontFamily,
    required this.fontSize,
    required this.color,
    required this.alignment,
  });

  TextFormat copyWith({
    int? start,
    int? end,
    String? fontFamily,
    String? fontSize,
    Color? color,
    TextAlign? alignment,
  }) {
    return TextFormat(
      start: start ?? this.start,
      end: end ?? this.end,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      alignment: alignment ?? this.alignment,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'color': color.value, // Store as int (ARGB)
      'alignment': alignment.index, // Store as int (0=left, 1=right, 2=center, etc.)
    };
  }

  /// Create from JSON
  factory TextFormat.fromJson(Map<String, dynamic> json) {
    return TextFormat(
      start: json['start'] as int,
      end: json['end'] as int,
      fontFamily: json['fontFamily'] as String,
      fontSize: json['fontSize'] as String,
      color: Color(json['color'] as int),
      alignment: TextAlign.values[json['alignment'] as int],
    );
  }
}

class NewEntryScreen extends StatefulWidget {
  final Color? themeBottomColor;
  final bool isLightTheme;
  final DiaryEntry? existingEntry; // For editing existing entries
  final DateTime? initialDate; // Initial date for new entries
  final MediaAttachment? scrollToMedia; // Media to scroll to when opening entry
  final String? initialMood; // Initial mood for new entries

  const NewEntryScreen({
    super.key,
    this.themeBottomColor,
    required this.isLightTheme,
    this.existingEntry,
    this.initialDate,
    this.scrollToMedia,
    this.initialMood,
  });

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _contentFocusNode = FocusNode();
  String? _selectedMood;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late DateTime _selectedDate;
  bool _showCalendar = false;
  late AnimationController _calendarController;
  late Animation<double> _calendarScaleAnimation;
  late Animation<double> _calendarOpacityAnimation;

  final List<String> _moods = ['😊', '😢', '😴', '😍', '🤔', '😌', '😎', '🥰', '😇', '😋'];
  
  // Toolbar state
  String? _selectedTool; // Track which tool is currently active
  bool _showFormattingToolbar = false; // Track if formatting toolbar is visible
  
  // Media attachments (legacy - kept for backward compatibility during migration)
  List<MediaAttachment> _mediaAttachments = [];
  
  // Sticker attachments (draggable)
  List<StickerAttachment> _stickerAttachments = [];
  int? _selectedStickerIndex; // Track which sticker is currently selected (only one at a time)
  
  // Audio attachments (legacy - kept for backward compatibility during migration)
  // ignore: prefer_final_fields
  List<MediaAttachment> _audioAttachments = [];
  
  // Ordered content blocks (new format)
  List<ContentBlock> _contentBlocks = [];
  
  // Quill controllers for text fields below media items
  final Map<int, quill.QuillController> _mediaTextControllers = {};
  final Map<int, FocusNode> _mediaTextFocusNodes = {};
  final Map<int, bool> _mediaTextUpdatingFlags = {}; // Track updating state to prevent loops
  
  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingAudio;
  
  // List mode tracking (deprecated - Quill handles lists natively)
  String? _currentListPrefix;
  int _listItemNumber = 0;
  bool _isHandlingListContinuation = false;
  
  // Emoji hint visibility
  bool _showEmojiHint = true; // Show hint until user interacts
  late AnimationController _hintAnimationController;
  late Animation<double> _hintFadeAnimation;
  late Animation<double> _hintScaleAnimation;
  
  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    
    // Hint bubble animation controller
    _hintAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _hintFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _hintAnimationController,
        curve: Curves.easeOut,
      ),
    );
    _hintScaleAnimation = Tween<double>(begin: 1.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _hintAnimationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Start hint animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _showEmojiHint && _selectedMood == null) {
        _hintAnimationController.forward();
      }
    });
    
    // Calendar animation controller
    _calendarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _calendarScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _calendarController,
        curve: Curves.easeOutCubic,
      ),
    );
    _calendarOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _calendarController,
        curve: Curves.easeOut,
      ),
    );
    
    // Initialize Quill controller
    quill.Document? document;
    
    // If editing, pre-fill the form
    if (widget.existingEntry != null) {
      _titleController.text = widget.existingEntry!.title;
      _selectedMood = widget.existingEntry!.mood;
      _selectedDate = widget.existingEntry!.timestamp;
      _mediaAttachments = List<MediaAttachment>.from(widget.existingEntry!.mediaAttachments);
      _stickerAttachments = List<StickerAttachment>.from(widget.existingEntry!.stickerAttachments);
      
      // Load Quill delta if available, otherwise migrate from old format
      if (widget.existingEntry!.quillDelta != null) {
        // Quill delta is stored as Map, but Document.fromJson expects List
        final deltaJson = widget.existingEntry!.quillDelta!;
        if (deltaJson.containsKey('ops') && deltaJson['ops'] is List) {
          document = quill.Document.fromJson(deltaJson['ops'] as List);
        } else {
          // Fallback: create from plain text
          document = quill.Document()..insert(0, widget.existingEntry!.content);
        }
      } else if (widget.existingEntry!.textFormats.isNotEmpty) {
        // Migrate old format to Quill
        final migratedEntry = QuillMigrationService.migrateEntry(widget.existingEntry!);
        if (migratedEntry.quillDelta != null) {
          final deltaJson = migratedEntry.quillDelta!;
          if (deltaJson.containsKey('ops') && deltaJson['ops'] is List) {
            document = quill.Document.fromJson(deltaJson['ops'] as List);
          } else {
            document = quill.Document()..insert(0, widget.existingEntry!.content);
          }
        }
      }
      
      // If no document yet, create from plain text
      if (document == null) {
        document = quill.Document()..insert(0, widget.existingEntry!.content);
      }
    } else {
      // Set initial mood if provided (from mood selection dialog)
      if (widget.initialMood != null) {
        _selectedMood = widget.initialMood;
      }
      // Use initialDate if provided, otherwise use current date
      _selectedDate = widget.initialDate ?? DateTime.now();
      // Create empty document for new entry
      document = quill.Document();
    }
    
    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _contentFocusNode.dispose();
    _fadeController.dispose();
    _calendarController.dispose();
    _hintAnimationController.dispose();
    _audioPlayer.dispose();
    // Dispose media text controllers and focus nodes
    for (final controller in _mediaTextControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _mediaTextFocusNodes.values) {
      focusNode.dispose();
    }
    _mediaTextControllers.clear();
    _mediaTextFocusNodes.clear();
    super.dispose();
  }

  Color _getBackgroundColor() {
    if (widget.themeBottomColor != null) {
      // Lighten the theme color by 10-15%
      final color = widget.themeBottomColor!;
      return Color.fromRGBO(
        ((color.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        ((color.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        ((color.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
        1.0,
      );
    }
    return const Color(0xFFE8D5FF); // Default soft pastel lavender
  }

  String _getFormattedDate() {
    // Format for display in header (includes year)
    return DateFormat('d MMM yyyy').format(_selectedDate);
  }
  
  String _getFormattedDateForStorage() {
    // Format for storage (day and month only, year comes from timestamp)
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
  
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF8F4FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (!mounted) return;
              Navigator.of(context).pop(); // Close dialog
              if (widget.existingEntry != null) {
                // Delete the entry
                // Delete via provider for automatic synchronization
                final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
                await provider.deleteEntry(widget.existingEntry!.id);
                // Return to home/calendar with deleted entry for undo
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

  Future<void> _saveEntry() async {
    final plainText = _quillController.document.toPlainText();
    if (_titleController.text.trim().isEmpty && plainText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title or content')),
      );
      return;
    }

    // Get Quill delta for storage
    // toDelta().toJson() returns a Map with 'ops' key
    final deltaJson = _quillController.document.toDelta().toJson();
    // Ensure it's a Map<String, dynamic>
    final quillDelta = deltaJson is Map<String, dynamic> 
        ? deltaJson 
        : {'ops': deltaJson};
    
    final entry = DiaryEntry(
      id: _isEditing 
          ? widget.existingEntry!.id // Keep existing ID when editing
          : DateTime.now().millisecondsSinceEpoch.toString(), // New ID for new entries
      date: _getFormattedDateForStorage(), // Store only day and month
      title: _titleController.text.trim().isEmpty ? 'Untitled' : _titleController.text.trim(),
      content: plainText.trim(), // Plain text for backward compatibility
      mood: _selectedMood ?? '😊',
      timestamp: _selectedDate, // Full timestamp for grouping and sorting
      mediaAttachments: _mediaAttachments, // Include media attachments
      stickerAttachments: _stickerAttachments, // Include sticker attachments
      quillDelta: quillDelta as Map<String, dynamic>?, // Quill delta for rich text
    );

    try {
      // Save via provider for automatic synchronization
      final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
      await provider.saveEntry(entry);
      
      // Show success animation with glow effect
      if (mounted) {
        // Show glow animation overlay
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          builder: (context) => const _GlowAnimation(),
        );
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          Navigator.of(context).pop(); // Close glow animation
          Navigator.of(context).pop(true); // Return to home/calendar
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e')),
        );
      }
    }
  }

  void _showMoodSelector() {
    // Hide hint when user taps emoji section
    if (_showEmojiHint) {
      _hintAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showEmojiHint = false;
          });
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
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _moods.map((mood) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = mood;
                    });
                    // Hide hint when emoji is selected
                    if (_showEmojiHint) {
                      _hintAnimationController.reverse().then((_) {
                        if (mounted) {
                          setState(() {
                            _showEmojiHint = false;
                          });
                        }
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedMood == mood
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: _selectedMood == mood
                            ? const Color(0xFF5E3A9E)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        mood,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
          // Hide emoji hint when user taps anywhere
          if (_showEmojiHint) {
            setState(() {
              _showEmojiHint = false;
            });
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: backgroundColor,
          resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Three-dot menu (only show Delete if editing existing entry)
            if (_isEditing)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: widget.isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white,
                ),
                color: const Color(0xFFF8F4FF), // Soft pastel background
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
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
                  if (value == 'delete') {
                    _showDeleteConfirmation();
                  }
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
              // Fixed top bar with date and save button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus(); // Close keyboard
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
                            color: widget.isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.7),
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
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              ),
              // Mood selector button (fixed at top)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                color: (widget.isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                        : Colors.white)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Emoji interaction hint bubble (only show if no emoji selected)
                    if (_showEmojiHint && _selectedMood == null)
                      _EmojiHintBubble(
                        fadeAnimation: _hintFadeAnimation,
                        scaleAnimation: _hintScaleAnimation,
                        isLightTheme: widget.isLightTheme,
                        onTap: () {
                          // Hide hint when tapped
                          _hintAnimationController.reverse().then((_) {
                            if (mounted) {
                              setState(() {
                                _showEmojiHint = false;
                              });
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              // Scrollable content area (Title + Content)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = constraints.maxWidth;
                    final contentHeight = constraints.maxHeight;
                    return Stack(
                      children: [
                        // Scrollable content (title, text and media in unified order)
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title field inside scrollable area
                              Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 12),
                                child: TextField(
                                  controller: _titleController,
                                  onTap: () {
                                    // Deselect stickers when user taps on title field
                                    if (_selectedStickerIndex != null) {
                                      setState(() {
                                        _selectedStickerIndex = null;
                                      });
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
                                      color: (widget.isLightTheme
                                              ? const Color(0xFF5E3A9E)
                                              : Colors.white)
                                          .withValues(alpha: 0.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              // Content (text and media)
                              _buildUnifiedContent(),
                            ],
                          ),
                        ),
                        // Note: Sticker deselection is handled when user taps on text field or scrolls
                        // No blocking GestureDetector needed - allows text input to work freely
                        // Stickers overlay - draggable floating elements
                        // Positioned widgets are direct children of this Stack
                        ..._stickerAttachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final sticker = entry.value;
                          return _DraggableStickerWidget(
                            key: ValueKey('sticker_$index'),
                            sticker: sticker,
                            index: index,
                            isLightTheme: widget.isLightTheme,
                            isSelected: _selectedStickerIndex == index,
                            contentWidth: contentWidth,
                            contentHeight: contentHeight,
                            onSelect: () {
                              // Unfocus text fields to hide cursor and close keyboard
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _selectedStickerIndex = index;
                              });
                            },
                            onDeselect: () {
                              setState(() {
                                _selectedStickerIndex = null;
                              });
                            },
                            onUpdate: (updatedSticker) {
                              setState(() {
                                _stickerAttachments[index] = updatedSticker;
                              });
                            },
                            onDelete: () {
                              setState(() {
                                _stickerAttachments.removeAt(index);
                                if (_selectedStickerIndex == index) {
                                  _selectedStickerIndex = null;
                                } else if (_selectedStickerIndex != null && _selectedStickerIndex! > index) {
                                  _selectedStickerIndex = _selectedStickerIndex! - 1;
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
              // Bottom toolbar
              _buildBottomToolbar(),
            ],
          ),
        ),
            // Persistent formatting toolbar (above keyboard)
            if (_showFormattingToolbar)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: EditorToolbar(
                  controller: _quillController,
                  onDone: _hideFormattingToolbar,
                  onCancel: _hideFormattingToolbar,
          ),
        ),
            // Custom calendar dropdown
            if (_showCalendar)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus(); // Close keyboard
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
                        FocusScope.of(context).unfocus(); // Close keyboard
                        _selectDate(date);
                      },
                      isLightTheme: widget.isLightTheme,
                    ),
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  /// Build bottom toolbar with 8 tools
  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent, // Keep transparent to show theme background
        border: Border(
          top: BorderSide(
            color: widget.isLightTheme
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.1),
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
            icon: Icons.star_rounded,
            tool: 'sticker',
            label: 'Sticker',
          ),
          _buildToolbarIcon(
            icon: Icons.emoji_emotions_rounded,
            tool: 'emoji',
            label: 'Emoji',
          ),
          _buildToolbarIcon(
            icon: Icons.text_fields_rounded,
            tool: 'font',
            label: 'Font',
          ),
          _buildToolbarIcon(
            icon: Icons.format_list_bulleted_rounded,
            tool: 'list',
            label: 'List',
          ),
          _buildToolbarIcon(
            icon: Icons.mic_rounded,
            tool: 'audio',
            label: 'Audio',
          ),
          _buildToolbarIcon(
            icon: Icons.edit_rounded,
            tool: 'draw',
            label: 'Draw',
          ),
        ],
      ),
    );
  }

  /// Build individual toolbar icon
  Widget _buildToolbarIcon({
    required IconData icon,
    required String tool,
    required String label,
  }) {
    final isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Close keyboard
        setState(() {
          if (_selectedTool == tool) {
            _selectedTool = null; // Toggle off
          } else {
            _selectedTool = tool;
          }
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white)
                        .withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: widget.isLightTheme
              ? const Color(0xFF5E3A9E)
              : Colors.white,
        ),
      ),
    );
  }

  /// Handle tool selection
  void _handleToolSelection(String tool) {
    switch (tool) {
      case 'photo':
        _handlePhotoUpload();
        break;
      case 'sticker':
        _handleStickerSelection();
        break;
      case 'emoji':
        _handleEmojiPicker();
        break;
      case 'font':
        _showQuillFormattingToolbar();
        break;
      case 'list':
        _handleListInsert();
        break;
      case 'audio':
        _handleAudioRecording();
        break;
      case 'draw':
        _handleDrawing();
        break;
    }
  }

  /// Photo upload handler
  Future<void> _handlePhotoUpload() async {
    // Dismiss keyboard before showing dialog
    FocusScope.of(context).unfocus();
    
    final ImagePicker picker = ImagePicker();
    
    // Show first dialog to choose Photo or Video
    final mediaType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
                    'Select Media',
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
                      Icons.photo_rounded,
                      color: widget.isLightTheme
                          ? const Color(0xFF5E3A9E)
                          : Colors.white,
                    ),
                    title: Text(
                      'Photo',
                      style: GoogleFonts.poppins(
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, 'photo'),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.videocam_rounded,
                      color: widget.isLightTheme
                          ? const Color(0xFF5E3A9E)
                          : Colors.white,
                    ),
                    title: Text(
                      'Video',
                      style: GoogleFonts.poppins(
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, 'video'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    if (mediaType == null) return;

    
    // Show second dialog to choose Camera or Gallery
    if (!mounted) return;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
                    mediaType == 'photo' ? 'Select Photo Source' : 'Select Video Source',
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
    
    if (source != null) {
      if (mediaType == 'photo') {
        await _pickImage(picker, source);
      } else {
        await _pickVideo(picker, source);
      }
    }
  }

  Future<void> _pickImage(ImagePicker picker, ImageSource source) async {
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
        
        // Get current text length for position tracking
        final currentTextLength = _quillController.document.toPlainText().length;
        final insertionPosition = currentTextLength;
        
        setState(() {
          _mediaAttachments.add(MediaAttachment(
            path: savedPath,
            isVideo: false,
            position: insertionPosition,
          ));
          _selectedTool = null;
        });
        
        // Move cursor to below the media - add newlines and position cursor at end
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              // Get document length (character count)
              final docLength = _quillController.document.length;
              
              // Ensure we have a valid document
              if (docLength == 0) {
                // Empty document - insert at position 0
                _quillController.document.insert(0, '\n\n');
                _quillController.updateSelection(
                  TextSelection.collapsed(offset: 2),
                  quill.ChangeSource.local,
                );
              } else {
                // Valid document - insert at the end
                // Use length-1 as the last valid position for insertion
                final insertPos = (docLength - 1).clamp(0, docLength - 1);
                _quillController.document.insert(insertPos, '\n\n');
                // Position cursor at the end
                final newLength = _quillController.document.length;
                _quillController.updateSelection(
                  TextSelection.collapsed(offset: newLength > 0 ? newLength - 1 : 0),
                  quill.ChangeSource.local,
                );
              }
            } catch (e) {
              debugPrint('🔥 [IMAGE ERROR] Error inserting newlines: $e');
              // Fallback: just position cursor at end if document exists
              try {
                final docLength = _quillController.document.length;
                if (docLength > 0) {
                  _quillController.updateSelection(
                    TextSelection.collapsed(offset: docLength - 1),
                    quill.ChangeSource.local,
                  );
                }
              } catch (e2) {
                debugPrint('🔥 [IMAGE ERROR] Fallback also failed: $e2');
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking image: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  Future<void> _pickVideo(ImagePicker picker, ImageSource source) async {
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
        
        // Get current text length for position tracking
        final currentTextLength = _quillController.document.toPlainText().length;
        final insertionPosition = currentTextLength;
        
        setState(() {
          _mediaAttachments.add(MediaAttachment(
            path: savedPath,
            isVideo: true,
            position: insertionPosition,
          ));
          _selectedTool = null;
        });
        
        // Move cursor to below the media - add newlines and position cursor at end
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              // Get document length (character count)
              final docLength = _quillController.document.length;
              
              // Ensure we have a valid document
              if (docLength == 0) {
                // Empty document - insert at position 0
                _quillController.document.insert(0, '\n\n');
                _quillController.updateSelection(
                  TextSelection.collapsed(offset: 2),
                  quill.ChangeSource.local,
                );
              } else {
                // Valid document - insert at the end
                // Use length-1 as the last valid position for insertion
                final insertPos = (docLength - 1).clamp(0, docLength - 1);
                _quillController.document.insert(insertPos, '\n\n');
                // Position cursor at the end
                final newLength = _quillController.document.length;
                _quillController.updateSelection(
                  TextSelection.collapsed(offset: newLength > 0 ? newLength - 1 : 0),
                  quill.ChangeSource.local,
                );
              }
            } catch (e) {
              debugPrint('🔥 [VIDEO ERROR] Error inserting newlines: $e');
              // Fallback: just position cursor at end if document exists
              try {
                final docLength = _quillController.document.length;
                if (docLength > 0) {
                  _quillController.updateSelection(
                    TextSelection.collapsed(offset: docLength - 1),
                    quill.ChangeSource.local,
                  );
                }
              } catch (e2) {
                debugPrint('🔥 [VIDEO ERROR] Fallback also failed: $e2');
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking video: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  /// Sticker selection handler
  void _handleStickerSelection() {
    // Dismiss keyboard before showing sticker picker
    FocusScope.of(context).unfocus();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _StickerPickerBottomSheet(
        isLightTheme: widget.isLightTheme,
        onStickerSelected: (sticker) {
          Navigator.pop(context);
          // Place sticker at center of visible area by default
          // User can then drag it to desired position
          setState(() {
            _stickerAttachments.add(StickerAttachment(
              emoji: sticker,
              x: 0.5, // Center horizontally
              y: 0.4, // Slightly above center
              size: 1.0,
              rotation: 0.0,
            ));
            _selectedTool = null;
          });
        },
      ),
    );
  }

  /// Emoji picker handler
  void _handleEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _EmojiPickerBottomSheet(
        isLightTheme: widget.isLightTheme,
        onEmojiSelected: (emoji) {
          // Insert emoji at cursor position using Quill
          final selection = _quillController.selection;
          final docLength = _quillController.document.length;
          
          // Validate selection indices
          final start = selection.start >= 0 ? selection.start.clamp(0, docLength) : docLength;
          final end = selection.end >= 0 && selection.end <= docLength 
              ? selection.end.clamp(0, docLength)
              : docLength;
          final validStart = start <= end ? start : end;
          final validEnd = end >= start ? end : start;
          
          // Replace selected text with emoji
          if (validStart < validEnd) {
            _quillController.document.delete(validStart, validEnd - validStart);
          }
          _quillController.document.insert(validStart, emoji);
          
          // Update cursor position
          _quillController.updateSelection(
            TextSelection.collapsed(offset: validStart + emoji.length),
            quill.ChangeSource.local,
          );
          
          setState(() {
            _selectedTool = null;
          });
        },
      ),
    );
  }

  /// Helper method to get alignment at cursor position (Quill-based)
  TextAlign _getAlignmentAtCursor(int position) {
    // Quill handles alignment internally - return default for now
    // This method is kept for compatibility but alignment is handled by Quill
    return TextAlign.left;
  }

  /// Font style handler (Legacy - no longer used with Quill)
  // Helper method to detect format(s) at selection/cursor with support for mixed styles
  ({TextFormat? singleFormat, Map<String, dynamic>? mixedStyles}) _detectFormatAtSelection() {
    // This method is deprecated - Quill handles formatting internally
    // Return default format for compatibility
        final defaultColor = widget.isLightTheme 
            ? const Color(0xFF1E1E1E)
            : Colors.white;
        return (
          singleFormat: TextFormat(
        start: 0,
        end: 0,
            fontFamily: 'Default',
            fontSize: 'Normal',
            color: defaultColor,
            alignment: TextAlign.left,
          ),
          mixedStyles: null,
        );
      }
      
  // Get paragraph alignment for a given position (Legacy - Quill handles this)
  TextAlign _getParagraphAlignment(int position) {
    // Quill handles alignment internally - return default
    return TextAlign.left;
  }
  
  void _showQuillFormattingToolbar() {
          setState(() {
      _showFormattingToolbar = true;
      _selectedTool = 'format';
    });
    // Don't unfocus - keep keyboard open if it's open
    // Toolbar will appear above keyboard
  }

  void _hideFormattingToolbar() {
          setState(() {
      _showFormattingToolbar = false;
            _selectedTool = null;
          });
  }
  
  // Legacy method - no longer used with Quill (formatting handled by QuillFormattingToolbar)
  void _handleFontStyle() {
    // This method is deprecated - use _showQuillFormattingToolbar instead
    _showQuillFormattingToolbar();
  }

  /// List insert handler (Quill handles lists natively)
  void _handleListInsert() {
    // Quill supports lists natively - use Quill formatting toolbar
    // For now, show formatting toolbar
    _showQuillFormattingToolbar();
        }
  
  void _updateFormatsOnTextChange(String newText) {
    // This method is deprecated - Quill handles formatting internally
    // No action needed
  }
  
  void _handleListContinuation(String text) {
    // This method is deprecated - Quill handles list continuation natively
    // No action needed
  }

  /// Audio recording handler
  void _handleAudioRecording() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AudioRecordingBottomSheet(
        isLightTheme: widget.isLightTheme,
        onAudioRecorded: (audioPath) {
          // Get current text length for position tracking
          final currentTextLength = _quillController.document.toPlainText().length;
          final insertionPosition = currentTextLength;
          
          setState(() {
            _audioAttachments.add(MediaAttachment(
              path: audioPath,
              isVideo: false,
              position: insertionPosition,
            ));
            _selectedTool = null;
          });
          
          // Move cursor to below the audio - add newlines and position cursor at end
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                // Get document length (character count)
                final docLength = _quillController.document.length;
                
                // Ensure we have a valid document
                if (docLength == 0) {
                  // Empty document - insert at position 0
                  _quillController.document.insert(0, '\n\n');
                  _quillController.updateSelection(
                    TextSelection.collapsed(offset: 2),
                    quill.ChangeSource.local,
                  );
                } else {
                  // Valid document - insert at the end
                  // Use length-1 as the last valid position for insertion
                  final insertPos = (docLength - 1).clamp(0, docLength - 1);
                  _quillController.document.insert(insertPos, '\n\n');
                  // Position cursor at the end
                  final newLength = _quillController.document.length;
                  _quillController.updateSelection(
                    TextSelection.collapsed(offset: newLength > 0 ? newLength - 1 : 0),
                    quill.ChangeSource.local,
                  );
                }
              } catch (e) {
                debugPrint('🔥 [AUDIO ERROR] Error inserting newlines: $e');
                // Fallback: just position cursor at end if document exists
                try {
                  final docLength = _quillController.document.length;
                  if (docLength > 0) {
                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: docLength - 1),
                      quill.ChangeSource.local,
                    );
                  }
                } catch (e2) {
                  debugPrint('🔥 [AUDIO ERROR] Fallback also failed: $e2');
                }
              }
            });
          }
        },
        onClose: () {
          setState(() {
            _selectedTool = null;
          });
        },
      ),
    );
  }

  /// Drawing handler
  void _handleDrawing({MediaAttachment? existingDrawing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DrawingCanvasScreen(
          isLightTheme: widget.isLightTheme,
          existingDrawingDataPath: existingDrawing?.drawingDataPath,
          existingImagePath: existingDrawing?.path,
          onDrawingSaved: (imagePath, drawingDataPath) {
            // Get current text length for position tracking
            final currentTextLength = _quillController.document.toPlainText().length;
            final insertionPosition = existingDrawing?.position ?? currentTextLength;
            
            setState(() {
              if (existingDrawing != null) {
                // Update existing drawing
                final index = _mediaAttachments.indexOf(existingDrawing);
                if (index != -1) {
                  _mediaAttachments[index] = existingDrawing.copyWith(
                    path: imagePath,
                    drawingDataPath: drawingDataPath,
                  );
                }
              } else {
                // Add new drawing
                _mediaAttachments.add(MediaAttachment(
                  path: imagePath,
                  isVideo: false,
                  position: insertionPosition,
                  isDrawing: true,
                  drawingDataPath: drawingDataPath,
                ));
              }
            });
            
            // Move cursor to below the drawing - add newlines and position cursor at end
            if (mounted && existingDrawing == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  // Get document length (character count)
                  final docLength = _quillController.document.length;
                  
                  // Ensure we have a valid document
                  if (docLength == 0) {
                    // Empty document - insert at position 0
                    _quillController.document.insert(0, '\n\n');
                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: 2),
                      quill.ChangeSource.local,
                    );
                  } else {
                    // Valid document - insert at the end
                    // Use length-1 as the last valid position for insertion
                    final insertPos = (docLength - 1).clamp(0, docLength - 1);
                    _quillController.document.insert(insertPos, '\n\n');
                    // Position cursor at the end
                    final newLength = _quillController.document.length;
                    _quillController.updateSelection(
                      TextSelection.collapsed(offset: newLength > 0 ? newLength - 1 : 0),
                      quill.ChangeSource.local,
                    );
                  }
                } catch (e) {
                  debugPrint('🔥 [DRAWING ERROR] Error inserting newlines: $e');
                  // Fallback: just position cursor at end if document exists
                  try {
                    final docLength = _quillController.document.length;
                    if (docLength > 0) {
                      _quillController.updateSelection(
                        TextSelection.collapsed(offset: docLength - 1),
                        quill.ChangeSource.local,
                      );
                    }
                  } catch (e2) {
                    debugPrint('🔥 [DRAWING ERROR] Fallback also failed: $e2');
                  }
                }
              });
            }
          },
        ),
      ),
    );
  }

  /// Build unified content display (text, media, audio in insertion order)
  Widget _buildUnifiedContent() {
    final allItems = <({int position, bool isMedia, bool isAudio, int index})>[];
    
    // Add all media attachments with their positions
    for (int i = 0; i < _mediaAttachments.length; i++) {
      allItems.add((
        position: _mediaAttachments[i].position,
        isMedia: true,
        isAudio: false,
        index: i,
      ));
    }
    
    // Add all audio attachments with their positions
    for (int i = 0; i < _audioAttachments.length; i++) {
      allItems.add((
        position: _audioAttachments[i].position,
        isMedia: false,
        isAudio: true,
        index: i,
      ));
    }
    
    // Sort by position to maintain insertion order
    allItems.sort((a, b) => a.position.compareTo(b.position));
    
    // Build content widgets in order
    final contentWidgets = <Widget>[];
    
    // Track if we've shown the initial text editor
    bool initialTextShown = false;
    
    // Show initial text editor first if there's any text or if no media exists yet
    if (allItems.isEmpty || (allItems.isNotEmpty && allItems.first.position > 0)) {
    contentWidgets.add(
        QuillTextEditor(
          key: const ValueKey('main_text_editor'),
          controller: _quillController,
        isLightTheme: widget.isLightTheme,
          focusNode: _contentFocusNode,
          onTextChanged: (text) {
            // Quill handles list continuation natively - no action needed
          },
          onSelectionChanged: () {
          // Deselect stickers when user taps on content text field
          if (_selectedStickerIndex != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
            setState(() {
              _selectedStickerIndex = null;
                  });
                }
            });
          }
        },
      ),
    );
      initialTextShown = true;
    }
    
    // Build content in order based on positions
    for (final item in allItems) {
      // Add spacing before media/audio (12dp)
      contentWidgets.add(const SizedBox(height: 12));
      
      // Add the appropriate widget
      if (item.isMedia) {
        contentWidgets.add(
          _buildMediaThumbnail(_mediaAttachments[item.index], item.index),
        );
      } else if (item.isAudio) {
        contentWidgets.add(
          _buildAudioWidget(_audioAttachments[item.index], item.index),
        );
      }
      
      // Add text field below media/audio with "Write more here..." hint
      // Use a unique key that combines type and index
      final mediaKey = item.isAudio 
          ? _audioAttachments.length + item.index 
          : item.index;
      contentWidgets.add(const SizedBox(height: 8));
      contentWidgets.add(
        _buildTextFieldBelowMedia(mediaKey, item.isAudio),
      );
    }
    
    // If no media/audio, ensure initial text editor is shown
    if (!initialTextShown && allItems.isEmpty) {
      contentWidgets.add(
        QuillTextEditor(
          key: const ValueKey('main_text_editor'),
          controller: _quillController,
          isLightTheme: widget.isLightTheme,
          focusNode: _contentFocusNode,
          onTextChanged: (text) {
            // Quill handles list continuation natively - no action needed
          },
          onSelectionChanged: () {
            // Deselect stickers when user taps on content text field
            if (_selectedStickerIndex != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedStickerIndex = null;
                  });
                }
              });
            }
          },
        ),
      );
    }
    
    // Add spacing at bottom for keyboard
    contentWidgets.add(const SizedBox(height: 20));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }
  
  /// Build text field below media item with "Write more here..." hint
  Widget _buildTextFieldBelowMedia(int mediaIndex, bool isAudio) {
    // Get or create controller for this media item's text field
    // Use a key to ensure stable widget identity
    final controllerKey = 'media_text_$mediaIndex';
    
    if (!_mediaTextControllers.containsKey(mediaIndex)) {
      _mediaTextControllers[mediaIndex] = quill.QuillController(
        document: quill.Document(),
        selection: const TextSelection.collapsed(offset: 0),
      );
      _mediaTextFocusNodes[mediaIndex] = FocusNode();
      _mediaTextUpdatingFlags[mediaIndex] = false; // Initialize update flag
      
      // Add listener to update UI when focus changes (to show/hide placeholder)
      // Use a flag to prevent multiple simultaneous callbacks
      _mediaTextFocusNodes[mediaIndex]!.addListener(() {
        if (mounted && !(_mediaTextUpdatingFlags[mediaIndex] ?? false)) {
          _mediaTextUpdatingFlags[mediaIndex] = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mediaTextUpdatingFlags[mediaIndex] = false;
            if (mounted) {
              setState(() {});
            }
          });
        }
      });
    }
    
    final controller = _mediaTextControllers[mediaIndex]!;
    final focusNode = _mediaTextFocusNodes[mediaIndex]!;
    
    return Padding(
      key: ValueKey(controllerKey),
      padding: const EdgeInsets.only(left: 10, right: 20),
      child: QuillTextEditor(
        controller: controller,
        isLightTheme: widget.isLightTheme,
        focusNode: focusNode,
        placeholder: 'Write more here...',
        onTextChanged: (text) {
          // Text changed - don't trigger setState here to avoid rebuild loops
          // The placeholder visibility is handled by the QuillTextEditor itself
        },
        onSelectionChanged: () {
          // Deselect stickers when user taps on text field
          if (_selectedStickerIndex != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedStickerIndex = null;
                });
              }
            });
          }
        },
      ),
    );
  }
  
  /// Build audio widget
  Widget _buildAudioWidget(MediaAttachment attachment, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final audioWidth = screenWidth * 0.75; // ¾ of screen width
    
    return Align(
      alignment: Alignment.centerLeft, // Left align
      child: Padding(
        padding: const EdgeInsets.only(left: 10), // Left padding 10dp
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
                color: Colors.black.withValues(alpha: widget.isLightTheme ? 0.08 : 0.2),
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
                onTap: () async {
                  if (_currentlyPlayingAudio == attachment.path) {
                    await _audioPlayer.stop();
                    setState(() {
                      _currentlyPlayingAudio = null;
                    });
                  } else {
                    await _audioPlayer.play(DeviceFileSource(attachment.path));
                    setState(() {
                      _currentlyPlayingAudio = attachment.path;
                    });
                  }
                },
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
                    _currentlyPlayingAudio == attachment.path
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Audio info
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
                    Text(
                      'Tap to play',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: (widget.isLightTheme
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
                onTap: () {
                  setState(() {
                    _audioAttachments.removeAt(index);
                    if (_currentlyPlayingAudio == attachment.path) {
                      _audioPlayer.stop();
                      _currentlyPlayingAudio = null;
                    }
                  });
                },
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
    );
  }

  /// Build media thumbnail widget
  Widget _buildMediaThumbnail(MediaAttachment attachment, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final mediaWidth = screenWidth * 0.75; // ¾ of screen width
    
    return Align(
      alignment: Alignment.centerLeft, // Left align
      child: Padding(
        padding: const EdgeInsets.only(left: 10), // Left padding 10dp
        child: GestureDetector(
          onTap: () => _showMediaFullScreen(attachment),
          child: Container(
            width: mediaWidth,
            height: 230, // Uniform height for all media
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
                  color: Colors.black.withValues(alpha: widget.isLightTheme ? 0.08 : 0.2),
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
                  if (attachment.isVideo)
                    SizedBox(
                      width: mediaWidth,
                      height: 230,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _VideoThumbnailWidget(videoPath: attachment.path),
                      ),
                    )
                  else
                    SizedBox(
                      width: mediaWidth,
                      height: 230,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(attachment.path),
                          width: mediaWidth,
                          height: 230,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: mediaWidth,
                            height: 230,
                            color: widget.isLightTheme
                                ? Colors.grey.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.4),
                            child: Icon(
                              Icons.image_rounded,
                              size: 48,
                              color: widget.isLightTheme
                                  ? Colors.grey[600]
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (attachment.isVideo)
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
                      onTap: () {
                        setState(() {
                          _mediaAttachments.removeAt(index);
                        });
                      },
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
    );
  }

  /// Show media in full screen
  void _showMediaFullScreen(MediaAttachment attachment) {
    if (attachment.isVideo) {
      // Show video player
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Center(
                child: _VideoPlayerWidget(videoPath: attachment.path),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Show image
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: Image.file(
                  File(attachment.path),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

/// Draggable sticker widget with resize and rotate capabilities
/// Completely rewritten for bug-free, smooth interactions
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
    required Key key,
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
  }) : super(key: key);

  @override
  State<_DraggableStickerWidget> createState() => _DraggableStickerWidgetState();
}

class _DraggableStickerWidgetState extends State<_DraggableStickerWidget> {
  // Interaction states - only one can be true at a time
  bool _isDragging = false;
  bool _isResizing = false;
  bool _isRotating = false;
  bool _isDeleting = false; // Track delete button interaction
  
  // Position and transform state
  late double _x;
  late double _y;
  late double _size;
  late double _rotation;
  
  // Constants
  static const double _baseSize = 60.0; // Base size in pixels
  static const double _minSize = 0.3; // Minimum size multiplier (no disappearing)
  static const double _maxSize = 3.0; // Maximum size multiplier (no oversized breaking)
  static const double _handleSize = 28.0; // Handle size for better touch targets
  static const double _handleHitboxPadding = 16.0; // Extra padding for hitbox
  static const double _deleteButtonSize = 44.0; // Minimum 44dp for accessibility
  static const double _deleteButtonHitboxPadding = 22.0; // Extra padding to ensure 44dp minimum touch area
  
  // Gesture tracking - resizing
  double _initialSize = 1.0;
  Offset _initialResizePosition = Offset.zero;
  Offset _resizeCenter = Offset.zero;
  
  // Gesture tracking - rotation
  double _initialRotation = 0.0;
  Offset? _initialRotatePosition;
  Offset? _rotateCenter;
  
  
  // Two-finger gesture tracking
  double _initialTwoFingerRotation = 0.0;
  double _initialTwoFingerDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _x = widget.sticker.x.clamp(0.0, 1.0);
    _y = widget.sticker.y.clamp(0.0, 1.0);
    // Ensure size and rotation are valid finite numbers
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
    // Only update if sticker data actually changed (not just selection state)
    if (oldWidget.sticker != widget.sticker) {
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
    // Reset interaction states when deselected (but preserve position/size/rotation)
    if (!widget.isSelected && oldWidget.isSelected) {
      _isDragging = false;
      _isResizing = false;
      _isRotating = false;
      _isDeleting = false;
    }
  }

  void _updateSticker() {
    widget.onUpdate(widget.sticker.copyWith(
      x: _x,
      y: _y,
      size: _size,
      rotation: _rotation,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = widget.contentWidth;
    final contentHeight = widget.contentHeight;
    
    // Ensure valid dimensions
    if (contentWidth <= 0 || contentHeight <= 0) {
      return const SizedBox.shrink();
    }
    
    final stickerSize = _baseSize * _size;
    
    // Calculate absolute position within content area
    final left = _x * contentWidth - stickerSize / 2;
    final top = _y * contentHeight - stickerSize / 2;
    
    // Clamp to content bounds - ensure max is >= min
    final maxLeft = (contentWidth - stickerSize).clamp(0.0, double.infinity);
    final maxTop = (contentHeight - stickerSize).clamp(0.0, double.infinity);
    final clampedLeft = left.clamp(0.0, maxLeft);
    final clampedTop = top.clamp(0.0, maxTop);
    
    // Return Positioned directly - it must be a direct child of Stack
    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: GestureDetector(
        // When not selected: deferToChild (only intercepts taps on the sticker itself)
        // When selected or actively interacting: opaque (intercepts all touches for dragging/resizing)
        behavior: widget.isSelected || _isDragging || _isRotating || _isResizing || _isDeleting
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        // Single finger tap to select/deselect
        onTap: () {
          // Don't process tap if interacting with handles
          if (_isResizing || _isRotating || _isDeleting) {
            return;
          }
          if (widget.isSelected) {
            widget.onDeselect();
          } else {
            widget.onSelect();
          }
        },
          // Unified gesture handling - FIXED: Proper conflict prevention
          onScaleStart: (details) {
            // Don't interfere if handles are active
            if (_isResizing || _isRotating || _isDeleting) {
              return;
            }
            
            // Check if touch is near handles or delete button (prevent conflicts)
            if (widget.isSelected && details.pointerCount == 1) {
              final touchLocalPos = details.localFocalPoint;
              final stickerSize = _baseSize * _size;
              
              // Check delete button area (top-left)
              final deleteArea = Rect.fromLTWH(
                -(_deleteButtonSize / 2) - _deleteButtonHitboxPadding,
                -(_deleteButtonSize / 2) - _deleteButtonHitboxPadding,
                _deleteButtonSize + _deleteButtonHitboxPadding * 2,
                _deleteButtonSize + _deleteButtonHitboxPadding * 2,
              );
              if (deleteArea.contains(touchLocalPos)) return;
              
              // Check rotation handle area (top-right)
              final rotateArea = Rect.fromLTWH(
                stickerSize - (_handleSize / 2) - _handleHitboxPadding,
                -(_handleSize / 2) - _handleHitboxPadding,
                _handleSize + _handleHitboxPadding * 2,
                _handleSize + _handleHitboxPadding * 2,
              );
              if (rotateArea.contains(touchLocalPos)) return;
              
              // Check resize handle area (bottom-right)
              final resizeArea = Rect.fromLTWH(
                stickerSize - (_handleSize / 2) - _handleHitboxPadding,
                stickerSize - (_handleSize / 2) - _handleHitboxPadding,
                _handleSize + _handleHitboxPadding * 2,
                _handleSize + _handleHitboxPadding * 2,
              );
              if (resizeArea.contains(touchLocalPos)) return;
            }
            
            // Two-finger gestures (pinch-to-zoom or rotation)
            if (details.pointerCount == 2 && widget.isSelected) {
              _initialSize = _size;
              _initialRotation = _rotation;
              
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
                _isRotating = false;
              });
            }
            // Single finger drag to move - FIXED: Always works, position fixed
            else if (details.pointerCount == 1) {
              if (widget.isSelected) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _isDragging = true;
                });
              } else {
                widget.onSelect();
              }
            }
          },
          onScaleUpdate: (details) {
            // Don't interfere if handles are active
            if (_isResizing || _isRotating || _isDeleting) {
              return;
            }
            
            final stickerSize = _baseSize * _size;
            
            // Two-finger gestures (pinch-to-zoom or rotation) - FIXED: Maintains aspect ratio
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
                
                // Prioritize pinch-to-zoom if scale change is significant
                if (scaleChangeAbs > 0.02) {
                  final newSize = _initialSize * scaleChange;
                  if (newSize.isFinite) {
                    setState(() {
                      _size = newSize.clamp(_minSize, _maxSize); // Maintain aspect ratio, apply limits
                    });
                    _updateSticker();
                  }
                } else if (normalizedAngleAbs > 5.0) {
                  // Rotation when angle change is significant
                  if (normalizedAngle.isFinite) {
                    setState(() {
                      final newRotation = (_initialRotation + normalizedAngle) % 360;
                      _rotation = newRotation < 0 ? newRotation + 360 : newRotation;
                    });
                    _updateSticker();
                  }
                }
              }
            }
            // Single finger drag to move - FIXED: Always works, position fixed on scroll
            else if (_isDragging && details.pointerCount == 1) {
              if (contentWidth > 0 && contentHeight > 0) {
                // Use focalPointDelta for accurate relative movement (works with scrolling)
                final deltaX = details.focalPointDelta.dx / contentWidth;
                final deltaY = details.focalPointDelta.dy / contentHeight;
                
                if (deltaX.isFinite && deltaY.isFinite) {
                  setState(() {
                    final newX = _x + deltaX;
                    final newY = _y + deltaY;
                    
                    if (newX.isFinite && newY.isFinite) {
                      // Clamp to valid range (0.0 to 1.0)
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
            // Only reset if not controlled by handles - FIXED: Stable state, no resets
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
                    : null, // No shadow when not selected
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Sticker emoji
                  Center(
                    child: Text(
                      widget.sticker.emoji,
                      style: TextStyle(fontSize: stickerSize * 0.7),
                    ),
                  ),
                  // Delete button (only when selected) - FIXED: 44dp minimum touch area, always works
                  if (widget.isSelected)
                    Positioned(
                      top: -(_deleteButtonSize / 2) - _deleteButtonHitboxPadding,
                      left: -(_deleteButtonSize / 2) - _deleteButtonHitboxPadding,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          // Immediately set deleting state to prevent conflicts
                          setState(() {
                            _isDeleting = true;
                            _isDragging = false;
                            _isResizing = false;
                            _isRotating = false;
                          });
                        },
                        onTap: () {
                          // Always delete - no conditions
                          widget.onDelete();
                          setState(() {
                            _isDeleting = false;
                          });
                        },
                        onTapCancel: () {
                          setState(() {
                            _isDeleting = false;
                          });
                        },
                        child: Container(
                          // Ensure minimum 44dp touch area (88dp total with padding on both sides)
                          width: _deleteButtonSize + (_deleteButtonHitboxPadding * 2),
                          height: _deleteButtonSize + (_deleteButtonHitboxPadding * 2),
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
                  // Resize handle (bottom-right, only when selected) - FIXED: Maintains aspect ratio, smooth, min/max limits
                  if (widget.isSelected)
                    Positioned(
                      bottom: -(_handleSize / 2),
                      right: -(_handleSize / 2),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          FocusScope.of(context).unfocus();
                          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                          final stickerCenter = Offset(stickerSize / 2, stickerSize / 2);
                          
                          if (renderBox != null) {
                            _resizeCenter = renderBox.localToGlobal(stickerCenter);
                            _initialResizePosition = details.globalPosition;
                          } else {
                            _resizeCenter = stickerCenter;
                            _initialResizePosition = details.localPosition + Offset(stickerSize - _handleSize / 2, stickerSize - _handleSize / 2);
                          }
                          
                          setState(() {
                            _isResizing = true;
                            _isDragging = false;
                            _isRotating = false;
                            _isDeleting = false;
                            _initialSize = _size;
                          });
                        },
                        onPanUpdate: (details) {
                          if (!_isResizing) return;
                          
                          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                          Offset currentPos;
                          Offset centerPos;
                          
                          if (renderBox != null) {
                            currentPos = details.globalPosition;
                            centerPos = _resizeCenter;
                          } else {
                            final handleOffset = Offset(stickerSize - _handleSize / 2, stickerSize - _handleSize / 2);
                            currentPos = details.localPosition + handleOffset;
                            centerPos = Offset(stickerSize / 2, stickerSize / 2);
                          }
                          
                          final initialDistance = (_initialResizePosition - centerPos).distance;
                          final currentDistance = (currentPos - centerPos).distance;
                          
                          if (initialDistance > 0 && currentDistance > 0 && 
                              initialDistance.isFinite && currentDistance.isFinite) {
                            // Maintain aspect ratio by using distance ratio
                            final sizeRatio = currentDistance / initialDistance;
                            final newSize = _initialSize * sizeRatio;
                            
                            if (newSize.isFinite) {
                              setState(() {
                                // Clamp to min/max limits
                                _size = newSize.clamp(_minSize, _maxSize);
                              });
                              _updateSticker();
                            }
                          }
                        },
                        onPanEnd: (details) {
                          setState(() {
                            _isResizing = false;
                          });
                        },
                        onPanCancel: () {
                          setState(() {
                            _isResizing = false;
                          });
                        },
                        child: Container(
                          // Large hitbox for reliable interaction
                          width: _handleSize + _handleHitboxPadding,
                          height: _handleSize + _handleHitboxPadding,
                          alignment: Alignment.center,
                          child: Container(
                            width: _handleSize,
                            height: _handleSize,
                            decoration: BoxDecoration(
                              color: widget.isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white,
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
                            child: Icon(
                              Icons.open_in_full_rounded,
                              color: widget.isLightTheme
                                  ? Colors.white
                                  : const Color(0xFF5E3A9E),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Rotate handle (top-right, only when selected) - FIXED: Smooth rotation at any size, no conflicts
                  if (widget.isSelected)
                    Positioned(
                      top: -(_handleSize / 2),
                      right: -(_handleSize / 2),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _isRotating = true;
                            _isDragging = false;
                            _isResizing = false;
                            _isDeleting = false;
                          });
                        },
                        onPanStart: (details) {
                          FocusScope.of(context).unfocus();
                          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                          final stickerCenter = Offset(stickerSize / 2, stickerSize / 2);
                          
                          if (renderBox != null) {
                            _rotateCenter = renderBox.localToGlobal(stickerCenter);
                            _initialRotatePosition = details.globalPosition;
                          } else {
                            _rotateCenter = stickerCenter;
                            _initialRotatePosition = details.localPosition + Offset(stickerSize - _handleSize / 2, -_handleSize / 2);
                          }
                          
                          setState(() {
                            _isRotating = true;
                            _isDragging = false;
                            _isResizing = false;
                            _isDeleting = false;
                            _initialRotation = _rotation;
                          });
                        },
                        onPanUpdate: (details) {
                          if (!_isRotating || _rotateCenter == null || _initialRotatePosition == null) return;
                          
                          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                          Offset currentPos;
                          Offset centerPos;
                          
                          if (renderBox != null) {
                            currentPos = details.globalPosition;
                            centerPos = _rotateCenter!;
                          } else {
                            final handleOffset = Offset(stickerSize - _handleSize / 2, -_handleSize / 2);
                            currentPos = details.localPosition + handleOffset;
                            centerPos = Offset(stickerSize / 2, stickerSize / 2);
                          }
                          
                          // Calculate angle difference
                          final initialVector = _initialRotatePosition! - centerPos;
                          final currentVector = currentPos - centerPos;
                          
                          if (initialVector.distance > 1 && currentVector.distance > 1) {
                            final initialAngle = initialVector.direction;
                            final currentAngle = currentVector.direction;
                            
                            // Calculate angle delta in degrees
                            double angleDelta = (currentAngle - initialAngle) * 180 / 3.14159;
                            
                            // Normalize to -180 to 180 range
                            while (angleDelta > 180) {
                              angleDelta -= 360;
                            }
                            while (angleDelta < -180) {
                              angleDelta += 360;
                            }
                            
                            // Apply rotation smoothly (even small movements)
                            if (angleDelta.isFinite && angleDelta.abs() > 0.01) {
                              setState(() {
                                final newRotation = (_initialRotation + angleDelta) % 360;
                                _rotation = newRotation < 0 ? newRotation + 360 : newRotation;
                                // Update for next frame to prevent accumulation
                                _initialRotation = _rotation;
                                _initialRotatePosition = currentPos;
                              });
                              _updateSticker();
                            }
                          }
                        },
                        onPanEnd: (details) {
                          setState(() {
                            _isRotating = false;
                            _initialRotatePosition = null;
                            _rotateCenter = null;
                          });
                        },
                        onPanCancel: () {
                          setState(() {
                            _isRotating = false;
                            _initialRotatePosition = null;
                            _rotateCenter = null;
                          });
                        },
                        child: Container(
                          // Large hitbox for reliable interaction
                          width: _handleSize + _handleHitboxPadding,
                          height: _handleSize + _handleHitboxPadding,
                          alignment: Alignment.center,
                          child: Container(
                            width: _handleSize,
                            height: _handleSize,
                            decoration: BoxDecoration(
                              color: widget.isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white,
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
                            child: Icon(
                              Icons.rotate_right_rounded,
                              color: widget.isLightTheme
                                  ? Colors.white
                                  : const Color(0xFF5E3A9E),
                              size: 18,
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

/// Sticker picker bottom sheet with categories
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

  // Sticker categories with lots of cute stickers (no duplicates)
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
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  itemCount: _categoryNames.length, // Removed "+" button
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
                            index < _categoryNames.length ? _categoryNames[index] : '',
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
                      onTap: () => widget.onStickerSelected(_currentStickers[index]),
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
        ),
      ),
    );
  }
}

/// Emoji picker bottom sheet
class _EmojiPickerBottomSheet extends StatefulWidget {
  final bool isLightTheme;
  final Function(String) onEmojiSelected;

  const _EmojiPickerBottomSheet({
    required this.isLightTheme,
    required this.onEmojiSelected,
  });

  @override
  State<_EmojiPickerBottomSheet> createState() => _EmojiPickerBottomSheetState();
}

class _EmojiPickerBottomSheetState extends State<_EmojiPickerBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final panelHeight = screenHeight * 0.42; // 42% of screen height
    
    return Container(
      height: panelHeight,
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
          child: emoji_picker.EmojiPicker(
            onEmojiSelected: (category, emoji) {
              widget.onEmojiSelected(emoji.emoji);
            },
            config: emoji_picker.Config(
              height: panelHeight,
              checkPlatformCompatibility: true,
              emojiViewConfig: emoji_picker.EmojiViewConfig(
                backgroundColor: Colors.transparent,
                emojiSizeMax: 28,
              ),
              skinToneConfig: const emoji_picker.SkinToneConfig(),
              categoryViewConfig: emoji_picker.CategoryViewConfig(
                backgroundColor: widget.isLightTheme
                    ? const Color(0xFFF8F4FF)
                    : Colors.black.withValues(alpha: 0.9),
                iconColorSelected: const Color(0xFF5E3A9E),
                iconColor: widget.isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.5),
              ),
              searchViewConfig: emoji_picker.SearchViewConfig(
                backgroundColor: widget.isLightTheme
                    ? const Color(0xFFF8F4FF)
                    : Colors.black.withValues(alpha: 0.9),
              ),
              bottomActionBarConfig: emoji_picker.BottomActionBarConfig(
                enabled: true,
                backgroundColor: widget.isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.1),
                buttonIconColor: widget.isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Emoji hint bubble widget with speech bubble style
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
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: CustomPaint(
              painter: _BubblePainter(
                backgroundColor: isLightTheme
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.95),
                shadowColor: Colors.black.withValues(alpha: 0.1),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(top: 8), // Space for tail
                child: Text(
                  'Tap to share how you feel ✨',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : const Color(0xFF5E3A9E),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for speech bubble with tail
class _BubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color shadowColor;

  _BubblePainter({
    required this.backgroundColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final radius = 12.0;
    final tailWidth = 8.0;
    final tailHeight = 6.0;
    final tailOffset = size.width / 2; // Center of bubble

    // Draw shadow
    final shadowPath = Path()
      ..moveTo(radius, tailHeight)
      ..lineTo(tailOffset - tailWidth / 2, tailHeight)
      ..lineTo(tailOffset, 0)
      ..lineTo(tailOffset + tailWidth / 2, tailHeight)
      ..lineTo(size.width - radius, tailHeight)
      ..arcToPoint(
        Offset(size.width, tailHeight + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: Radius.circular(radius),
      )
      ..lineTo(radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(0, tailHeight + radius)
      ..arcToPoint(
        Offset(radius, tailHeight),
        radius: Radius.circular(radius),
      )
      ..close();

    canvas.drawPath(shadowPath.shift(const Offset(0, 2)), shadowPaint);

    // Draw bubble
    final bubblePath = Path()
      ..moveTo(radius, tailHeight)
      ..lineTo(tailOffset - tailWidth / 2, tailHeight)
      ..lineTo(tailOffset, 0)
      ..lineTo(tailOffset + tailWidth / 2, tailHeight)
      ..lineTo(size.width - radius, tailHeight)
      ..arcToPoint(
        Offset(size.width, tailHeight + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: Radius.circular(radius),
      )
      ..lineTo(radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(0, tailHeight + radius)
      ..arcToPoint(
        Offset(radius, tailHeight),
        radius: Radius.circular(radius),
      )
      ..close();

    canvas.drawPath(bubblePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Formatted text field widget that displays formatting
class _FormattedTextField extends StatefulWidget {
  final TextEditingController controller;
  final bool isLightTheme;
  final List<TextFormat> textFormats;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const _FormattedTextField({
    required this.controller,
    required this.isLightTheme,
    required this.textFormats,
    this.onChanged,
    this.onTap,
  });

  @override
  State<_FormattedTextField> createState() => _FormattedTextFieldState();
}

class _FormattedTextFieldState extends State<_FormattedTextField> {
  // Track selection changes to update cursor position
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  
  // Build complete TextSpan tree for TextPainter layout calculations
  // This ensures we use the exact same layout as RichText for accurate metrics
  TextSpan _buildCompleteTextSpan() {
    final text = widget.controller.text;
    final baseStyle = _getBaseTextStyle();
    final sortedFormats = List<TextFormat>.from(widget.textFormats)
      ..sort((a, b) => a.start.compareTo(b.start));
    
    List<TextSpan> spans = [];
    int currentPos = 0;
    
    for (final format in sortedFormats) {
      if (format.start < 0 || format.start >= text.length) continue;
      
      // Skip zero-length formats for layout (they'll be applied when typing)
      if (format.start == format.end) continue;
      
      // Add unformatted text before this format
      if (format.start > currentPos) {
        spans.add(TextSpan(
          text: text.substring(currentPos, format.start),
          style: baseStyle,
        ));
      }
      
      // Add formatted text
      final formatStart = format.start < 0 ? 0 : format.start;
      final formatEnd = format.end > text.length ? text.length : format.end;
      if (formatEnd > formatStart) {
        spans.add(TextSpan(
          text: text.substring(formatStart, formatEnd),
          style: _getTextStyle(format),
        ));
      }
      
      currentPos = formatEnd;
    }
    
    // Add remaining unformatted text
    if (currentPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPos),
        style: baseStyle,
      ));
    }
    
    // If no spans, create default span
    if (spans.isEmpty) {
      if (text.isNotEmpty) {
        spans.add(TextSpan(text: text, style: baseStyle));
      } else {
        // Empty text - return empty span with base style for layout calculations
        return TextSpan(text: '', style: baseStyle);
      }
    }
    
    return TextSpan(children: spans);
  }
  
  // Get TextPainter for accurate layout metrics
  // Uses the exact same TextSpan structure as RichText for pixel-perfect alignment
  TextPainter _buildTextPainter({double maxWidth = double.infinity, TextAlign? textAlign}) {
    final textSpan = _buildCompleteTextSpan();
    final alignment = textAlign ?? _getAlignmentAtCursor(widget.controller.selection.start);
    
    final painter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: alignment,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
      maxLines: null,
    );
    
    painter.layout(maxWidth: maxWidth);
    return painter;
  }
  
  @override
  void initState() {
    super.initState();
    _lastSelection = widget.controller.selection;
    // Listen to selection changes
    widget.controller.addListener(_onSelectionChanged);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    super.dispose();
  }
  
  void _onSelectionChanged() {
    final currentSelection = widget.controller.selection;
    if (currentSelection != _lastSelection) {
      _lastSelection = currentSelection;
      // CRITICAL: Rebuild when selection changes to update cursor position and style
      // This ensures cursor style updates immediately when cursor moves or formats change
      if (mounted) {
        setState(() {});
        // Force immediate rebuild to ensure cursor style is updated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }
  
  @override
  void didUpdateWidget(_FormattedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when textFormats change (check by length and content, not just reference)
    bool formatsChanged = false;
    if (oldWidget.textFormats.length != widget.textFormats.length) {
      formatsChanged = true;
    } else {
      for (int i = 0; i < widget.textFormats.length; i++) {
        final oldF = oldWidget.textFormats[i];
        final newF = widget.textFormats[i];
        if (oldF.start != newF.start || 
            oldF.end != newF.end ||
            oldF.fontFamily != newF.fontFamily ||
            oldF.fontSize != newF.fontSize ||
            oldF.color != newF.color) {
          formatsChanged = true;
          break;
        }
      }
    }
    if (formatsChanged) {
      debugPrint('🔄 FormattedTextField: formats changed, rebuilding');
      setState(() {});
    }
  }

  TextStyle _getTextStyle(TextFormat format) {
    // Fix font sizes according to requirements
    double fontSize = 17; // Normal default (16-18 range, using 17)
    switch (format.fontSize) {
      case 'H1':
        fontSize = 30; // Large title (28-32 range, using 30)
        break;
      case 'H2':
        fontSize = 25; // Medium title (24-26 range, using 25)
        break;
      case 'H3':
        fontSize = 21; // Small title (20-22 range, using 21)
        break;
      case 'Small':
        fontSize = 13.5; // Small (13-14 range, using 13.5)
        break;
      case 'Normal':
      default:
        fontSize = 17; // Normal (16-18 range, using 17)
        break;
    }

    FontWeight fontWeight = FontWeight.normal;
    FontStyle fontStyle = FontStyle.normal;
    String? fontFamily;

    // Fix font family application - ensure all styles work correctly
    switch (format.fontFamily) {
      case 'Bold':
        fontWeight = FontWeight.bold;
        fontFamily = null; // Use default font with bold weight
        break;
      case 'Light':
        fontWeight = FontWeight.w300;
        fontFamily = null; // Use default font with light weight
        break;
      case 'Italic':
        fontStyle = FontStyle.italic;
        fontFamily = null; // Use default font with italic style
        break;
      case 'Merriweather':
        fontFamily = 'Merriweather';
        // Keep existing fontWeight/fontStyle if set
        break;
      case 'Monospace':
        fontFamily = 'monospace';
        // Keep existing fontWeight/fontStyle if set
        break;
      case 'Default':
      default:
        fontWeight = FontWeight.normal;
        fontStyle = FontStyle.normal;
        fontFamily = null; // Use default system font
        break;
    }

    // Calculate dynamic line height to prevent clipping
    // Larger fonts need more line height to prevent clipping
    double lineHeight = 1.5; // Default
    if (fontSize >= 28) {
      lineHeight = 1.6; // H1 - extra space for large text
    } else if (fontSize >= 24) {
      lineHeight = 1.55; // H2 - slightly more space
    } else if (fontSize >= 20) {
      lineHeight = 1.52; // H3 - slightly more space
    } else if (fontSize <= 14) {
      lineHeight = 1.45; // Small - can be tighter
    }

    if (fontFamily == 'Merriweather') {
      return GoogleFonts.merriweather(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: format.color,
        height: lineHeight, // Dynamic line height to prevent clipping
        textBaseline: TextBaseline.alphabetic, // Explicit baseline
      );
    } else if (fontFamily == 'monospace') {
      return GoogleFonts.robotoMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: format.color,
        height: lineHeight, // Dynamic line height to prevent clipping
        textBaseline: TextBaseline.alphabetic, // Explicit baseline
      );
    } else {
      // Default font - must match exactly between RichText and TextField
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: format.color,
        height: lineHeight, // Dynamic line height to prevent clipping
        letterSpacing: 0.0, // Explicit spacing - must match TextField
        wordSpacing: 0.0, // Explicit spacing - must match TextField
        textBaseline: TextBaseline.alphabetic, // Explicit baseline - must match TextField
      );
    }
  }

  // Base text style for consistent alignment
  // This must match exactly what RichText uses for unformatted text
  // Critical: All properties must match TextField exactly for cursor alignment
  TextStyle _getBaseTextStyle() {
    return GoogleFonts.poppins(
      fontSize: 16,
      height: 1.5, // Consistent line height - must match TextField exactly
      color: widget.isLightTheme
          ? const Color(0xFF5E3A9E)
          : Colors.white,
      fontWeight: FontWeight.normal, // Explicit default - must match TextField
      fontStyle: FontStyle.normal, // Explicit default - must match TextField
      letterSpacing: 0.0, // Explicit default - must match TextField
      wordSpacing: 0.0, // Explicit default - must match TextField
      textBaseline: TextBaseline.alphabetic, // Explicit baseline - must match TextField
      // No decoration - must match TextField
    );
  }
  
  // Get TextStyle at cursor position for accurate font metrics
  TextStyle _getTextStyleAtPosition(int position) {
    if (position < 0) return _getBaseTextStyle();
    
    final text = widget.controller.text;
    
    // CRITICAL FIX: Check for zero-length format FIRST (style before typing)
    // Zero-length formats have priority - they represent styles applied before typing
    // This ensures the first typed character uses the selected style
    for (final format in widget.textFormats) {
      if (position == format.start && format.start == format.end) {
        debugPrint('📝 Using zero-length format at position $position: ${format.fontFamily}/${format.fontSize}');
        return _getTextStyle(format);
      }
    }
    
    // Find format that contains this position
    for (final format in widget.textFormats) {
      if (position >= format.start && position < format.end) {
        return _getTextStyle(format);
      }
    }
    
    // Check if cursor is at the end of a format (for continuation)
    for (final format in widget.textFormats) {
      if (position == format.end && format.start < format.end) {
        return _getTextStyle(format);
      }
    }
    
    // If text is empty and we have zero-length formats, use the one at position 0
    if (text.isEmpty) {
      for (final format in widget.textFormats) {
        if (format.start == 0 && format.end == 0) {
          debugPrint('📝 Empty text - using zero-length format at 0: ${format.fontFamily}/${format.fontSize}');
          return _getTextStyle(format);
        }
      }
    }
    
    return _getBaseTextStyle();
  }
  
  // Get paragraph alignment for a given position
  // This finds the alignment of the paragraph containing this position
  TextAlign _getParagraphAlignment(int position) {
    if (position < 0) return TextAlign.left;
    
    final text = widget.controller.text;
    
    // Find paragraph boundaries
    int paragraphStart = 0;
    for (int i = position - 1; i >= 0; i--) {
      if (text[i] == '\n') {
        paragraphStart = i + 1;
        break;
      }
    }
    
    int paragraphEnd = text.length;
    for (int i = position; i < text.length; i++) {
      if (text[i] == '\n') {
        paragraphEnd = i;
        break;
      }
    }
    
    // Find format that covers any part of this paragraph
    for (final format in widget.textFormats) {
      if (format.start < paragraphEnd && format.end > paragraphStart) {
        return format.alignment;
      }
    }
    
    return TextAlign.left;
  }
  
  // Get alignment at cursor position (for paragraph-level alignment)
  // CRITICAL: Only return alignment from formats in the CURRENT paragraph
  // This prevents alignment from changing when tapping on text in different paragraphs
  TextAlign _getAlignmentAtCursor(int position) {
    if (position < 0) return TextAlign.left;
    
    final text = widget.controller.text;
    
    // Find paragraph boundaries for this position
    int paragraphStart = 0;
    for (int i = position - 1; i >= 0; i--) {
      if (text[i] == '\n') {
        paragraphStart = i + 1;
        break;
      }
    }
    
    int paragraphEnd = text.length;
    for (int i = position; i < text.length; i++) {
      if (text[i] == '\n') {
        paragraphEnd = i;
        break;
      }
    }
    
    // CRITICAL: Only check formats that are WITHIN the current paragraph
    // This prevents alignment from other paragraphs affecting the current one
    for (final format in widget.textFormats) {
      // Format must overlap with the current paragraph
      if (format.start < paragraphEnd && format.end > paragraphStart) {
        // Check if position is within this format
        if (position >= format.start && position < format.end) {
          return format.alignment;
        }
        // Check if position is at the start of a zero-length format in this paragraph
        if (position == format.start && format.start == format.end && 
            format.start >= paragraphStart && format.start < paragraphEnd) {
          return format.alignment;
        }
        // Check if position is at the end of a format in this paragraph
        if (position == format.end && format.start < format.end &&
            format.end >= paragraphStart && format.end <= paragraphEnd) {
          return format.alignment;
        }
      }
    }
    
    // If no format found, return left alignment (default)
    return TextAlign.left;
  }
  
  // Get font metrics for a given TextStyle using TextPainter
  // CRITICAL: Must use exact same TextStyle as RichText/TextField for accurate metrics
  // Uses actual text rendering to get pixel-perfect measurements
  ({double ascent, double descent, double height, double baseline, double fontSize, double lineHeight}) _getFontMetrics(TextStyle style) {
    // Use a representative character that works well for all fonts and styles
    // 'Ag' provides good baseline and height measurements
    // CRITICAL: Use the EXACT same style properties as TextField/RichText
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Ag', 
        style: style.copyWith(
          // Ensure all style properties match exactly
          height: style.height ?? 1.5,
          letterSpacing: style.letterSpacing ?? 0.0,
          wordSpacing: style.wordSpacing ?? 0.0,
          textBaseline: TextBaseline.alphabetic,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
      maxLines: 1, // Single line for accurate height measurement
    );
    textPainter.layout();
    
    // Get actual rendered text height (ascent + descent) - this is what cursor should match
    final height = textPainter.height;
    final baseline = textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final ascent = baseline;
    final descent = height - baseline;
    final fontSize = style.fontSize ?? 16.0;
    
    // Calculate line height (fontSize * height multiplier) - used for line spacing
    // CRITICAL: cursorHeight should use 'height' (actual text height), not 'lineHeight' (includes spacing)
    final heightMultiplier = style.height ?? 1.5;
    final lineHeight = fontSize * heightMultiplier;
    
    debugPrint('📏 Font metrics: fontSize=$fontSize, height=$height, baseline=$baseline, ascent=$ascent, descent=$descent');
    
    return (
      ascent: ascent,
      descent: descent,
      height: height, // Actual text height - use this for cursorHeight
      baseline: baseline,
      fontSize: fontSize,
      lineHeight: lineHeight, // Line spacing - used for TextField/RichText height property
    );
  }
  
  // Get font size at cursor position (for backward compatibility)
  double _getFontSizeAtPosition(int position) {
    final style = _getTextStyleAtPosition(position);
    return style.fontSize ?? 16.0;
  }
  
  // Build scalable TextField widget with accurate baseline alignment
  Widget _buildScalableTextField(TextStyle baseStyle) {
    final selection = widget.controller.selection;
    final cursorPos = selection.start;
    final text = widget.controller.text;
    
    // CRITICAL: Get the TextStyle at cursor position - MUST match RichText exactly
    // This includes zero-length formats (style before typing)
    final cursorStyle = _getTextStyleAtPosition(cursorPos);
    
    debugPrint('🎯 Cursor position: $cursorPos, style: fontSize=${cursorStyle.fontSize}, fontFamily=${cursorStyle.fontFamily}, fontWeight=${cursorStyle.fontWeight}, fontStyle=${cursorStyle.fontStyle}');
    
    // Calculate font metrics for accurate baseline alignment
    // CRITICAL: Use the EXACT same TextStyle that RichText uses at this position
    // Must include ALL style properties: fontSize, height, letterSpacing, wordSpacing, fontFamily, fontWeight, fontStyle
    final metrics = _getFontMetrics(cursorStyle);
    
    // For cursor height, use the ACTUAL text height (ascent + descent) from TextPainter
    // NOT lineHeight which includes spacing. This ensures cursor matches the visual text height
    // CRITICAL: cursorHeight must match the actual rendered text height, not line spacing
    // Use the actual rendered height from TextPainter for perfect alignment
    final cursorHeight = metrics.height; // Actual text height (ascent + descent)
    
    debugPrint('🎯 Cursor height: $cursorHeight (from metrics.height), fontSize: ${metrics.fontSize}');
    
    // For mixed styles (cursor between different formats), average the metrics
    if (cursorPos > 0 && cursorPos < text.length) {
      final prevStyle = _getTextStyleAtPosition(cursorPos - 1);
      final nextStyle = _getTextStyleAtPosition(cursorPos);
      
      // If styles differ, average the metrics
      // Critical: Check fontStyle (italic) as well for proper italic handling
      if (prevStyle.fontSize != nextStyle.fontSize ||
          prevStyle.fontFamily != nextStyle.fontFamily ||
          prevStyle.fontWeight != nextStyle.fontWeight ||
          prevStyle.fontStyle != nextStyle.fontStyle) {
        final prevMetrics = _getFontMetrics(prevStyle);
        final nextMetrics = _getFontMetrics(nextStyle);
        
        // Use averaged ACTUAL text height for cursor height (not lineHeight which includes spacing)
        // This ensures cursor matches the visual text height for mixed styles
        final avgCursorHeight = (prevMetrics.height + nextMetrics.height) / 2;
        
        // Ensure TextField style exactly matches RichText style for perfect alignment
        // Critical: All properties must match EXACTLY, especially for default font
        // Use cursorStyle directly to ensure pixel-perfect matching with RichText
        return TextField(
          controller: widget.controller,
          maxLines: null,
          minLines: 5,
          style: cursorStyle.copyWith(
            color: const Color(0x00000000), // Fully transparent (alpha=0) - only cursor visible
            // CRITICAL: Match ALL style properties exactly to RichText
            fontSize: cursorStyle.fontSize, // Match font size exactly
            height: cursorStyle.height ?? 1.5, // Explicitly set height - must match RichText exactly
            letterSpacing: cursorStyle.letterSpacing ?? 0.0, // Match letter spacing
            wordSpacing: cursorStyle.wordSpacing ?? 0.0, // Match word spacing
            fontFamily: cursorStyle.fontFamily, // Match font family
            fontWeight: cursorStyle.fontWeight ?? FontWeight.normal, // Match font weight
            fontStyle: cursorStyle.fontStyle ?? FontStyle.normal, // Match font style
            textBaseline: TextBaseline.alphabetic, // Explicit baseline for alignment
            // Ensure no other properties interfere
            decoration: TextDecoration.none,
            decorationColor: null,
            decorationStyle: TextDecorationStyle.solid,
            decorationThickness: 1.0,
          ),
          showCursor: true, // Show cursor
          readOnly: false, // Allow editing
          enableInteractiveSelection: true, // Allow text selection
          // Don't use strutStyle - let TextField use natural line height from style.height
          // This prevents line height accumulation errors across many lines
          textAlign: _getAlignmentAtCursor(cursorPos), // Match alignment
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: widget.controller.text.isEmpty ? 'Write more here…' : null,
            hintStyle: baseStyle.copyWith(
              color: (widget.isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white)
                  .withValues(alpha: 0.4),
            ),
            contentPadding: EdgeInsets.zero, // Remove padding for alignment
            isDense: true, // Reduce padding
            isCollapsed: false, // Allow proper text rendering
          ),
          onTap: widget.onTap, // Call onTap callback if provided
          onChanged: (newText) {
            // When text changes, trigger callback to update formats
            // Parent widget will handle rebuilds - don't call setState here to avoid loops
            if (widget.onChanged != null) {
              widget.onChanged!(newText);
            }
          },
          cursorColor: widget.isLightTheme
              ? const Color(0xFF5E3A9E)
              : Colors.white,
          cursorHeight: avgCursorHeight, // Use averaged actual text height for cursor height
        );
      }
    }
    
    // Standard case: single style at cursor
    // Use line height for cursor height (already calculated above)
    // This ensures proper alignment for all font sizes (H1, H2, H3, Normal, Small)
    
    // Ensure TextField style exactly matches RichText style for perfect alignment
    // Critical: All properties must match EXACTLY, especially for default font
    // Use cursorStyle directly to ensure pixel-perfect matching with RichText
    return TextField(
      controller: widget.controller,
      maxLines: null,
      minLines: 5,
      style: cursorStyle.copyWith(
        color: const Color(0x00000000), // Fully transparent (alpha=0) - only cursor visible
        // CRITICAL: Match ALL style properties exactly to RichText
        fontSize: cursorStyle.fontSize, // Match font size exactly
        height: cursorStyle.height ?? 1.5, // Explicitly set height - must match RichText exactly
        letterSpacing: cursorStyle.letterSpacing ?? 0.0, // Match letter spacing
        wordSpacing: cursorStyle.wordSpacing ?? 0.0, // Match word spacing
        fontFamily: cursorStyle.fontFamily, // Match font family
        fontWeight: cursorStyle.fontWeight ?? FontWeight.normal, // Match font weight
        fontStyle: cursorStyle.fontStyle ?? FontStyle.normal, // Match font style
        textBaseline: TextBaseline.alphabetic, // Explicit baseline for alignment
        // Ensure no other properties interfere
        decoration: TextDecoration.none,
        decorationColor: null,
        decorationStyle: TextDecorationStyle.solid,
        decorationThickness: 1.0,
      ),
      showCursor: true, // Show cursor
      readOnly: false, // Allow editing
      enableInteractiveSelection: true, // Allow text selection
      // Don't use strutStyle - let TextField use natural line height from style.height
      // This prevents line height accumulation errors across many lines
      textAlign: _getAlignmentAtCursor(cursorPos), // Match alignment
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: widget.controller.text.isEmpty ? 'Write more here…' : null,
        hintStyle: baseStyle.copyWith(
          color: (widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white)
              .withValues(alpha: 0.4),
        ),
        contentPadding: EdgeInsets.zero, // Zero padding - critical for alignment
        isDense: true, // Reduce padding
        isCollapsed: false, // Allow proper text rendering
      ),
      onTap: widget.onTap, // Call onTap callback if provided
      onChanged: (newText) {
        // When text changes, trigger callback to update formats
        // Parent widget will handle rebuilds - don't call setState here to avoid loops
        if (widget.onChanged != null) {
          widget.onChanged!(newText);
        }
      },
      cursorColor: widget.isLightTheme
          ? const Color(0xFF5E3A9E)
          : Colors.white,
      cursorHeight: cursorHeight, // Use actual text height for cursor height
    );
  }
  
  // Build paragraph widgets with per-paragraph alignment
  // CRITICAL: RichText can only have one textAlign, so we need separate RichText widgets per paragraph
  List<Widget> _buildParagraphWidgets(String text, List<TextSpan> spans, TextStyle baseStyle) {
    if (text.isEmpty || spans.isEmpty) {
      // Fallback to single RichText if no spans
      return [
        RichText(
          text: TextSpan(children: spans),
          textAlign: _getAlignmentAtCursor(0),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: true,
            applyHeightToLastDescent: true,
          ),
        ),
      ];
    }
    
    final paragraphs = <Widget>[];
    final textHeightBehavior = const TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    );
    
    // Build a map of position to TextSpan for easier lookup
    final spanMap = <int, TextSpan>{};
    int currentPos = 0;
    for (final span in spans) {
      final spanText = span.text ?? '';
      if (spanText.isNotEmpty) {
        spanMap[currentPos] = span;
        currentPos += spanText.length;
      }
    }
    
    // Split text into paragraphs (by newlines)
    final paragraphRanges = <({int start, int end})>[];
    int paraStart = 0;
    
    for (int i = 0; i <= text.length; i++) {
      if (i == text.length || text[i] == '\n') {
        if (i >= paraStart) {
          paragraphRanges.add((start: paraStart, end: i));
        }
        paraStart = i + 1;
      }
    }
    
    // Build RichText widget for each paragraph with its own alignment
    for (final range in paragraphRanges) {
      if (range.start >= range.end && range.end < text.length) continue;
      
      // Get alignment for this paragraph (use start of paragraph)
      final paragraphAlignment = _getAlignmentAtCursor(range.start);
      
      // Build TextSpans for this paragraph by reconstructing from original spans
      final paragraphSpans = <TextSpan>[];
      int pos = range.start;
      
      while (pos < range.end) {
        // Find which span contains this position
        TextSpan? matchingSpan;
        int spanStart = range.start;
        
        // Check all spans to find one that contains pos
        int checkPos = 0;
        for (final span in spans) {
          final spanText = span.text ?? '';
          final spanEnd = checkPos + spanText.length;
          
          if (pos >= checkPos && pos < spanEnd) {
            matchingSpan = span;
            spanStart = checkPos;
            break;
          }
          checkPos = spanEnd;
        }
        
        if (matchingSpan != null) {
          final spanText = matchingSpan.text ?? '';
          final spanEnd = spanStart + spanText.length;
          final clipEnd = spanEnd < range.end ? spanEnd : range.end;
          final clippedText = text.substring(pos, clipEnd);
          
          paragraphSpans.add(TextSpan(
            text: clippedText,
            style: matchingSpan.style ?? baseStyle,
          ));
          
          pos = clipEnd;
        } else {
          // No matching span, use base style
          final remainingText = text.substring(pos, range.end);
          if (remainingText.isNotEmpty) {
            paragraphSpans.add(TextSpan(
              text: remainingText,
              style: baseStyle,
            ));
          }
          break;
        }
      }
      
      // Create RichText widget for this paragraph
      if (paragraphSpans.isNotEmpty) {
        paragraphs.add(
          RichText(
            text: TextSpan(children: paragraphSpans),
            textAlign: paragraphAlignment,
            textHeightBehavior: textHeightBehavior,
          ),
        );
      } else if (range.start == range.end) {
        // Empty paragraph (just newline) - add empty RichText to maintain spacing
        paragraphs.add(
          RichText(
            text: const TextSpan(text: ' '),
            textAlign: paragraphAlignment,
            textHeightBehavior: textHeightBehavior,
          ),
        );
      }
    }
    
    return paragraphs.isEmpty ? [
      RichText(
        text: TextSpan(children: spans),
        textAlign: _getAlignmentAtCursor(0),
        textHeightBehavior: textHeightBehavior,
      ),
    ] : paragraphs;
  }
  
  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    
    // Build TextSpan with formatting
    List<TextSpan> spans = [];
    int currentPos = 0;
    
    // Base style for unformatted text
    final baseStyle = _getBaseTextStyle();
    
    // Sort formats by start position
    final sortedFormats = List<TextFormat>.from(widget.textFormats)
      ..sort((a, b) => a.start.compareTo(b.start));
    
    for (final format in sortedFormats) {
      // Skip if format is out of bounds or invalid
      if (format.start < 0) continue;
      
      // Handle zero-length formats (for future text at cursor)
      if (format.start == format.end && format.start <= text.length) {
        // Zero-length format - will apply to next character typed
        // Don't add to spans yet, but keep it for when text is typed
        continue;
      }
      
      // Skip if format is completely out of bounds
      if (format.start >= text.length) continue;
      
      // Add unformatted text before this format
      if (format.start > currentPos) {
        spans.add(TextSpan(
          text: text.substring(currentPos, format.start),
          style: baseStyle,
        ));
      }
      
      // Add formatted text
      final formatStart = format.start < 0 ? 0 : format.start;
      final formatEnd = format.end > text.length ? text.length : format.end;
      if (formatEnd > formatStart) {
        final formattedStyle = _getTextStyle(format);
        final formattedText = text.substring(formatStart, formatEnd);
        debugPrint('  ✅ Adding formatted text: "$formattedText" ($formatStart-$formatEnd) with style: ${format.fontFamily}/${format.fontSize}');
        // Use the exact style without overriding height - let each style use its own height
        // This ensures RichText renders exactly as TextField would with that style
        spans.add(TextSpan(
          text: formattedText,
          style: formattedStyle, // Use style as-is to match TextField exactly
        ));
      }
      
      currentPos = formatEnd;
    }
    
    // Add remaining unformatted text
    if (currentPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPos),
        style: baseStyle,
      ));
    }
    
    // Build default text span if no formatting
    if (spans.isEmpty && text.isNotEmpty) {
      spans.add(TextSpan(
        text: text,
        style: baseStyle,
      ));
    }
    
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        selectionColor: (widget.isLightTheme
                ? const Color(0xFF5E3A9E)
                : Colors.white)
            .withValues(alpha: 0.3), // Purple selection highlight
        cursorColor: widget.isLightTheme
            ? const Color(0xFF5E3A9E)
            : Colors.white,
      ),
      child: DefaultTextHeightBehavior(
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: true,
          applyHeightToLastDescent: true,
        ), // Apply consistent textHeightBehavior to both TextField and RichText for multi-line alignment
        child: Stack(
          children: [
            // Display formatted text behind TextField
            // Critical: RichText and TextField must be positioned identically
            // NOTE: RichText can only have one textAlign, so it uses alignment of paragraph containing cursor
            // This is a limitation - per-paragraph alignment requires more complex rendering
            if (text.isNotEmpty && spans.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: RichText(
                    text: TextSpan(children: spans),
                    textAlign: _getAlignmentAtCursor(widget.controller.selection.start),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: true,
                      applyHeightToLastDescent: true,
                    ),
                  ),
                ),
              ),
            // Overlay TextField for editing (transparent text, visible cursor)
            // Use scalable TextField that adjusts cursor/selection height based on font size
            // Ensure TextField matches RichText exactly for perfect alignment
            _buildScalableTextField(baseStyle),
          ],
        ),
      ),
    );
  }
}

/// Glow animation widget for save success
class _GlowAnimation extends StatefulWidget {
  const _GlowAnimation();

  @override
  State<_GlowAnimation> createState() => _GlowAnimationState();
}

class _GlowAnimationState extends State<_GlowAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF5E3A9E),
                  size: 60,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom SoulSync calendar dropdown widget
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

class _SoulSyncCalendarState extends State<_SoulSyncCalendar> with TickerProviderStateMixin {
  late DateTime _currentMonth;
  late AnimationController _monthTransitionController;
  late Animation<double> _monthFadeAnimation;
  bool _showYearSelector = false;
  bool _showMonthSelector = false;
  final ScrollController _yearScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _monthTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _monthFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _monthTransitionController,
        curve: Curves.easeInOut,
      ),
    );
    _monthTransitionController.forward();
  }

  @override
  void dispose() {
    _monthTransitionController.dispose();
    _yearScrollController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    _monthTransitionController.reverse().then((_) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      });
      _monthTransitionController.forward();
    });
  }

  void _nextMonth() {
    _monthTransitionController.reverse().then((_) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      });
      _monthTransitionController.forward();
    });
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    List<DateTime> days = [];
    
    // Add days from previous month to fill first week
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    final prevMonthLastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
    for (int i = firstWeekday - 1; i > 0; i--) {
      days.add(DateTime(prevMonth.year, prevMonth.month, prevMonthLastDay - i + 1));
    }
    
    // Add days of current month
    for (int day = 1; day <= daysInMonth; day++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, day));
    }
    
    // Add days from next month to fill last week
    final remainingDays = 42 - days.length; // 6 weeks * 7 days
    for (int day = 1; day <= remainingDays; day++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month + 1, day));
    }
    
    return days;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _isCurrentMonth(DateTime date) {
    return date.year == _currentMonth.year && date.month == _currentMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF5).withValues(alpha: 0.95), // Soft creamy-beige
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FadeTransition(
            opacity: _monthFadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Month navigation header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _previousMonth,
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFF5E3A9E),
                        size: 28,
                      ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Month selector
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showMonthSelector = !_showMonthSelector;
                              _showYearSelector = false;
                            });
                          },
                          child: Text(
                            DateFormat('MMMM').format(_currentMonth),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5E3A9E),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Year selector
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showYearSelector = !_showYearSelector;
                              _showMonthSelector = false;
                            });
                            // Scroll to current year when opening
                            if (_showYearSelector) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final yearIndex = _currentMonth.year - 2000;
                                final itemHeight = 48.0; // Approximate item height
                                _yearScrollController.animateTo(
                                  yearIndex * itemHeight,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              });
                            }
                          },
                          child: Text(
                            _currentMonth.year.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5E3A9E),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF5E3A9E),
                        size: 28,
                      ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                  ],
                ),
                // Year selector dropdown
                if (_showYearSelector) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.builder(
                      controller: _yearScrollController,
                      itemCount: 50, // Years from 2000 to 2049
                      itemBuilder: (context, index) {
                        final year = 2000 + index;
                        final isSelected = year == _currentMonth.year;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentMonth = DateTime(year, _currentMonth.month);
                              _showYearSelector = false;
                              _monthTransitionController.forward(from: 0.0);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFC3A4F3).withValues(alpha: 0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                year.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: const Color(0xFF5E3A9E),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // Month selector dropdown
                if (_showMonthSelector) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final monthName = DateFormat('MMM').format(DateTime(2024, month));
                        final isSelected = month == _currentMonth.month;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentMonth = DateTime(_currentMonth.year, month);
                              _showMonthSelector = false;
                              _monthTransitionController.forward(from: 0.0);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFC3A4F3).withValues(alpha: 0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                monthName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: const Color(0xFF5E3A9E),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Weekday headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map((day) => SizedBox(
                            width: 36,
                            child: Center(
                              child: Text(
                                day,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                // Calendar grid
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
                    final date = days[index];
                    final isSelected = _isSameDay(date, widget.selectedDate);
                    final isCurrentMonth = _isCurrentMonth(date);
                    final isToday = _isSameDay(date, DateTime.now());

                    return GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus(); // Close keyboard
                        widget.onDateSelected(date);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFB89DF2) // Pastel purple
                              : isToday
                                  ? const Color(0xFFC3A4F3).withValues(alpha: 0.3) // Soft lavender glow
                                  : Colors.transparent,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFB89DF2).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                  // Inner glow
                                  BoxShadow(
                                    color: const Color(0xFFC3A4F3).withValues(alpha: 0.6),
                                    blurRadius: 4,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : isCurrentMonth
                                      ? const Color(0xFF5E3A9E)
                                      : const Color(0xFF5E3A9E).withValues(alpha: 0.3),
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
      ),
    );
  }
}

/// Video thumbnail widget for better preview rendering
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
      final thumbnailPath = await video_thumbnail.VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: video_thumbnail.ImageFormat.PNG,
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
        child: const Center(
          child: CircularProgressIndicator(),
        ),
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

/// Video player widget
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
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
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
/// Font style bottom sheet
class _FontStyleBottomSheet extends StatefulWidget {
  final bool isLightTheme;
  final TextEditingController contentController;
  final TextFormat? currentFormat; // Current format at cursor (for pre-selection)
  final Map<String, dynamic>? mixedStyles; // Mixed styles info for indeterminate state
  final Function(TextFormat) onFormatApplied; // Callback to apply format
  final VoidCallback onClose;

  const _FontStyleBottomSheet({
    required this.isLightTheme,
    required this.contentController,
    this.currentFormat,
    this.mixedStyles,
    required this.onFormatApplied,
    required this.onClose,
  });

  @override
  State<_FontStyleBottomSheet> createState() => _FontStyleBottomSheetState();
}

class _FontStyleBottomSheetState extends State<_FontStyleBottomSheet> 
    with SingleTickerProviderStateMixin {
  late String _selectedFont;
  late String _selectedSize;
  late Color _selectedColor;
  late TextAlign _selectedAlign;
  
  // Track indeterminate states (mixed styles in selection)
  bool _isFontMixed = false;
  bool _isSizeMixed = false;
  bool _isColorMixed = false;
  bool _isAlignMixed = false;
  
  // Custom color not in palette
  Color? _customColor;
  bool _hasCustomColor = false;
  
  // Selection change listener
  Timer? _selectionChangeTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeFromFormat();
    
    // Listen to selection changes (throttled)
    widget.contentController.addListener(_onSelectionChanged);
  }
  
  @override
  void dispose() {
    _selectionChangeTimer?.cancel();
    widget.contentController.removeListener(_onSelectionChanged);
    super.dispose();
  }
  
  void _initializeFromFormat() {
    // Initialize with current format if available, otherwise defaults
    if (widget.currentFormat != null) {
      // Check for mixed styles
      if (widget.mixedStyles != null) {
        _isFontMixed = widget.mixedStyles!['fontFamily'] == null;
        _isSizeMixed = widget.mixedStyles!['fontSize'] == null;
        _isColorMixed = widget.mixedStyles!['color'] == null;
        _isAlignMixed = widget.mixedStyles!['alignment'] == null;
        
        _selectedFont = widget.mixedStyles!['fontFamily'] ?? widget.currentFormat!.fontFamily;
        _selectedSize = widget.mixedStyles!['fontSize'] ?? widget.currentFormat!.fontSize;
        _selectedColor = widget.mixedStyles!['color'] ?? widget.currentFormat!.color;
        _selectedAlign = widget.mixedStyles!['alignment'] ?? widget.currentFormat!.alignment;
      } else {
        _selectedFont = widget.currentFormat!.fontFamily;
        _selectedSize = widget.currentFormat!.fontSize;
        _selectedColor = widget.currentFormat!.color;
        _selectedAlign = widget.currentFormat!.alignment;
        _isFontMixed = false;
        _isSizeMixed = false;
        _isColorMixed = false;
        _isAlignMixed = false;
      }
      
      // Check if color is in palette
      _hasCustomColor = !_colors.contains(_selectedColor);
      if (_hasCustomColor) {
        _customColor = _selectedColor;
      }
      
      debugPrint('🎨 Initialized with current format: $_selectedFont/$_selectedSize');
      debugPrint('🎨 Mixed states: font=$_isFontMixed, size=$_isSizeMixed, color=$_isColorMixed, align=$_isAlignMixed');
    } else {
      // Default settings: Default font, Normal size, White (dark mode) or Dark gray (light mode), Left alignment
      _selectedFont = 'Default';
      _selectedSize = 'Normal';
      _selectedColor = widget.isLightTheme 
          ? const Color(0xFF1E1E1E) // Dark gray for light mode
          : Colors.white; // White for dark mode
      _selectedAlign = TextAlign.left;
      _isFontMixed = false;
      _isSizeMixed = false;
      _isColorMixed = false;
      _isAlignMixed = false;
      _hasCustomColor = false;
    }
  }
  
  // Throttled selection change handler (100ms throttle)
  void _onSelectionChanged() {
    _selectionChangeTimer?.cancel();
    _selectionChangeTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      // Note: Full format re-detection happens when panel is reopened
      // This listener is mainly for future enhancements
      setState(() {
        // Trigger rebuild if needed
      });
    });
  }

  final List<String> _fonts = [
    'Default',
    'Bold',
    'Light',
    'Italic',
    'Merriweather',
    'Monospace',
  ];

  final List<String> _sizes = ['H1', 'H2', 'H3', 'Normal', 'Small'];

  List<Color> get _colors => [
    // Theme-adaptive default color (white for dark mode, dark gray for light mode) - first in list
    widget.isLightTheme ? const Color(0xFF1E1E1E) : Colors.white,
    const Color(0xFF5E3A9E), // Purple accent
    Colors.black,
    const Color(0xFFFFB6C1), // Pink
    const Color(0xFFB0E0E6), // Sky blue
    const Color(0xFFDDA0DD), // Plum
    const Color(0xFFFFE4B5), // Moccasin
    const Color(0xFF98FB98), // Pale green
    const Color(0xFFFFD700), // Gold
    const Color(0xFFF0E68C), // Khaki
  ];

  void _applyStyle() {
    final selection = widget.contentController.selection;
    final text = widget.contentController.text;
    
    debugPrint('🎨 Applying style: selection=${selection.start}-${selection.end}, text length=${text.length}');
    debugPrint('🎨 Selected font: $_selectedFont, size: $_selectedSize, color: $_selectedColor');
    
    // Validate selection indices
    final start = selection.start >= 0 ? selection.start : 0;
    final end = selection.end >= 0 && selection.end <= text.length 
        ? selection.end 
        : text.length;
    final validStart = start <= end ? start : end;
    final validEnd = end >= start ? end : start;
    
    debugPrint('🎨 Valid range: $validStart-$validEnd');
    
    // Determine the range to format
    int formatStart = validStart;
    int formatEnd = validEnd;
    
    // If no text is selected, format will apply to future text
    // Create a zero-length format at cursor that will expand when user types
    if (formatStart == formatEnd) {
      // No selection - format will apply to text typed after this point
      // Store it with the cursor position (zero-length format)
      formatEnd = formatStart;
      debugPrint('🎨 No text selected - creating zero-length format at position $formatStart');
      debugPrint('🎨 This format will expand when user types at position $formatStart');
    } else {
      debugPrint('🎨 Text selected - applying format to range $formatStart-$formatEnd');
      debugPrint('🎨 Selected text: "${text.substring(formatStart, formatEnd)}"');
    }
    
    // CRITICAL FIX: When no text is selected (zero-length format), use the SELECTED style directly
    // Don't merge with current format - the user explicitly selected a style, so use it!
    TextFormat format;
    if (formatStart == formatEnd) {
      // Zero-length format (style before typing) - use the SELECTED values directly
      // This ensures the first typed character uses the style the user selected
      format = TextFormat(
        start: formatStart,
        end: formatEnd,
        fontFamily: _selectedFont,
        fontSize: _selectedSize,
        color: _selectedColor,
        alignment: _selectedAlign,
      );
      debugPrint('🎨 Created zero-length format (style before typing) at $formatStart');
      debugPrint('🎨 Format: font=${format.fontFamily}, size=${format.fontSize}, color=${format.color}, alignment=${format.alignment}');
    } else {
      // Text is selected - create format for selected text
      format = TextFormat(
        start: formatStart,
        end: formatEnd,
        fontFamily: _selectedFont,
        fontSize: _selectedSize,
        color: _selectedColor,
        alignment: _selectedAlign,
      );
      debugPrint('🎨 Created format for selected text: $formatStart-$formatEnd');
    }
    
    // Use callback to apply format (removes overlapping formats in parent)
    widget.onFormatApplied(format);
    
    // Debug: Print format info
    debugPrint('🎨 Applied format: start=$formatStart, end=$formatEnd, font=${format.fontFamily}, size=${format.fontSize}, color=${format.color}');
    
    // Close the panel smoothly
    widget.onClose();
    Navigator.pop(context);
  }

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Font',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: widget.isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_rounded),
                      color: widget.isLightTheme
                          ? const Color(0xFF5E3A9E)
                          : Colors.white,
                      onPressed: _applyStyle,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Font Style',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _fonts.map((font) {
                          final isSelected = !_isFontMixed && _selectedFont == font;
                          final isIndeterminate = _isFontMixed && font == _selectedFont;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedFont = font;
                              _isFontMixed = false; // Clear mixed state when explicitly selected
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (widget.isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                        : Colors.white)
                                    : isIndeterminate
                                        ? (widget.isLightTheme
                                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                                            : Colors.white.withValues(alpha: 0.5))
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected || isIndeterminate
                                      ? Colors.transparent
                                      : (widget.isLightTheme
                                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.3)),
                                  width: isIndeterminate ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    font,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected || isIndeterminate
                                          ? (widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E))
                                          : (widget.isLightTheme
                                              ? const Color(0xFF5E3A9E)
                                              : Colors.white),
                                    ),
                                  ),
                                  if (isIndeterminate)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        '—',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Size',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _sizes.map((size) {
                          final isSelected = !_isSizeMixed && _selectedSize == size;
                          final isIndeterminate = _isSizeMixed && size == _selectedSize;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedSize = size;
                              _isSizeMixed = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (widget.isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                        : Colors.white)
                                    : isIndeterminate
                                        ? (widget.isLightTheme
                                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                                            : Colors.white.withValues(alpha: 0.5))
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected || isIndeterminate
                                      ? Colors.transparent
                                      : (widget.isLightTheme
                                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.3)),
                                  width: isIndeterminate ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    size,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected || isIndeterminate
                                          ? (widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E))
                                          : (widget.isLightTheme
                                              ? const Color(0xFF5E3A9E)
                                              : Colors.white),
                                    ),
                                  ),
                                  if (isIndeterminate)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        '—',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Color',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          // Show custom color if exists and not in palette
                          if (_hasCustomColor && _customColor != null)
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedColor = _customColor!;
                                _isColorMixed = false;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _customColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: !_isColorMixed && _selectedColor == _customColor
                                        ? (widget.isLightTheme
                                            ? const Color(0xFF5E3A9E)
                                            : Colors.white)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: _isColorMixed
                                    ? Center(
                                        child: Text(
                                          '—',
                                          style: TextStyle(
                                            color: widget.isLightTheme
                                                ? Colors.white
                                                : const Color(0xFF5E3A9E),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          // Show palette colors
                          ..._colors.map((color) {
                            final isSelected = !_isColorMixed && _selectedColor == color;
                            final isIndeterminate = _isColorMixed && color == _selectedColor;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedColor = color;
                                _isColorMixed = false;
                                _hasCustomColor = false;
                                _customColor = null;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? (widget.isLightTheme
                                            ? const Color(0xFF5E3A9E)
                                            : Colors.white)
                                        : isIndeterminate
                                            ? (widget.isLightTheme
                                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                                                : Colors.white.withValues(alpha: 0.5))
                                            : Colors.transparent,
                                    width: isSelected ? 3 : (isIndeterminate ? 2 : 0),
                                  ),
                                ),
                                child: isIndeterminate
                                    ? Center(
                                        child: Text(
                                          '—',
                                          style: TextStyle(
                                            color: widget.isLightTheme
                                                ? Colors.white
                                                : const Color(0xFF5E3A9E),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : (isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                                        : null),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Alignment',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAlignButton(Icons.format_align_left, TextAlign.left),
                          _buildAlignButton(Icons.format_align_center, TextAlign.center),
                          _buildAlignButton(Icons.format_align_right, TextAlign.right),
                        ],
                      ),
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

  Widget _buildAlignButton(IconData icon, TextAlign align) {
    final isSelected = !_isAlignMixed && _selectedAlign == align;
    final isIndeterminate = _isAlignMixed && align == _selectedAlign;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedAlign = align;
        _isAlignMixed = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white)
              : isIndeterminate
                  ? (widget.isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.5))
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected || isIndeterminate
                ? Colors.transparent
                : (widget.isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.3)),
            width: isIndeterminate ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected || isIndeterminate
                  ? (widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E))
                  : (widget.isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white),
            ),
            if (isIndeterminate)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '—',
                  style: TextStyle(
                    color: widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// List style bottom sheet
class _ListStyleBottomSheet extends StatelessWidget {
  final bool isLightTheme;
  final TextEditingController contentController;
  final Function(String prefix, bool isNumbered) onListStyleSelected;
  final VoidCallback onClose;

  const _ListStyleBottomSheet({
    required this.isLightTheme,
    required this.contentController,
    required this.onListStyleSelected,
    required this.onClose,
  });

  final List<Map<String, String>> _listStyles = const [
    {'icon': '•', 'name': 'Bullet'},
    {'icon': '★', 'name': 'Star'},
    {'icon': '1.', 'name': 'Numbered'},
    {'icon': '✓', 'name': 'Checkmark'},
    {'icon': '❤', 'name': 'Heart'},
    {'icon': '🌸', 'name': 'Flower'},
    {'icon': '🌿', 'name': 'Leaf'},
    {'icon': '🌈', 'name': 'Rainbow'},
    {'icon': '⭐', 'name': 'Star'},
    {'icon': '💫', 'name': 'Sparkle'},
  ];

  void _insertListStyle(BuildContext context, String prefix) {
    final text = contentController.text;
    final selection = contentController.selection;
    
    // Validate selection indices
    final start = selection.start >= 0 ? selection.start : 0;
    final end = selection.end >= 0 && selection.end <= text.length 
        ? selection.end 
        : text.length;
    final validStart = start <= end ? start : end;
    final validEnd = end >= start ? end : start;
    
    // Check if this is a numbered list
    final isNumbered = prefix.contains('.');
    
    // For numbered lists, always start at 1 when manually selecting
    // (not continuing from a previous list)
    if (isNumbered) {
      // Reset to start numbering from 1 for new list
      onListStyleSelected('1.', isNumbered);
    } else {
      // Notify parent about selected list style
      onListStyleSelected(prefix, isNumbered);
    }
    
    // Always start list on a new line for better UX
    // Determine insertion point and text to insert
    String textToInsert;
    int insertionPoint;
    
    // For numbered lists, use '1.' instead of the prefix from the picker
    final actualPrefix = isNumbered ? '1.' : prefix;
    
    if (text.isEmpty) {
      // Text is completely empty - just insert list prefix
      textToInsert = '$actualPrefix ';
      insertionPoint = 0;
    } else {
      // Text is not empty - always insert newline first, then list prefix
      // This ensures the list starts on a new line, even if cursor is at line start
      textToInsert = '\n$actualPrefix ';
      insertionPoint = validStart;
    }
    
    final newText = text.replaceRange(
      insertionPoint,
      validEnd,
      textToInsert,
    );
    
    // Calculate cursor position (after prefix and space)
    final cursorOffset = insertionPoint + textToInsert.length;
    
    contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursorOffset,
      ),
    );
    onClose();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: isLightTheme
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
                  color: isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'List',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isLightTheme
                        ? const Color(0xFF5E3A9E)
                        : Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _listStyles.length,
                  itemBuilder: (context, index) {
                    final style = _listStyles[index];
                    return GestureDetector(
                      onTap: () => _insertListStyle(context, style['icon']!),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLightTheme
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              style['icon']!,
                              style: TextStyle(
                                fontSize: 32,
                                // Make bullets and numbered icon visible in dark theme
                                color: (style['icon'] == '•' || 
                                        style['icon'] == '★' || 
                                        style['icon'] == '✓' ||
                                        style['icon'] == '1.')
                                    ? (isLightTheme 
                                        ? Colors.black 
                                        : Colors.white)
                                    : null, // Emojis don't need color override
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              style['name']!,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Audio recording bottom sheet
class _AudioRecordingBottomSheet extends StatefulWidget {
  final bool isLightTheme;
  final Function(String) onAudioRecorded;
  final VoidCallback onClose;

  const _AudioRecordingBottomSheet({
    required this.isLightTheme,
    required this.onAudioRecorded,
    required this.onClose,
  });

  @override
  State<_AudioRecordingBottomSheet> createState() => _AudioRecordingBottomSheetState();
}

class _AudioRecordingBottomSheetState extends State<_AudioRecordingBottomSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  
  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final filePath = path.join(appDir.path, 'diary_audio', fileName);
        await Directory(path.dirname(filePath)).create(recursive: true);
        
        await _recorder.start(
          const RecordConfig(),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        
        // Update duration
        _updateDuration();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      if (path != null) {
        widget.onAudioRecorded(path);
        widget.onClose();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
    setState(() {
      _isRecording = false;
    });
  }

  void _updateDuration() {
    if (_isRecording) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isRecording) {
          setState(() {
            _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
          });
          _updateDuration();
        }
      });
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (!mounted) return;
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      // Copy to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(filePath);
      final savedPath = path.join(appDir.path, 'diary_audio', fileName);
      await Directory(path.dirname(savedPath)).create(recursive: true);
      await File(filePath).copy(savedPath);
      
      if (!mounted) return;
      widget.onAudioRecorded(savedPath);
      widget.onClose();
      Navigator.pop(context);
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
                          decoration: BoxDecoration(
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: widget.isLightTheme
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.isLightTheme
                                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
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
                          decoration: BoxDecoration(
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

/// Drawing canvas screen
class _DrawingCanvasScreen extends StatefulWidget {
  final bool isLightTheme;
  final Function(String, String?) onDrawingSaved; // imagePath, drawingDataPath
  final String? existingDrawingDataPath; // For editing existing drawings
  final String? existingImagePath; // For editing existing drawings

  const _DrawingCanvasScreen({
    required this.isLightTheme,
    required this.onDrawingSaved,
    this.existingDrawingDataPath,
    this.existingImagePath,
  });

  @override
  State<_DrawingCanvasScreen> createState() => _DrawingCanvasScreenState();
}

class _DrawingCanvasScreenState extends State<_DrawingCanvasScreen> {
  List<DrawingPoint> _points = [];
  Color _currentColor = Colors.black;
  // ignore: prefer_final_fields
  double _strokeWidth = 3.0;
  // ignore: prefer_final_fields
  Color _backgroundColor = Colors.white;
  final List<List<DrawingPoint>> _history = [];
  int _historyIndex = -1;
  
  @override
  void initState() {
    super.initState();
    // Initialize history with empty state so first drawing can be undone
    _history.add([]);
    _historyIndex = 0;
    // Load existing drawing data if editing
    if (widget.existingDrawingDataPath != null) {
      _loadDrawingData();
    }
  }
  bool _isEraserMode = false;
  // ignore: prefer_final_fields
  double _eraserSize = 20.0;
  int _currentStrokeId = 0;
  Offset? _lastPoint;
  bool _isDrawingActive = false; // Track if we're in the middle of a drawing gesture
  
  
  Future<void> _loadDrawingData() async {
    try {
      final file = File(widget.existingDrawingDataPath!);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final pointsList = (json['points'] as List<dynamic>)
            .map((p) => DrawingPoint.fromJson(p as Map<String, dynamic>))
            .toList();
        
        setState(() {
          _points = pointsList;
          // Find max strokeId to continue from there
          if (_points.isNotEmpty) {
            _currentStrokeId = _points.map((p) => p.strokeId).reduce((a, b) => a > b ? a : b);
          }
          // Initialize history with loaded points
          _history.clear();
          _history.add([]); // Empty initial state
          _history.add(List.from(_points)); // Loaded drawing
          _historyIndex = 1; // Point to loaded drawing
        });
      }
    } catch (e) {
      // If loading fails, start with empty canvas
      // Error loading drawing data - start with empty canvas
      debugPrint('Error loading drawing data: $e');
    }
  }

  void _eraseAtPoint(Offset point) {
    // Erase by drawing with background color (white) instead of removing points
    // This preserves the shape and only erases where touched
    // Check if this is a new eraser stroke (far from last point or last point was not eraser)
    final lastPointWasEraser = _points.isNotEmpty && 
        _points.last.color == _backgroundColor;
    final isNewStroke = _lastPoint == null || 
        !lastPointWasEraser ||
        (_lastPoint != null && (point - _lastPoint!).distance > 50);
    
    if (isNewStroke) {
      _currentStrokeId++; // Start a new stroke group for eraser
    }
    
    setState(() {
      // Add eraser point - these will be drawn but new colored strokes will appear on top
      _points = List.from(_points)..add(DrawingPoint(
        point: point,
        color: _backgroundColor, // Draw with background color to "erase"
        strokeWidth: _eraserSize, // Use eraser size as stroke width
        strokeId: _currentStrokeId, // Use current stroke ID
      ));
      _lastPoint = point;
    });
  }
  
  void _addPoint(Offset point) {
    if (_isEraserMode) {
      _eraseAtPoint(point);
      return;
    }
    
    // Mark that we're starting a new drawing gesture
    _isDrawingActive = true;
    
    // Check if this is a new stroke
    // Always start a new stroke if:
    // 1. No last point (first point ever, or after mode switch)
    // 2. Last point was an eraser point (background color) - ensures new stroke after erasing
    // 3. Far from last point (> 100px) AND we're not already drawing - user lifted finger and started elsewhere
    // Note: Increased threshold to 100px to prevent accidental stroke breaks
    final lastPointWasEraser = _points.isNotEmpty && 
        _points.last.color == _backgroundColor;
    final isNewStroke = _lastPoint == null || 
        lastPointWasEraser ||
        (!_isDrawingActive && _lastPoint != null && (point - _lastPoint!).distance > 100);
    
    if (isNewStroke) {
      _currentStrokeId++; // Start a new stroke group
      // If starting a new stroke after erasing, reset lastPoint to null
      // This ensures the first drawing point doesn't have distance issues with eraser points
      if (lastPointWasEraser) {
        _lastPoint = null;
      }
    }
    
    // Start a new stroke - add first point
    // Create a new list to trigger repaint
    setState(() {
      // Always add new drawing points at the end - this ensures they appear on top of eraser strokes
      _points = List.from(_points)..add(DrawingPoint(
        point: point,
        color: _currentColor,
        strokeWidth: _strokeWidth,
        strokeId: _currentStrokeId,
      ));
      _lastPoint = point; // Set last point to current point for smooth continuation
    });
  }

  void _updatePoint(Offset point) {
    if (_isEraserMode) {
      _eraseAtPoint(point);
      return;
    }
    
    // For continuous drawing within the same stroke
    // _addPoint should have already set up the stroke correctly
    // We just need to continue adding points to the current stroke
    // IMPORTANT: Always use the same strokeId during continuous drawing
    // Don't check distance or eraser points - just continue the current stroke
    
    // Add new point continuously for real-time drawing
    // Create a new list to trigger repaint
    setState(() {
      // Always add new drawing points at the end - this ensures they appear on top of eraser strokes
      _points = List.from(_points)..add(DrawingPoint(
        point: point,
        color: _currentColor,
        strokeWidth: _strokeWidth,
        strokeId: _currentStrokeId, // Same stroke ID for continuous drawing - no checks here!
      ));
      _lastPoint = point; // Update last point for smooth line continuation
    });
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _points.clear();
        _points.addAll(_history[_historyIndex]);
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _points.clear();
        _points.addAll(_history[_historyIndex]);
      });
    }
  }

  // ignore: unused_element
  void _clear() {
    setState(() {
      _points.clear();
      _history.clear();
      _history.add([]); // Empty initial state
      _historyIndex = 0;
      _currentStrokeId = 0;
      _lastPoint = null;
    });
  }

  Future<void> _saveDrawing() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = _backgroundColor
      ..style = PaintingStyle.fill;
    
    // Use the actual canvas size (A4 sheet size) - same calculation as in build
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.85;
    final sheetWidth = maxWidth;
    final sheetHeight = sheetWidth * 1.414;
    final maxHeight = screenSize.height * 0.6;
    final finalHeight = sheetHeight > maxHeight ? maxHeight : sheetHeight;
    final finalWidth = finalHeight / 1.414;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, finalWidth, finalHeight), paint);
    
    // Use the same rendering logic as DrawingPainter to ensure consistency
    // Process points in chronological order: eraser points erase, drawing points draw on top
    if (_points.length > 1) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      
      // Track the last drawing point for each strokeId to connect across eraser points
      final lastDrawingPoint = <int, DrawingPoint?>{};
      
      // Process points in chronological order
      for (int i = 0; i < _points.length; i++) {
        final currentPoint = _points[i];
        
        if (currentPoint.color == _backgroundColor) {
          // This is an eraser point - draw it on top of everything drawn so far
          // This erases/covers the drawing underneath
          final eraserPaint = Paint()
            ..color = _backgroundColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            currentPoint.point,
            currentPoint.strokeWidth / 2,
            eraserPaint,
          );
        } else {
          // This is a drawing point
          final strokeId = currentPoint.strokeId;
          final lastPoint = lastDrawingPoint[strokeId];
          
          if (lastPoint != null) {
            // Connect to the last drawing point in the same stroke
            // This ensures smooth lines even if eraser points are between them
            strokePaint.color = currentPoint.color;
            strokePaint.strokeWidth = currentPoint.strokeWidth;
            canvas.drawLine(lastPoint.point, currentPoint.point, strokePaint);
          }
          
          // Also draw the point itself as a circle for better visibility
          // This ensures single points or points after erasing are visible
          final pointPaint = Paint()
            ..color = currentPoint.color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            currentPoint.point,
            currentPoint.strokeWidth / 2,
            pointPaint,
          );
          
          // Update the last drawing point for this stroke
          lastDrawingPoint[strokeId] = currentPoint;
        }
      }
    } else if (_points.length == 1) {
      // Handle single point case
      final point = _points[0];
      if (point.color == _backgroundColor) {
        // Single eraser point
        final eraserPaint = Paint()
          ..color = _backgroundColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          point.point,
          point.strokeWidth / 2,
          eraserPaint,
        );
      } else {
        // Single drawing point
        final pointPaint = Paint()
          ..color = point.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          point.point,
          point.strokeWidth / 2,
          pointPaint,
        );
      }
    }
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(finalWidth.toInt(), finalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    
    final appDir = await getApplicationDocumentsDirectory();
    
    // Save image
    final imageFileName = widget.existingImagePath != null 
        ? path.basename(widget.existingImagePath!)
        : 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFilePath = widget.existingImagePath ?? 
        path.join(appDir.path, 'diary_drawings', imageFileName);
    await Directory(path.dirname(imageFilePath)).create(recursive: true);
    await File(imageFilePath).writeAsBytes(pngBytes);
    
    // Save drawing data (points) as JSON
    final dataFileName = widget.existingDrawingDataPath != null
        ? path.basename(widget.existingDrawingDataPath!)
        : 'drawing_data_${DateTime.now().millisecondsSinceEpoch}.json';
    final dataFilePath = widget.existingDrawingDataPath ??
        path.join(appDir.path, 'diary_drawings', dataFileName);
    
    final drawingData = {
      'points': _points.map((p) => p.toJson()).toList(),
      'backgroundColor': _backgroundColor.value,
    };
    final jsonString = jsonEncode(drawingData);
    await File(dataFilePath).writeAsString(jsonString);
    
    if (!mounted) return;
    widget.onDrawingSaved(imageFilePath, dataFilePath);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for A4 sheet calculation
    final screenSize = MediaQuery.of(context).size;
    // A4 ratio is approximately 1:1.414 (width:height)
    // Calculate A4 sheet size to fit nicely on screen with padding
    final maxWidth = screenSize.width * 0.85; // 85% of screen width
    final sheetWidth = maxWidth;
    final sheetHeight = sheetWidth * 1.414; // A4 ratio
    final maxHeight = screenSize.height * 0.6; // Max 60% of screen height
    final finalHeight = sheetHeight > maxHeight ? maxHeight : sheetHeight;
    final finalWidth = finalHeight / 1.414; // Recalculate width to maintain ratio
    
    // Theme background color
    final themeBackgroundColor = widget.isLightTheme
        ? const Color(0xFFF8F4FF) // Light theme background (light purplish)
        : const Color(0xFF4A5568); // Dark theme background (soft muted bluish-gray)
    
    return Scaffold(
      backgroundColor: themeBackgroundColor, // Theme background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: widget.isLightTheme
                ? const Color(0xFF5E3A9E)
                : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              color: widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
            onPressed: _historyIndex > 0 ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.redo_rounded,
              color: widget.isLightTheme
                  ? const Color(0xFF5E3A9E)
                  : Colors.white,
            ),
            onPressed: _historyIndex < _history.length - 1 ? _redo : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton(
              onPressed: _saveDrawing,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isLightTheme
                    ? const Color(0xFF5E3A9E)
                    : Colors.white,
                foregroundColor: widget.isLightTheme
                    ? Colors.white
                    : const Color(0xFF5E3A9E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
              child: Text(
                'Done',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // A4 sheet canvas - centered
          Expanded(
            child: Center(
              child: Container(
                width: finalWidth,
                height: finalHeight,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onPanStart: (details) {
                      // Use localPosition directly since GestureDetector provides it relative to child
                      _addPoint(details.localPosition);
                    },
                    onPanUpdate: (details) {
                      // Use localPosition directly since GestureDetector provides it relative to child
                      _updatePoint(details.localPosition);
                    },
                    onPanEnd: (details) {
                      // Finalize the stroke
                      setState(() {
                        if (_historyIndex < _history.length - 1) {
                          _history.removeRange(_historyIndex + 1, _history.length);
                        }
                        _history.add(List.from(_points));
                        _historyIndex = _history.length - 1;
                        // Reset drawing state to allow new stroke detection
                        _isDrawingActive = false;
                        _lastPoint = null;
                      });
                    },
                    child: CustomPaint(
                      key: ValueKey(_points.length), // Force rebuild when points change
                      painter: DrawingPainter(_points, _backgroundColor, Size(finalWidth, finalHeight)),
                      size: Size(finalWidth, finalHeight),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isLightTheme
                  ? Colors.white
                  : Colors.grey[900],
              border: Border(
                top: BorderSide(
                  color: widget.isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Eraser button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEraserMode = !_isEraserMode;
                      // Reset last point when switching to eraser mode
                      // This ensures clean eraser strokes and proper stroke detection when switching back to drawing
                      _lastPoint = null;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isEraserMode
                          ? (widget.isLightTheme
                              ? const Color(0xFF5E3A9E)
                              : Colors.white)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isEraserMode
                            ? Colors.transparent
                            : (widget.isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.3)),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_fix_high_rounded,
                      color: _isEraserMode
                          ? (widget.isLightTheme ? Colors.white : const Color(0xFF5E3A9E))
                          : (widget.isLightTheme
                              ? const Color(0xFF5E3A9E)
                              : Colors.white),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ..._buildColorPalette(),
                const SizedBox(width: 16),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isEraserMode ? Colors.grey : _currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isLightTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _isEraserMode
                      ? Icon(
                          Icons.auto_fix_high_rounded,
                          color: widget.isLightTheme
                              ? const Color(0xFF5E3A9E)
                              : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildColorPalette() {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.pink,
    ];
    return colors.map((color) {
      final isSelected = !_isEraserMode && _currentColor == color;
      return GestureDetector(
        onTap: () {
          setState(() {
            _isEraserMode = false; // Switch to drawing mode when color is selected
            _currentColor = color; // Update color immediately
            // Reset last point when switching from eraser to drawing
            // This ensures the next drawing stroke starts fresh and connects smoothly
            _lastPoint = null;
          });
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? (widget.isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
      );
    }).toList();
  }
}

class DrawingPoint {
  final Offset point;
  final Color color;
  final double strokeWidth;
  final int strokeId; // Group points by stroke to prevent connecting distant strokes

  DrawingPoint({
    required this.point,
    required this.color,
    required this.strokeWidth,
    required this.strokeId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'point': {'dx': point.dx, 'dy': point.dy},
      'color': color.value,
      'strokeWidth': strokeWidth,
      'strokeId': strokeId,
    };
  }
  
  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      point: Offset(
        (json['point'] as Map<String, dynamic>)['dx'] as double,
        (json['point'] as Map<String, dynamic>)['dy'] as double,
      ),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      strokeId: json['strokeId'] as int,
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;
  final Color backgroundColor;
  final Size canvasSize;

  DrawingPainter(this.points, this.backgroundColor, this.canvasSize);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw white background
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    // Use canvasSize if provided, otherwise use size
    final drawSize = canvasSize.width > 0 && canvasSize.height > 0 ? canvasSize : size;
    canvas.drawRect(Rect.fromLTWH(0, 0, drawSize.width, drawSize.height), backgroundPaint);
    
    // Draw points with smooth lines
    if (points.isEmpty) return;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Draw connected lines for smooth real-time strokes
    // IMPORTANT: Process points in chronological order
    // Strategy: Draw points as we encounter them, but eraser points erase what's drawn before,
    // and drawing points after eraser appear on top
    if (points.length > 1) {
      // Track the last drawing point for each strokeId to connect across eraser points
      final lastDrawingPoint = <int, DrawingPoint?>{};
      
      // Process points in chronological order
      for (int i = 0; i < points.length; i++) {
        final currentPoint = points[i];
        
        if (currentPoint.color == backgroundColor) {
          // This is an eraser point - draw it on top of everything drawn so far
          // This erases/covers the drawing underneath
          final eraserPaint = Paint()
            ..color = backgroundColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            currentPoint.point,
            currentPoint.strokeWidth / 2,
            eraserPaint,
          );
        } else {
          // This is a drawing point
          final strokeId = currentPoint.strokeId;
          final lastPoint = lastDrawingPoint[strokeId];
          
          if (lastPoint != null) {
            // Connect to the last drawing point in the same stroke
            // This ensures smooth lines even if eraser points are between them
            paint.color = currentPoint.color;
            paint.strokeWidth = currentPoint.strokeWidth;
            canvas.drawLine(lastPoint.point, currentPoint.point, paint);
          }
          
          // Also draw the point itself as a circle for better visibility
          // This ensures single points or points after erasing are visible
          final pointPaint = Paint()
            ..color = currentPoint.color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            currentPoint.point,
            currentPoint.strokeWidth / 2,
            pointPaint,
          );
          
          // Update the last drawing point for this stroke
          lastDrawingPoint[strokeId] = currentPoint;
        }
      }
    } else if (points.length == 1) {
      // Handle single point case
      final point = points[0];
      if (point.color == backgroundColor) {
        // Single eraser point
        final eraserPaint = Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          point.point,
          point.strokeWidth / 2,
          eraserPaint,
        );
      } else {
        // Single drawing point
        final pointPaint = Paint()
          ..color = point.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          point.point,
          point.strokeWidth / 2,
          pointPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    // Always repaint when points change - ensures real-time updates
    // Simple check: if length changed, definitely repaint
    if (oldDelegate.points.length != points.length) {
      return true;
    }
    // If same length but different list reference, repaint (for eraser)
    if (oldDelegate.points != points) {
      return true;
    }
    // Always repaint to ensure real-time updates
    return true;
  }
}

