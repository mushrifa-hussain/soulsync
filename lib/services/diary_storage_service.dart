import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';

/// Service to store and retrieve diary entries in local storage
class DiaryStorageService {
  static const String _entriesKey = 'diary_entries';

  /// Save a diary entry (creates new or updates existing if ID matches)
  static Future<void> saveEntry(DiaryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getAllEntries();
    
    // Check if entry with same ID exists (for updates)
    final existingIndex = entries.indexWhere((e) => e.id == entry.id);
    if (existingIndex != -1) {
      // Update existing entry
      entries[existingIndex] = entry;
    } else {
      // Add new entry
      entries.add(entry);
    }
    
    // Sort by timestamp in descending order (newest first)
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Convert to JSON and save
    final entriesJson = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_entriesKey, jsonEncode(entriesJson));
  }

  /// Get all diary entries (sorted by timestamp, newest first)
  static Future<List<DiaryEntry>> getAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_entriesKey);
    
    if (entriesJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(entriesJson);
      final entries = decoded.map((json) => DiaryEntry.fromJson(json as Map<String, dynamic>)).toList();
      
      // Sort by timestamp in descending order (newest first)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return entries;
    } catch (e) {
      return [];
    }
  }

  /// Delete a diary entry by ID
  static Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getAllEntries();
    
    entries.removeWhere((entry) => entry.id == id);
    
    final entriesJson = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_entriesKey, jsonEncode(entriesJson));
  }

  /// Clear all entries
  static Future<void> clearAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_entriesKey);
  }
}

