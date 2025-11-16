import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Quill-based rich text editor widget with theme-aware default colors
class QuillTextEditor extends StatefulWidget {
  final quill.QuillController controller;
  final bool isLightTheme;
  final FocusNode? focusNode;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onSelectionChanged;
  final String? placeholder; // Placeholder text hint

  const QuillTextEditor({
    super.key,
    required this.controller,
    required this.isLightTheme,
    this.focusNode,
    this.onTextChanged,
    this.onSelectionChanged,
    this.placeholder,
  });

  @override
  State<QuillTextEditor> createState() => _QuillTextEditorState();
}

class _QuillTextEditorState extends State<QuillTextEditor> {
  late FocusNode _internalFocusNode;
  bool _isInitialized = false;
  bool _previousFocusState = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onControllerChanged);
    
    // Listen to focus changes to update placeholder visibility
    _internalFocusNode.addListener(_onFocusChanged);
    _previousFocusState = _internalFocusNode.hasFocus;
    
    // Set default text color based on theme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setDefaultTextColor();
    });
  }
  
  void _onFocusChanged() {
    final currentFocus = _internalFocusNode.hasFocus;
    if (currentFocus != _previousFocusState) {
      _previousFocusState = currentFocus;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(QuillTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLightTheme != widget.isLightTheme) {
      // Theme changed - update default color
      _setDefaultTextColor();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _internalFocusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.onTextChanged != null) {
      final plainText = widget.controller.document.toPlainText();
      widget.onTextChanged!(plainText);
    }
    if (widget.onSelectionChanged != null) {
      widget.onSelectionChanged!();
    }
  }

  /// Set default text color based on theme
  void _setDefaultTextColor() {
    if (_isInitialized) return;
    
    // Only set default color if document is empty or has no color formatting
    if (widget.controller.document.length <= 1) {
      // Document is empty or just has newline - set default color for next typed text
      try {
        // Set default color using formatSelection (applies to next typed characters)
        // Note: This sets up the color attribute for future text
        widget.controller.formatSelection(quill.Attribute.color);
        _isInitialized = true;
      } catch (e) {
        debugPrint('Error setting default text color: $e');
        _isInitialized = true;
      }
    } else {
      _isInitialized = true;
    }
  }


  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.controller.document.toPlainText().trim().isEmpty;
    final hasFocus = _internalFocusNode.hasFocus;
    
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: quill.QuillEditor.basic(
            controller: widget.controller,
            focusNode: _internalFocusNode,
          ),
        ),
        // Show placeholder when empty and not focused
        // Use IgnorePointer to prevent placeholder from blocking input
        if (widget.placeholder != null && isEmpty && !hasFocus)
          IgnorePointer(
            child: Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 0, top: 0),
                child: Text(
                  widget.placeholder!,
                  style: TextStyle(
                    color: widget.isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
