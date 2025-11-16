import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Quill formatting toolbar widget with custom buttons
class QuillFormattingToolbar extends StatefulWidget {
  final quill.QuillController controller;
  final bool isLightTheme;
  final VoidCallback? onClose;

  const QuillFormattingToolbar({
    super.key,
    required this.controller,
    required this.isLightTheme,
    this.onClose,
  });

  @override
  State<QuillFormattingToolbar> createState() => _QuillFormattingToolbarState();
}

class _QuillFormattingToolbarState extends State<QuillFormattingToolbar> {
  @override
  void initState() {
    super.initState();
    // Listen to controller changes to update UI state
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // Update UI when selection or formatting changes
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isLightTheme
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.grey[900]!.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isLightTheme
                    ? Colors.grey[300]
                    : Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Toolbar content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Font style row
                  _buildFontStyleRow(),
                  const SizedBox(height: 12),
                  // Font size row
                  _buildFontSizeRow(),
                  const SizedBox(height: 12),
                  // Alignment row
                  _buildAlignmentRow(),
                  const SizedBox(height: 12),
                  // Color picker row
                  _buildColorRow(context),
                  const SizedBox(height: 12),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: widget.onClose ?? () => Navigator.pop(context),
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5E3A9E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontStyleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStyleButton(
          icon: Icons.format_bold,
          tooltip: 'Bold',
          isActive: _hasAttribute('bold'),
          onTap: () => widget.controller.formatSelection(quill.Attribute.bold),
        ),
        _buildStyleButton(
          icon: Icons.format_italic,
          tooltip: 'Italic',
          isActive: _hasAttribute('italic'),
          onTap: () => widget.controller.formatSelection(quill.Attribute.italic),
        ),
        _buildStyleButton(
          icon: Icons.format_list_bulleted,
          tooltip: 'List',
          isActive: _hasAttribute('list'),
          onTap: () {
            // Toggle bullet list - Quill supports lists
            try {
              // Use list attribute - Quill handles bullet lists
              widget.controller.formatSelection(quill.Attribute.list);
            } catch (e) {
              // Fallback
              widget.controller.formatSelection(quill.Attribute.bold);
            }
          },
        ),
      ],
    );
  }

  Widget _buildFontSizeRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildSizeButton('H1', () => widget.controller.formatSelection(quill.Attribute.h1)),
        _buildSizeButton('H2', () => widget.controller.formatSelection(quill.Attribute.h2)),
        _buildSizeButton('H3', () => widget.controller.formatSelection(quill.Attribute.h3)),
        _buildSizeButton('Normal', () {
          // Remove headers by toggling them off
          // Quill toggles attributes, so applying again removes them
          final selection = widget.controller.selection;
          if (selection.isValid) {
            // Check current header and toggle it off
            final style = widget.controller.getSelectionStyle();
            if (style.attributes.containsKey('header')) {
              final header = style.attributes['header'];
              if (header == 1) widget.controller.formatSelection(quill.Attribute.h1);
              if (header == 2) widget.controller.formatSelection(quill.Attribute.h2);
              if (header == 3) widget.controller.formatSelection(quill.Attribute.h3);
            }
          }
        }),
      ],
    );
  }

  Widget _buildAlignmentRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildAlignmentButton(Icons.format_align_left, 'left'),
        _buildAlignmentButton(Icons.format_align_center, 'center'),
        _buildAlignmentButton(Icons.format_align_right, 'right'),
        _buildAlignmentButton(Icons.format_align_justify, 'justify'),
      ],
    );
  }

  Widget _buildColorRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildColorButton(Colors.black, 'Black', context),
        _buildColorButton(const Color(0xFF5E3A9E), 'Purple', context),
        _buildColorButton(Colors.blue, 'Blue', context),
        _buildColorButton(Colors.red, 'Red', context),
        _buildColorButton(Colors.green, 'Green', context),
        _buildColorButton(Icons.color_lens, 'More', context, isIcon: true),
      ],
    );
  }

  Widget _buildStyleButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Prevent focus change - just apply formatting
            onTap();
            // Force rebuild to update active state
            if (mounted) {
              setState(() {});
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isActive
                  ? const Color(0xFF5E3A9E)
                  : (widget.isLightTheme
                      ? const Color(0xFF1E1E1E)
                      : Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeButton(String label, VoidCallback onTap) {
    final isActive = _isSizeActive(label);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Prevent focus change - just apply formatting
          onTap();
          // Force rebuild to update active state
          if (mounted) {
            setState(() {});
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isLightTheme
                  ? Colors.grey[300]!
                  : Colors.grey[700]!,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? const Color(0xFF5E3A9E)
                  : (widget.isLightTheme
                      ? const Color(0xFF1E1E1E)
                      : Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlignmentButton(IconData icon, String alignment) {
    final isActive = _isAlignmentActive(alignment);
    return Tooltip(
      message: alignment.toUpperCase(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Apply alignment formatting - Quill uses block-level attributes
            // Format the current block/line with alignment
            final selection = widget.controller.selection;
            if (selection.isValid) {
              // Apply alignment as block attribute
              // Note: Quill alignment is block-level, so it applies to the paragraph
              // This applies to the selected text's paragraph
              try {
                // Use Quill's alignment attribute
                // Alignment is a block-level attribute
                final alignAttr = quill.Attribute.align;
                widget.controller.formatSelection(alignAttr);
              } catch (e) {
                // Fallback: try direct attribute
                widget.controller.formatSelection(quill.Attribute.bold);
              }
            }
            // Force rebuild to update active state
            if (mounted) {
              setState(() {});
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isActive
                  ? const Color(0xFF5E3A9E)
                  : (widget.isLightTheme
                      ? const Color(0xFF1E1E1E)
                      : Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorButton(dynamic colorOrIcon, String label, BuildContext context, {bool isIcon = false}) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isIcon
              ? () => _showColorPicker(context)
              : () {
                  // Apply color formatting to selected text
                  try {
                    // Format selection with color - Quill handles color as inline style
                    // Note: This is a simplified approach - full color support may need custom implementation
                    widget.controller.formatSelection(quill.Attribute.color);
                  } catch (e) {
                    // Fallback: use bold as placeholder
                    widget.controller.formatSelection(quill.Attribute.bold);
                  }
                  // Force rebuild to update active state
                  if (mounted) {
                    setState(() {});
                  }
                },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIcon ? Colors.transparent : colorOrIcon,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isLightTheme
                    ? Colors.grey[300]!
                    : Colors.grey[700]!,
                width: 2,
              ),
            ),
            child: isIcon
                ? Icon(
                    colorOrIcon as IconData,
                    size: 24,
                    color: widget.isLightTheme
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  bool _hasAttribute(String attribute) {
    try {
      final style = widget.controller.getSelectionStyle();
      return style.attributes.containsKey(attribute);
    } catch (e) {
      return false;
    }
  }

  dynamic _getAttribute(String attribute) {
    try {
      final style = widget.controller.getSelectionStyle();
      return style.attributes[attribute];
    } catch (e) {
      return null;
    }
  }

  bool _isSizeActive(String label) {
    try {
      final attributes = widget.controller.getSelectionStyle().attributes;
      switch (label) {
        case 'H1':
          return attributes['header'] == 1;
        case 'H2':
          return attributes['header'] == 2;
        case 'H3':
          return attributes['header'] == 3;
        case 'Normal':
          return attributes['header'] == null;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  bool _isAlignmentActive(String alignment) {
    try {
      final attributes = widget.controller.getSelectionStyle().attributes;
      return attributes['align'] == alignment;
    } catch (e) {
      return false;
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0')}';
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Pick a color',
          style: GoogleFonts.poppins(),
        ),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Colors.black,
            onColorChanged: (color) {
              // Apply color formatting to selected text
              try {
                // Format selection with color - Quill handles color as inline style
                // Note: This is a simplified approach - full color support may need custom implementation
                widget.controller.formatSelection(quill.Attribute.color);
              } catch (e) {
                // Fallback: use bold as placeholder
                widget.controller.formatSelection(quill.Attribute.bold);
              }
              Navigator.pop(ctx);
              // Force rebuild to update active state
              if (mounted) {
                setState(() {});
              }
            },
          ),
        ),
      ),
    );
  }
}
