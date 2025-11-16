import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soulsync_dairyapp/providers/ai_chat_provider.dart';

/// Service for storing and retrieving AI chat history locally
class AIChatStorageService {
  static const String _chatHistoryKey = 'ai_chat_history';

  /// Save chat history to local storage
  static Future<void> saveChatHistory(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = messages.map((m) => m.toJson()).toList();
      final jsonString = jsonEncode(messagesJson);
      await prefs.setString(_chatHistoryKey, jsonString);
    } catch (e) {
      throw Exception('Failed to save chat history: $e');
    }
  }

  /// Load chat history from local storage
  static Future<List<ChatMessage>> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_chatHistoryKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> messagesJson = jsonDecode(jsonString);
      return messagesJson.map((json) => ChatMessage.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load chat history: $e');
    }
  }

  /// Clear chat history from local storage
  static Future<void> clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
    } catch (e) {
      throw Exception('Failed to clear chat history: $e');
    }
  }
}

