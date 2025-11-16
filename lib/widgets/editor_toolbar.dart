import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Persistent formatting toolbar for the Quill editor
///
/// This toolbar stays visible while the editor is active and allows users to:
/// - Apply multiple formatting options before committing
/// - Preview changes in real-time
/// - Commit all changes with the Done button
///
/// Usage:
/// ```dart
/// EditorToolbar(
///   controller: quillController,
///   onDone: () {
///     // Commit changes and hide toolbar
///   },
///   onCancel: () {
///     // Revert staged changes
///   },
/// )
/// ```
class EditorToolbar extends StatefulWidget {
  final quill.QuillController controller;
  final VoidCallback onDone;
  final VoidCallback? onCancel;
  final bool autoApplyOnBlur;

  const EditorToolbar({
    super.key,
    required this.controller,
    required this.onDone,
    this.onCancel,
    this.autoApplyOnBlur = false,
  });

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  // Track staged changes for preview (currently not used but kept for future enhancement)
  // Color? _stagedColor;
  // String? _stagedFontSize;
  // String? _stagedAlignment;
  // String? _stagedListType;
  // int? _stagedIndent;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Get default text color based on theme
  Color _getDefaultTextColor() {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.light) {
      // Light theme: use primary purple
      return Theme.of(context).colorScheme.primary;
    } else {
      // Dark/Black theme: use white
      return Colors.white;
    }
  }

  /// Apply formatting (changes are immediate in Quill)
  void _applyFormatPreview(String attribute, dynamic value) {
    // Apply to selection immediately for preview
    try {
      switch (attribute) {
        case 'bold':
          final isBold = _hasAttribute('bold');
          widget.controller.formatSelection(
            isBold
                ? quill.Attribute.clone(quill.Attribute.bold, null)
                : quill.Attribute.bold,
          );
          break;
        case 'italic':
          final isItalic = _hasAttribute('italic');
          widget.controller.formatSelection(
            isItalic
                ? quill.Attribute.clone(quill.Attribute.italic, null)
                : quill.Attribute.italic,
          );
          break;
        case 'underline':
          final isUnderline = _hasAttribute('underline');
          widget.controller.formatSelection(
            isUnderline
                ? quill.Attribute.clone(quill.Attribute.underline, null)
                : quill.Attribute.underline,
          );
          break;
        case 'strike':
          final isStrike = _hasAttribute('strike');
          widget.controller.formatSelection(
            isStrike
                ? quill.Attribute.clone(quill.Attribute.strikeThrough, null)
                : quill.Attribute.strikeThrough,
          );
          break;
        case 'color':
          if (value is Color) {
            // Convert color to hex string for Quill
            final hexColor =
                '#${value.value.toRadixString(16).padLeft(8, '0').substring(2)}';
            widget.controller.formatSelection(
              quill.Attribute.fromKeyValue('color', hexColor),
            );
          }
          break;
        case 'size':
          if (value is String) {
            // Remove existing headers first
            _removeHeaderFormat();
            // Apply new header
            switch (value) {
              case 'H1':
                widget.controller.formatSelection(quill.Attribute.h1);
                break;
              case 'H2':
                widget.controller.formatSelection(quill.Attribute.h2);
                break;
              case 'H3':
                widget.controller.formatSelection(quill.Attribute.h3);
                break;
              case 'Normal':
                // Already removed above
                break;
            }
          }
          break;
        case 'align':
          if (value is String) {
            // Check current alignment
            final currentAlign = _getAttribute('align');
            final currentAlignValue =
                currentAlign?.toString().toLowerCase() ?? 'left';

            // Apply specific alignment or remove if already active
            switch (value) {
              case 'left':
                widget.controller.formatSelection(
                  currentAlignValue == 'left'
                      ? quill.Attribute.clone(
                          quill.Attribute.leftAlignment,
                          null,
                        )
                      : quill.Attribute.leftAlignment,
                );
                break;
              case 'center':
                widget.controller.formatSelection(
                  currentAlignValue == 'center'
                      ? quill.Attribute.clone(
                          quill.Attribute.centerAlignment,
                          null,
                        )
                      : quill.Attribute.centerAlignment,
                );
                break;
              case 'right':
                widget.controller.formatSelection(
                  currentAlignValue == 'right'
                      ? quill.Attribute.clone(
                          quill.Attribute.rightAlignment,
                          null,
                        )
                      : quill.Attribute.rightAlignment,
                );
                break;
              case 'justify':
                widget.controller.formatSelection(
                  currentAlignValue == 'justify'
                      ? quill.Attribute.clone(
                          quill.Attribute.justifyAlignment,
                          null,
                        )
                      : quill.Attribute.justifyAlignment,
                );
                break;
            }
          }
          break;
        case 'list':
          if (value == 'bullet') {
            // Check if bullet list is already active
            final listAttr = _getAttribute('list');
            final listValue = listAttr?.toString().toLowerCase() ?? '';
            final isBullet = listValue == 'bullet' || listValue == 'ul';

            widget.controller.formatSelection(
              isBullet
                  ? quill.Attribute.clone(
                      quill.Attribute.ul,
                      null,
                    ) // Remove if active
                  : quill.Attribute.ul, // Apply if not active
            );
          } else if (value == 'ordered') {
            // Check if ordered list is already active
            final listAttr = _getAttribute('list');
            final listValue = listAttr?.toString().toLowerCase() ?? '';
            final isOrdered = listValue == 'ordered' || listValue == 'ol';

            widget.controller.formatSelection(
              isOrdered
                  ? quill.Attribute.clone(
                      quill.Attribute.ol,
                      null,
                    ) // Remove if active
                  : quill.Attribute.ol, // Apply if not active
            );
          } else if (value == null) {
            // Remove list - toggle off current list
            final currentList = _getAttribute('list');
            if (currentList == 'bullet' || currentList == 'ul') {
              widget.controller.formatSelection(
                quill.Attribute.clone(quill.Attribute.ul, null),
              );
            } else if (currentList == 'ordered' || currentList == 'ol') {
              widget.controller.formatSelection(
                quill.Attribute.clone(quill.Attribute.ol, null),
              );
            }
          }
          break;
        case 'indent':
          if (value == 'increase') {
            final currentIndent = _getListLevel();
            if (currentIndent < 3) {
              widget.controller.formatSelection(
                quill.Attribute.getIndentLevel(currentIndent + 1),
              );
            }
          } else if (value == 'decrease') {
            final currentIndent = _getListLevel();
            if (currentIndent > 0) {
              widget.controller.formatSelection(
                quill.Attribute.getIndentLevel(currentIndent - 1),
              );
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('Error applying format: $e');
    }
  }

  void _removeHeaderFormat() {
    final style = widget.controller.getSelectionStyle();
    final header = style.attributes['header'];
    if (header != null) {
      final headerValue = header.value;
      if (headerValue == 1) {
        widget.controller.formatSelection(quill.Attribute.h1);
      } else if (headerValue == 2) {
        widget.controller.formatSelection(quill.Attribute.h2);
      } else if (headerValue == 3) {
        widget.controller.formatSelection(quill.Attribute.h3);
      }
    }
  }

  /// Commit all staged changes
  void _commitChanges() {
    // Changes are already applied in Quill (preview mode)
    // Just close the toolbar
    widget.onDone();
  }

  /// Check if attribute is active
  bool _hasAttribute(String attribute) {
    try {
      final style = widget.controller.getSelectionStyle();
      return style.attributes.containsKey(attribute);
    } catch (e) {
      return false;
    }
  }

  /// Get current attribute value
  dynamic _getAttribute(String attribute) {
    try {
      final style = widget.controller.getSelectionStyle();
      final attr = style.attributes[attribute];
      // Attributes from Quill are always Attribute objects
      return attr?.value;
    } catch (e) {
      return null;
    }
  }

  /// Get current list level
  int _getListLevel() {
    try {
      final style = widget.controller.getSelectionStyle();
      final indent = style.attributes['indent'];
      if (indent != null) {
        final value = indent.value;
        if (value is num) {
          return value.toInt().clamp(0, 3);
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.white.withValues(alpha: 0.98)
            : Colors.grey[900]!.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 8,
          ),
          child: Row(
            children: [
              // Fixed close button
              Container(
                padding: const EdgeInsets.only(left: 12),
                child: IconButton(
                  onPressed: _commitChanges,
                  icon: Icon(
                    Icons.close_rounded,
                    color: isLightTheme ? colorScheme.primary : Colors.white,
                  ),
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: isLightTheme
                        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),

              // Scrollable buttons
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 6),
                  child: Row(
                    children: [
                      // Text styles
                      _buildToggleButton(
                        icon: Icons.format_bold,
                        tooltip: 'Bold',
                        isActive: _hasAttribute('bold'),
                        onTap: () => _applyFormatPreview('bold', true),
                        colorScheme: colorScheme,
                        isLightTheme: isLightTheme,
                      ),
                      const SizedBox(width: 8),
                      _buildToggleButton(
                        icon: Icons.format_italic,
                        tooltip: 'Italic',
                        isActive: _hasAttribute('italic'),
                        onTap: () => _applyFormatPreview('italic', true),
                        colorScheme: colorScheme,
                        isLightTheme: isLightTheme,
                      ),
                      const SizedBox(width: 8),
                      _buildToggleButton(
                        icon: Icons.format_underlined,
                        tooltip: 'Underline',
                        isActive: _hasAttribute('underline'),
                        onTap: () => _applyFormatPreview('underline', true),
                        colorScheme: colorScheme,
                        isLightTheme: isLightTheme,
                      ),
                      const SizedBox(width: 8),
                      _buildToggleButton(
                        icon: Icons.strikethrough_s,
                        tooltip: 'Strikethrough',
                        isActive: _hasAttribute('strike'),
                        onTap: () => _applyFormatPreview('strike', true),
                        colorScheme: colorScheme,
                        isLightTheme: isLightTheme,
                      ),
                      const SizedBox(width: 16),
                      // Divider
                      Container(
                        width: 1,
                        height: 32,
                        color: isLightTheme
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                      const SizedBox(width: 16),
                      // Lists
                      _buildListButtons(colorScheme, isLightTheme),
                      const SizedBox(width: 16),
                      // Divider
                      Container(
                        width: 1,
                        height: 32,
                        color: isLightTheme
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                      const SizedBox(width: 16),
                      // Font size
                      _buildFontSizeButton(colorScheme, isLightTheme),
                      const SizedBox(width: 16),
                      // Divider
                      Container(
                        width: 1,
                        height: 32,
                        color: isLightTheme
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                      const SizedBox(width: 16),
                      // Alignment
                      _buildAlignmentButtons(colorScheme, isLightTheme),
                      const SizedBox(width: 16),
                      // Divider
                      Container(
                        width: 1,
                        height: 32,
                        color: isLightTheme
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                      const SizedBox(width: 16),
                      // Color picker button
                      _buildColorPickerButton(
                        _getDefaultTextColor(),
                        colorScheme,
                        isLightTheme,
                      ),
                      const SizedBox(width: 12),
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

  Widget _buildListButtons(ColorScheme colorScheme, bool isLightTheme) {
    final listLevel = _getListLevel();
    final listAttr = _getAttribute('list');
    final listValue = listAttr?.toString().toLowerCase() ?? '';
    final isBullet = listValue == 'bullet' || listValue == 'ul';
    final isOrdered = listValue == 'ordered' || listValue == 'ol';

    return Row(
      children: [
        _buildToggleButton(
          icon: Icons.format_list_bulleted,
          tooltip: 'Bullet List',
          isActive: isBullet,
          onTap: () => _applyFormatPreview('list', isBullet ? null : 'bullet'),
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
        const SizedBox(width: 8),
        _buildToggleButton(
          icon: Icons.format_list_numbered,
          tooltip: 'Numbered List',
          isActive: isOrdered,
          onTap: () =>
              _applyFormatPreview('list', isOrdered ? null : 'ordered'),
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
        const SizedBox(width: 8),
        _buildToggleButton(
          icon: Icons.format_indent_increase,
          tooltip: 'Indent',
          isActive: false,
          onTap: listLevel < 3
              ? () => _applyFormatPreview('indent', 'increase')
              : null,
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
        const SizedBox(width: 8),
        _buildToggleButton(
          icon: Icons.format_indent_decrease,
          tooltip: 'Outdent',
          isActive: false,
          onTap: listLevel > 0
              ? () => _applyFormatPreview('indent', 'decrease')
              : null,
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
      ],
    );
  }

  Widget _buildAlignmentButtons(ColorScheme colorScheme, bool isLightTheme) {
    return Row(
      children: [
        _buildToggleButton(
          icon: Icons.format_align_left,
          tooltip: 'Align Left',
          isActive:
              _getAttribute('align') == 'left' ||
              _getAttribute('align') == null,
          onTap: () => _applyFormatPreview('align', 'left'),
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
        const SizedBox(width: 8),
        _buildToggleButton(
          icon: Icons.format_align_center,
          tooltip: 'Align Center',
          isActive: _getAttribute('align') == 'center',
          onTap: () => _applyFormatPreview('align', 'center'),
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
        const SizedBox(width: 8),
        _buildToggleButton(
          icon: Icons.format_align_right,
          tooltip: 'Align Right',
          isActive: _getAttribute('align') == 'right',
          onTap: () => _applyFormatPreview('align', 'right'),
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
        const SizedBox(width: 8),
        _buildToggleButton(
          icon: Icons.format_align_justify,
          tooltip: 'Justify',
          isActive: _getAttribute('align') == 'justify',
          onTap: () => _applyFormatPreview('align', 'justify'),
          colorScheme: colorScheme,
          isLightTheme: isLightTheme,
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback? onTap,
    required ColorScheme colorScheme,
    required bool isLightTheme,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? colorScheme.primary
                      : (isLightTheme ? Colors.grey[300]! : Colors.grey[700]!),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isActive
                    ? colorScheme.primary
                    : (isLightTheme ? Colors.grey[800] : Colors.grey[300]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeButton(ColorScheme colorScheme, bool isLightTheme) {
    final currentSize = _getCurrentFontSize();

    return PopupMenuButton<String>(
      tooltip: 'Font Size',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLightTheme ? Colors.grey[300]! : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            currentSize,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isLightTheme ? Colors.grey[800] : Colors.grey[300],
            ),
          ),
        ),
      ),
      onSelected: (value) {
        _applyFormatPreview('size', value);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'H1', child: Text('H1')),
        const PopupMenuItem(value: 'H2', child: Text('H2')),
        const PopupMenuItem(value: 'H3', child: Text('H3')),
        const PopupMenuItem(value: 'Normal', child: Text('Normal')),
      ],
    );
  }

  String _getCurrentFontSize() {
    final header = _getAttribute('header');
    if (header == null) return 'Normal';
    if (header == 1) return 'H1';
    if (header == 2) return 'H2';
    if (header == 3) return 'H3';
    return 'Normal';
  }

  Widget _buildColorPickerButton(
    Color currentColor,
    ColorScheme colorScheme,
    bool isLightTheme,
  ) {
    return Semantics(
      label: 'More Colors',
      button: true,
      child: Tooltip(
        message: 'More Colors',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showColorPickerDialog(currentColor),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLightTheme ? Colors.grey[300]! : Colors.grey[700]!,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.color_lens,
                size: 22,
                color: isLightTheme ? Colors.grey[800] : Colors.grey[300],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPickerDialog(Color currentColor) {
    Color selectedColor = currentColor;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Pick a Color',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              selectedColor = color;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFormatPreview('color', selectedColor);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
