import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for calling the FastAPI AIML backend
/// SIMPLE VERSION - Just works!
class AIMLApiService {
  static final AIMLApiService _instance = AIMLApiService._internal();
  factory AIMLApiService() => _instance;
  AIMLApiService._internal();

  // ============================================
  // SIMPLE CONFIGURATION - Set this once!
  // ============================================
  
  // Option 1: Use ngrok (RECOMMENDED - works everywhere)
  // Run: .\start_with_ngrok.ps1
  // Then paste the URL here (e.g., 'https://abc123.ngrok.io')
  static const String? _ngrokUrl = null; // Set this if using ngrok
  
  // Option 2: Use local IP (for same Wi-Fi network)
  // Run: .\get_local_ip.ps1 to find your IP
  // Then set it here (e.g., 'http://192.168.1.100:8000')
  static const String? _localIp = 'http://10.136.104.122:8000'; // Your laptop IP on hotspot
  
  // Option 3: Use localhost (for emulator with adb reverse)
  // Run: adb reverse tcp:8000 tcp:8000
  // Then use: 'http://localhost:8000' (auto-detected)
  
  // ============================================
  // AUTO-DETECTION (if config not set)
  // ============================================
  
  String get _baseUrl {
    // Priority 1: Use ngrok if set (works everywhere!)
    if (_ngrokUrl != null && _ngrokUrl!.isNotEmpty) {
      final url = _ngrokUrl!.startsWith('http') ? _ngrokUrl! : 'https://$_ngrokUrl';
      debugPrint('🔥 [AIML API] Using ngrok URL: $url');
      return url;
    }
    
    // Priority 2: Use local IP if set
    if (_localIp != null && _localIp!.isNotEmpty) {
      debugPrint('🔥 [AIML API] Using local IP: $_localIp');
      return _localIp!;
    }
    
    // Priority 3: Auto-detect based on platform
    if (kIsWeb) {
      debugPrint('🔥 [AIML API] Using localhost (Web)');
      return 'http://localhost:8000';
    }
    
    if (Platform.isAndroid) {
      // Try emulator first (most common)
      debugPrint('🔥 [AIML API] Using Android emulator URL: http://10.0.2.2:8000');
      return 'http://10.0.2.2:8000'; // Android emulator
    }
    
    // iOS simulator and desktop
    debugPrint('🔥 [AIML API] Using localhost (iOS/Desktop)');
    return 'http://localhost:8000';
  }

  // Session ID for maintaining conversation context
  String? _sessionId;
  String? _userName;

  /// Check if backend is available
  Future<bool> isBackendAvailable() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Initialize session with user name
  Future<void> initializeSession(String? userName) async {
    _userName = userName;
  }

  /// Chat with AI - simple and reliable
  Future<String> chatWithAI(String message) async {
    try {
      final url = Uri.parse('$_baseUrl/chat');
      
      final requestBody = <String, dynamic>{
        'message': message,
      };
      if (_sessionId != null) {
        requestBody['session_id'] = _sessionId;
      }
      if (_sessionId == null && _userName != null) {
        requestBody['user_name'] = _userName;
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _sessionId = data['session_id'] as String?;
        return data['reply'] as String;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      final error = e.toString().toLowerCase();
      if (error.contains('timeout') || error.contains('connection')) {
        throw Exception('Cannot connect to AI server.\n\nMake sure:\n1. Backend is running\n2. Check the URL in aiml_api_service.dart\n3. For help, see SIMPLE_SETUP.md');
      }
      throw Exception('AI error: $e');
    }
  }

  /// Get AI reflection on diary entry text
  Future<String> getReflection(String text) async {
    try {
      final url = Uri.parse('$_baseUrl/reflect');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['reflection'] as String;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Reflection error: $e');
    }
  }

  /// Summarize a list of messages
  Future<String> summarizeMessages(List<String> messages) async {
    try {
      final url = Uri.parse('$_baseUrl/summarize');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'messages': messages}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['summary'] as String;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Summarize error: $e');
    }
  }

  /// Reset session (start new conversation)
  void resetSession() {
    _sessionId = null;
  }

  /// Get current session ID
  String? get sessionId => _sessionId;
}
