import 'package:flutter/foundation.dart';
import 'package:soulsync_dairyapp/services/ai_chat_storage_service.dart';
import 'package:soulsync_dairyapp/services/firebase_function_service.dart';

/// Message model for chat
class ChatMessage {
  final String id;
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;
  final List<String>? imagePaths; // Paths to images attached to this message

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.imagePaths,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'imagePaths': imagePaths,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sender: json['sender'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imagePaths: json['imagePaths'] != null 
          ? List<String>.from(json['imagePaths'] as List)
          : null,
    );
  }
}

/// Provider for AI chat state management
class AIChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;

  /// Get count of user messages
  int get userMessageCount => _messages.where((m) => m.sender == 'user').length;

  /// Load chat history from local storage
  Future<void> loadChatHistory() async {
    try {
      _messages = await AIChatStorageService.loadChatHistory();
      notifyListeners();
    } catch (e) {
      debugPrint('🔥 [AI CHAT] Error loading chat history: $e');
      _messages = [];
    }
  }

  /// Send a user message and get AI response
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'user',
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    await _saveChatHistory();
    notifyListeners();

    // Get AI response
    await _getAIResponse();
  }

  /// Get AI response from Firebase Function
  Future<void> _getAIResponse() async {
    _isTyping = true;
    notifyListeners();

    try {
      // Build conversation history for context
      final conversationHistory = _messages.map((m) => <String, String>{
        'role': m.sender == 'user' ? 'user' : 'assistant',
        'text': m.text,
      }).toList();

      // Call Firebase Function
      final response = await FirebaseFunctionService.geminiChat(
        conversationHistory,
      );

      // Add AI message
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'ai',
        text: response,
        timestamp: DateTime.now(),
      );

      _messages.add(aiMessage);
      await _saveChatHistory();
    } catch (e) {
      debugPrint('🔥 [AI CHAT ERROR] Error getting AI response: $e');
      debugPrint('🔥 [AI CHAT ERROR] Error type: ${e.runtimeType}');
      debugPrint('🔥 [AI CHAT ERROR] Error details: ${e.toString()}');
      
      // Check if it's a Firebase Functions error
      String errorText = 'I apologize, but I\'m having trouble connecting right now. Please try again in a moment. 💜';
      
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('functions/not-found') || 
          errorString.contains('not_found') ||
          errorString.contains('function does not exist')) {
        errorText = 'The AI service is not available. Please make sure Firebase Functions are deployed. 💜';
      } else if (errorString.contains('failed-precondition') || 
                 errorString.contains('api key') ||
                 errorString.contains('gemini api key') ||
                 errorString.contains('invalid gemini api key') ||
                 errorString.contains('api key is not configured')) {
        errorText = 'The AI service needs configuration. Please set the Gemini API key in Firebase Functions config. 💜\n\nSee SETUP_INSTRUCTIONS.md for steps.';
      } else if (errorString.contains('permission') || 
                 errorString.contains('permission_denied') ||
                 errorString.contains('unauthenticated')) {
        errorText = 'I don\'t have permission to access the AI service. Please check your authentication. 💜';
      } else if (errorString.contains('network') || 
                 errorString.contains('timeout') ||
                 errorString.contains('unavailable')) {
        errorText = 'Network connection issue. Please check your internet and try again. 💜';
      }
      
      // Add error message
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'ai',
        text: errorText,
        timestamp: DateTime.now(),
      );

      _messages.add(errorMessage);
      await _saveChatHistory();
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Generate summary and save as diary entry
  Future<String?> generateSummary() async {
    if (_messages.isEmpty) return null;

    _isLoading = true;
    notifyListeners();

    try {
      // Build full conversation text with image references
      final conversationText = _messages.map((m) {
        String messageText = '${m.sender == 'user' ? 'You' : 'SoulSync AI'}: ${m.text}';
        if (m.imagePaths != null && m.imagePaths!.isNotEmpty) {
          messageText += '\n[Attached ${m.imagePaths!.length} image(s)]';
        }
        return messageText;
      }).join('\n\n');

      // Collect all image paths from user messages
      final imagePaths = <String>[];
      for (final message in _messages) {
        if (message.sender == 'user' && message.imagePaths != null) {
          imagePaths.addAll(message.imagePaths!);
        }
      }

      // Call Firebase Function for summary (with images if any)
      final summary = await FirebaseFunctionService.geminiSummarize(
        conversationText,
        imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
      );

      _isLoading = false;
      notifyListeners();
      return summary;
    } catch (e) {
      debugPrint('🔥 [AI CHAT ERROR] Error generating summary: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Clear chat history
  Future<void> clearChat() async {
    _messages.clear();
    await AIChatStorageService.clearChatHistory();
    notifyListeners();
  }

  /// Save chat history to local storage
  Future<void> _saveChatHistory() async {
    try {
      await AIChatStorageService.saveChatHistory(_messages);
    } catch (e) {
      debugPrint('🔥 [AI CHAT ERROR] Error saving chat history: $e');
    }
  }
}

