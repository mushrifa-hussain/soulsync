import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:soulsync_dairyapp/providers/ai_chat_provider.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/widgets/ai_chat_bubble.dart';
import 'package:soulsync_dairyapp/widgets/typing_indicator.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isInputFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Clear chat history when opening the page (start fresh each time)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AIChatProvider>(context, listen: false);
      provider.clearChat();
    });

    _focusNode.addListener(() {
      setState(() {
        _isInputFocused = _focusNode.hasFocus;
      });
      
      // Scroll to bottom when keyboard opens
      if (_focusNode.hasFocus) {
        // Delay to ensure keyboard is fully shown
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _scrollToBottom();
          }
        });
      }
    });

    _messageController.addListener(() {
      setState(() {
        _hasText = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomImmediate() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _focusNode.unfocus();

    final provider = Provider.of<AIChatProvider>(context, listen: false);
    await provider.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _generateSummary() async {
    final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
    final diaryProvider = Provider.of<DiaryEntriesProvider>(context, listen: false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B4C93)),
        ),
      ),
    );

    try {
      final summary = await chatProvider.generateSummary();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (summary == null || summary.isEmpty) {
        _showErrorDialog('Failed to generate summary. Please try again.');
        return;
      }

      // Create diary entry from summary
      final now = DateTime.now();
      final entry = DiaryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateFormat('yyyy-MM-dd').format(now),
        title: 'AI Conversation Summary',
        content: summary,
        mood: '🤔',
        timestamp: now,
      );

      await diaryProvider.saveEntry(entry);

      if (!mounted) return;

      // Clear chat history after successful summary
      await chatProvider.clearChat();

      // Show success animation
      _showSuccessDialog(() {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showErrorDialog('Error saving summary: $e');
    }
  }

  void _showSuccessDialog(VoidCallback onComplete) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6B4C93),
                      const Color(0xFF8B6FA8),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Summary Saved! ✨',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5E3A9E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your conversation has been saved as a diary entry.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4C93),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Go to Home',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Error',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5E3A9E),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B4C93),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildContent(context, isLightTheme, isDarkTheme);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isLightTheme, bool isDarkTheme) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Clear chat history when user presses back
        final provider = Provider.of<AIChatProvider>(context, listen: false);
        await provider.clearChat();
        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: ThemeBackgroundWrapper(
          child: Container(
          decoration: BoxDecoration(
            // Add subtle gradient overlay for premium feel
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkTheme
                  ? [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                    ]
                  : [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.05),
                    ],
            ),
          ),
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // App Bar
                    _buildAppBar(isLightTheme, isDarkTheme),
                    
                    // Chat Messages
                    Expanded(
                      child: Consumer<AIChatProvider>(
                        builder: (context, provider, child) {
                          // Scroll to bottom when new messages arrive or when typing
                          if (provider.messages.isNotEmpty || provider.isTyping) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToBottomImmediate();
                            });
                          }

                          if (provider.messages.isEmpty && !provider.isTyping) {
                            return _buildEmptyState(isLightTheme, isDarkTheme);
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              top: 16,
                              bottom: 16,
                              left: 8,
                              right: 8,
                            ),
                            itemCount: provider.messages.length + (provider.isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == provider.messages.length) {
                                return const TypingIndicator();
                              }
                              
                              final message = provider.messages[index];
                              return message.sender == 'user'
                                  ? UserChatBubble(message: message)
                                  : AIChatBubble(message: message);
                            },
                          );
                        },
                      ),
                    ),

                    // Summary Button (only after 3 user messages, hide when keyboard is visible)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                        final isKeyboardVisible = keyboardHeight > 0;
                        
                        if (isKeyboardVisible) {
                          return const SizedBox.shrink();
                        }
                        
                        return Consumer<AIChatProvider>(
                          builder: (context, provider, child) {
                            if (provider.userMessageCount < 3) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ElevatedButton.icon(
                                onPressed: provider.isLoading ? null : _generateSummary,
                                icon: provider.isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.book_outlined, size: 18),
                                label: Text(
                                  'Summarize into Diary Entry',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B4C93),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Input Bar - positioned directly above keyboard
                    _buildInputBar(isLightTheme, isDarkTheme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isLightTheme, bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDarkTheme ? Colors.white : const Color(0xFF5E3A9E),
              size: 20,
            ),
            onPressed: () async {
              // Clear chat history when back is pressed
              final provider = Provider.of<AIChatProvider>(context, listen: false);
              await provider.clearChat();
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6B4C93),
                  const Color(0xFF8B6FA8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B4C93).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SoulSync AI',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF5E3A9E),
                  ),
                ),
                Text(
                  'Your emotional companion',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDarkTheme
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isLightTheme, bool isDarkTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6B4C93),
                    const Color(0xFF8B6FA8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4C93).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'I\'m here for you 💜',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.white : const Color(0xFF5E3A9E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Talk to me about anything. I\'m here to listen and help you reflect.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkTheme
                    ? Colors.white.withValues(alpha: 0.7)
                    : const Color(0xFF5E3A9E).withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isLightTheme, bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkTheme
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isInputFocused
                      ? const Color(0xFF6B4C93)
                      : (isDarkTheme
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFF6B4C93).withValues(alpha: 0.2)),
                  width: _isInputFocused ? 2 : 1,
                ),
                boxShadow: _isInputFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6B4C93).withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: isDarkTheme ? Colors.white : const Color(0xFF5E3A9E),
                ),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    color: isDarkTheme
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF5E3A9E).withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Consumer<AIChatProvider>(
            builder: (context, provider, child) {
              final canSend = _hasText && !provider.isTyping;

              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: canSend
                        ? [
                            const Color(0xFF6B4C93),
                            const Color(0xFF8B6FA8),
                          ]
                        : [
                            Colors.grey.shade400,
                            Colors.grey.shade500,
                          ],
                  ),
                  boxShadow: canSend
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6B4C93).withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canSend ? _sendMessage : null,
                    borderRadius: BorderRadius.circular(24),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
