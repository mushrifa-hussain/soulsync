import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import 'notification_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final NotificationService _notificationService = NotificationService();
  static const String _storageKey = 'reminders_list';
  int _nextNotificationId = 1000; // Start from 1000 to avoid conflicts

  // Generate unique ID for reminder
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Generate unique notification ID
  int _generateNotificationId() {
    return _nextNotificationId++;
  }

  // Save reminders to SharedPreferences
  Future<bool> _saveReminders(List<Reminder> reminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = reminders.map((r) => r.toJson()).toList();
      final jsonString = jsonEncode(remindersJson);
      await prefs.setString(_storageKey, jsonString);
      return true;
    } catch (e) {
      debugPrint('Error saving reminders: $e');
      return false;
    }
  }

  // Load reminders from SharedPreferences
  Future<List<Reminder>> _loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> remindersJson = jsonDecode(jsonString);
      final reminders = remindersJson
          .map((json) => Reminder.fromJson(json as Map<String, dynamic>))
          .toList();

      // Update next notification ID based on existing reminders
      if (reminders.isNotEmpty) {
        final maxId = reminders.map((r) => r.notificationId).reduce((a, b) => a > b ? a : b);
        _nextNotificationId = maxId + 1;
      }

      return reminders;
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      return [];
    }
  }

  // Get all reminders
  Future<List<Reminder>> getReminders() async {
    return await _loadReminders();
  }

  // Add a new reminder
  Future<bool> addReminder({
    required String title,
    required DateTime dateTime,
  }) async {
    try {
      final reminders = await _loadReminders();
      final notificationId = _generateNotificationId();
      
      final reminder = Reminder(
        id: _generateId(),
        title: title,
        dateTime: dateTime,
        notificationId: notificationId,
      );

      reminders.add(reminder);
      final saved = await _saveReminders(reminders);

      if (saved) {
        // Always try to schedule notification if reminder is enabled and in the future
        final now = DateTime.now();
        final isFuture = dateTime.isAfter(now);
        
        debugPrint('🔥 [REMINDER] Reminder saved. Enabled: ${reminder.enabled}, IsFuture: $isFuture, DateTime: $dateTime, Now: $now');
        
              if (reminder.enabled && isFuture) {
                debugPrint('🔥 [REMINDER] Scheduling notification for reminder: "$title" at $dateTime (ID: $notificationId)');
                
                try {
                  // Format the date/time for a more informative notification
                  final dateFormat = DateFormat('MMM d, yyyy');
                  final timeFormat = DateFormat('h:mm a');
                  final formattedDate = dateFormat.format(dateTime);
                  final formattedTime = timeFormat.format(dateTime);
                  
        final scheduled = await _notificationService.scheduleNotification(
          id: notificationId,
                    title: '📝 $title',
                    body: 'Time to write in your diary!\n$formattedDate at $formattedTime',
          scheduledDate: dateTime,
        );

            if (scheduled) {
              debugPrint('🔥 [REMINDER] ✅ Notification scheduled successfully for ID: $notificationId');
              
              // Verify it was scheduled
              final pending = await _notificationService.getPendingNotifications();
              final found = pending.any((n) => n.id == notificationId);
              
              if (found) {
                final pendingNotification = pending.firstWhere((n) => n.id == notificationId);
                debugPrint('🔥 [REMINDER] ✅ Verification PASSED - Found in pending notifications');
                debugPrint('🔥 [REMINDER] Pending notification details: ID=${pendingNotification.id}, Title=${pendingNotification.title}, Body=${pendingNotification.body}');
              } else {
                debugPrint('🔥 [REMINDER] ⚠️ Verification FAILED - Notification ID=$notificationId NOT found in pending list');
                debugPrint('🔥 [REMINDER] Total pending notifications: ${pending.length}');
                for (final p in pending) {
                  debugPrint('🔥 [REMINDER]   - Pending ID: ${p.id}, Title: ${p.title}');
                }
              }
            } else {
              debugPrint('🔥 [REMINDER ERROR] ❌ Reminder saved but notification scheduling returned false');
            }
          } catch (e, stackTrace) {
            debugPrint('🔥 [REMINDER ERROR] ❌ Exception while scheduling notification: $e');
            debugPrint('🔥 [REMINDER ERROR] Stack trace: $stackTrace');
        }
        } else {
          if (!reminder.enabled) {
            debugPrint('🔥 [REMINDER] ⚠️ Reminder not scheduled - reminder is disabled');
          }
          if (!isFuture) {
            debugPrint('🔥 [REMINDER] ⚠️ Reminder not scheduled - date/time is in the past');
            debugPrint('🔥 [REMINDER] DateTime: $dateTime, Now: $now, Difference: ${now.difference(dateTime)}');
          }
        }
      } else {
        debugPrint('🔥 [REMINDER ERROR] ❌ Failed to save reminder to storage');
      }

      return saved;
    } catch (e) {
      debugPrint('Error adding reminder: $e');
      return false;
    }
  }

  // Toggle reminder enabled/disabled
  Future<bool> toggleReminder(String id) async {
    try {
      final reminders = await _loadReminders();
      final reminderIndex = reminders.indexWhere((r) => r.id == id);

      if (reminderIndex == -1) {
        return false;
      }

      final reminder = reminders[reminderIndex];
      final now = DateTime.now();
      final newEnabled = !reminder.enabled;
      
      // Update reminder
      reminders[reminderIndex] = reminder.copyWith(enabled: newEnabled);
      
      if (newEnabled && reminder.dateTime.isAfter(now)) {
        // Re-enable: Schedule notification if it's in the future
        final dateFormat = DateFormat('MMM d, yyyy');
        final timeFormat = DateFormat('h:mm a');
        final formattedDate = dateFormat.format(reminder.dateTime);
        final formattedTime = timeFormat.format(reminder.dateTime);
        
        await _notificationService.scheduleNotification(
          id: reminder.notificationId,
          title: '📝 ${reminder.title}',
          body: 'Time to write in your diary!\n$formattedDate at $formattedTime',
          scheduledDate: reminder.dateTime,
        );
      } else if (!newEnabled) {
        // Disable: Cancel notification
        await _notificationService.cancelNotification(reminder.notificationId);
      }
      
      return await _saveReminders(reminders);
    } catch (e) {
      debugPrint('Error toggling reminder: $e');
      return false;
    }
  }

  // Delete a reminder
  Future<bool> deleteReminder(String id) async {
    try {
      final reminders = await _loadReminders();
      final reminderIndex = reminders.indexWhere((r) => r.id == id);

      if (reminderIndex == -1) {
        return false;
      }

      final reminder = reminders[reminderIndex];
      
      // Cancel the notification
      await _notificationService.cancelNotification(reminder.notificationId);

      // Remove from list
      reminders.removeAt(reminderIndex);
      return await _saveReminders(reminders);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      return false;
    }
  }

  // Re-schedule all future reminders (call on app startup)
  Future<void> rescheduleAllReminders() async {
    try {
      final reminders = await _loadReminders();
      final now = DateTime.now();

      for (final reminder in reminders) {
        // Only re-schedule future reminders that are enabled
        if (reminder.enabled && reminder.dateTime.isAfter(now)) {
          final dateFormat = DateFormat('MMM d, yyyy');
          final timeFormat = DateFormat('h:mm a');
          final formattedDate = dateFormat.format(reminder.dateTime);
          final formattedTime = timeFormat.format(reminder.dateTime);
          
          await _notificationService.scheduleNotification(
            id: reminder.notificationId,
            title: '📝 ${reminder.title}',
            body: 'Time to write in your diary!\n$formattedDate at $formattedTime',
            scheduledDate: reminder.dateTime,
          );
        }
      }

      debugPrint('Re-scheduled ${reminders.where((r) => r.dateTime.isAfter(now)).length} reminders');
    } catch (e) {
      debugPrint('Error re-scheduling reminders: $e');
    }
  }
}
