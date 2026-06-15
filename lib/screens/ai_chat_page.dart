import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:soulsync_dairyapp/providers/ai_chat_provider.dart';
import 'package:soulsync_dairyapp/widgets/ai_chat_bubble.dart';
import 'package:soulsync_dairyapp/widgets/typing_indicator.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';
import 'package:soulsync_dairyapp/services/aiml_api_service.dart';
import 'package:soulsync_dairyapp/screens/new_entry_screen.dart';
import 'package:soulsync_dairyapp/services/theme_storage_service.dart';

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
      onPopInvokedWithResult: (didPop, result) async {
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
            child: ClipOval(
              child: Image.asset(
                'assets/images/ai_face_mouth.jpg',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey,
                    child: const Icon(Icons.error, color: Colors.white, size: 20),
                  );
                },
              ),
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
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ai_face_mouth.jpg',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey,
                      child: const Icon(Icons.error, color: Colors.white, size: 50),
                    );
                  },
                ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Save as Diary Entry button - above the input row
          Consumer<AIChatProvider>(
            builder: (context, provider, child) {
              final userMessageCount = provider.userMessageCount;
              final isEnabled = userMessageCount >= 4;
              
              return Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: isEnabled
                        ? () => _handleSaveAsDiary(context, isLightTheme, isDarkTheme)
                        : () => _showInsufficientMessagesDialog(context, isLightTheme, isDarkTheme),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEnabled
                            ? const Color(0xFF6B4C93)
                            : Colors.grey.shade400,
                        boxShadow: isEnabled
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6B4C93).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.book_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Input row with text field and send button
          Row(
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
                              ? Colors.white.withValues(alpha: 0.4)
                              : const Color(0xFF6B4C93).withValues(alpha: 0.5)),
                      width: _isInputFocused ? 2.5 : 1.5,
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
        ],
      ),
    );
  }


  Future<void> _handleSaveAsDiary(BuildContext context, bool isLightTheme, bool isDarkTheme) async {
    final provider = Provider.of<AIChatProvider>(context, listen: false);
    
    // Properly detect dark theme using ThemeUtils (do this first)
    final correctIsDarkTheme = await ThemeUtils.isDarkTheme();
    final correctIsLightTheme = !correctIsDarkTheme;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: correctIsDarkTheme ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Creating your journal entry...',
                style: GoogleFonts.poppins(
                  color: correctIsDarkTheme ? Colors.white : const Color(0xFF5E3A9E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    try {
      // Get user messages only
      final userMessages = provider.messages
          .where((m) => m.sender == 'user')
          .map((m) => m.text)
          .toList();
      
      if (userMessages.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        if (!mounted) return;
        _showErrorDialog(context, 'No messages to summarize', correctIsLightTheme, correctIsDarkTheme);
        return;
      }
      
      // Call backend summarize API
      final summary = await AIMLApiService().summarizeMessages(userMessages);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      if (!mounted) return;
      
      // Get theme bottom color to match home screen styling
      final themeBottomColor = await ThemeStorageService.getBottomColor();
      
      if (!mounted) return;
      
      // Navigate to new entry screen with pre-filled content
      // Set navigateToHomeOnSave to true so it goes to home after saving
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewEntryScreen(
            themeBottomColor: themeBottomColor,
            isLightTheme: correctIsLightTheme,
            initialContent: summary,
            navigateToHomeOnSave: true,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (!mounted) return;
      _showErrorDialog(
        context,
        'Failed to create journal entry. Please try again.',
        correctIsLightTheme,
        correctIsDarkTheme,
      );
    }
  }

  void _showInsufficientMessagesDialog(BuildContext context, bool isLightTheme, bool isDarkTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Write a little more',
          style: GoogleFonts.poppins(
            color: isDarkTheme ? Colors.white : const Color(0xFF5E3A9E),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Write a little more to create a meaningful entry.',
          style: GoogleFonts.poppins(
            color: isDarkTheme ? Colors.white70 : const Color(0xFF5E3A9E).withValues(alpha: 0.8),
          ),
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

  void _showErrorDialog(BuildContext context, String message, bool isLightTheme, bool isDarkTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Error',
          style: GoogleFonts.poppins(
            color: isDarkTheme ? Colors.white : const Color(0xFF5E3A9E),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: isDarkTheme ? Colors.white70 : const Color(0xFF5E3A9E).withValues(alpha: 0.8),
          ),
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
}
