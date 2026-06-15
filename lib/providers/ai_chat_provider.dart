import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:soulsync_dairyapp/services/ai_chat_storage_service.dart';
import 'package:soulsync_dairyapp/services/aiml_api_service.dart';
import 'package:soulsync_dairyapp/services/firebase_function_service.dart';
import 'package:soulsync_dairyapp/services/profile_service.dart';

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

  /// Load chat history from local storage and initialize session with user name
  Future<void> loadChatHistory() async {
    try {
      _messages = await AIChatStorageService.loadChatHistory();
      
      // Initialize session with user name if available
      final userName = await ProfileService.getUsername();
      if (userName != null && userName.isNotEmpty) {
        await AIMLApiService().initializeSession(userName);
        debugPrint('🔥 [AI CHAT] Session initialized with user name: $userName');
      }
      
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

  /// Get AI response from AIML API
  Future<void> _getAIResponse() async {
    _isTyping = true;
    notifyListeners();

    try {
      // Get the last user message
      final lastUserMessage = _messages.lastWhere(
        (m) => m.sender == 'user',
        orElse: () => _messages.last,
      );

      // Call AIML API service - it will handle connection errors with proper messages
      final response = await AIMLApiService().chatWithAI(lastUserMessage.text);

      // Validate response
      if (response.trim().isEmpty) {
        throw Exception('AI returned an empty response');
      }

      // Add AI message
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'ai',
        text: response.trim(),
        timestamp: DateTime.now(),
      );

      _messages.add(aiMessage);
      await _saveChatHistory();
    } catch (e) {
      debugPrint('🔥 [AI CHAT ERROR] Error getting AI response: $e');
      debugPrint('🔥 [AI CHAT ERROR] Error type: ${e.runtimeType}');
      debugPrint('🔥 [AI CHAT ERROR] Error details: ${e.toString()}');
      
      final errorString = e.toString().toLowerCase();
      
      // Determine error message based on error type
      String errorText;
      if (errorString.contains('backend server is not running') ||
          errorString.contains('connection') || 
          errorString.contains('network') || 
          errorString.contains('unavailable') ||
          errorString.contains('refused') ||
                 errorString.contains('timeout') ||
          errorString.contains('timed out') ||
          errorString.contains('socketexception')) {
        errorText = 'I\'m having trouble connecting to the AI server. 💜\n\nPlease make sure:\n1. Backend is running: python run_api.py in ai_engine folder\n2. Server is accessible on port 8000\n3. For Android: Run "adb reverse tcp:8000 tcp:8000"';
      } else if (errorString.contains('api error') || errorString.contains('statuscode')) {
        errorText = 'The AI server returned an error. 💜 Please check the backend logs and try again.';
      } else if (errorString.contains('empty response')) {
        errorText = 'The AI server returned an empty response. 💜 Please try again.';
      } else {
        errorText = 'I encountered an issue: ${e.toString().split(':').last.trim()}. 💜 Please try again.';
      }
      
      // Show error message
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
    if (_messages.isEmpty) {
      debugPrint('🔥 [AI CHAT ERROR] No messages to summarize');
      return null;
    }

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

      if (conversationText.trim().isEmpty) {
        debugPrint('🔥 [AI CHAT ERROR] Conversation text is empty');
        _isLoading = false;
        notifyListeners();
        return null;
      }

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
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Summary generation timed out after 60 seconds');
        },
      );

      if (summary.trim().isEmpty) {
        debugPrint('🔥 [AI CHAT ERROR] Summary is empty');
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _isLoading = false;
      notifyListeners();
      return summary.trim();
    } catch (e) {
      debugPrint('🔥 [AI CHAT ERROR] Error generating summary: $e');
      debugPrint('🔥 [AI CHAT ERROR] Error type: ${e.runtimeType}');
      debugPrint('🔥 [AI CHAT ERROR] Error details: ${e.toString()}');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Clear chat history and reinitialize session with user name
  Future<void> clearChat() async {
    _messages.clear();
    await AIChatStorageService.clearChatHistory();
    AIMLApiService().resetSession(); // Reset API session
    
    // Reinitialize session with user name
    final userName = await ProfileService.getUsername();
    if (userName != null && userName.isNotEmpty) {
      await AIMLApiService().initializeSession(userName);
      debugPrint('🔥 [AI CHAT] Session reinitialized with user name: $userName');
    }
    
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

