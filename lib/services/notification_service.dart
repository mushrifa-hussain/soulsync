import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Initialize the notification plugin
  Future<bool> initialize() async {
    if (_initialized) return true;

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'reminders_channel',
      'Reminders',
      description: 'Notifications for diary reminders',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final bool? initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (initialized == true) {
      _initialized = true;
      
      // Verify timezone is initialized
      try {
        final local = tz.local;
        final now = DateTime.now();
        final nowTZ = tz.TZDateTime.now(local);
        debugPrint('🔥 [NOTIFICATION] Timezone verification:');
        debugPrint('🔥 [NOTIFICATION]   Local timezone: ${local.name}');
        debugPrint('🔥 [NOTIFICATION]   System DateTime: $now');
        debugPrint('🔥 [NOTIFICATION]   System timezone offset: ${now.timeZoneOffset}');
        debugPrint('🔥 [NOTIFICATION]   TZDateTime now: $nowTZ');
      } catch (e) {
        debugPrint('🔥 [NOTIFICATION ERROR] Timezone verification failed: $e');
      }
      
      // Create notification channel for Android
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        // Create the channel
        await androidImplementation.createNotificationChannel(androidChannel);
        debugPrint('🔥 [NOTIFICATION] Notification channel created: reminders_channel');
        
        // Request permissions for Android 13+ (POST_NOTIFICATIONS)
        final permissionGranted = await androidImplementation.requestNotificationsPermission();
        debugPrint('🔥 [NOTIFICATION] POST_NOTIFICATIONS permission granted: $permissionGranted');
        
        if (permissionGranted != true) {
          debugPrint('🔥 [NOTIFICATION WARNING] POST_NOTIFICATIONS permission NOT granted - notifications may not work!');
        }
        
        // Request exact alarm permission for Android 12+ (SCHEDULE_EXACT_ALARM)
        final exactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
        debugPrint('🔥 [NOTIFICATION] SCHEDULE_EXACT_ALARM permission granted: $exactAlarmPermission');
        
        if (exactAlarmPermission != true) {
          debugPrint('🔥 [NOTIFICATION WARNING] SCHEDULE_EXACT_ALARM permission NOT granted - using inexact alarms');
        }
        
        // Check if notifications are enabled
        final notificationsEnabled = await androidImplementation.areNotificationsEnabled();
        debugPrint('🔥 [NOTIFICATION] Notifications enabled: $notificationsEnabled');
      }
      
      // Request iOS permissions
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final iosPermission = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🔥 [NOTIFICATION] iOS permissions granted: $iosPermission');
      }
      
      debugPrint('🔥 [NOTIFICATION] Notification service initialized successfully');
    } else {
      debugPrint('🔥 [NOTIFICATION ERROR] Failed to initialize notification service');
    }

    return initialized ?? false;
  }

  // Handle notification tap/action
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification action: ${response.actionId}, ID: ${response.id}');
    
    // Handle different actions
    if (response.actionId == 'open_app') {
      // Open App action - navigation will be handled by the app
      debugPrint('Open App action tapped');
      _navigateToApp();
    } else if (response.actionId == 'stop') {
      // Stop action - notification is already dismissed
      debugPrint('Stop action tapped - notification dismissed');
    } else {
      // Default tap (notification body) - open app
      debugPrint('Notification body tapped - opening app');
      _navigateToApp();
    }
  }

  // Navigate to app when notification is tapped
  void _navigateToApp() {
    // This will be handled by the app's navigation system
    // The notification tap will bring the app to foreground
    debugPrint('Navigating to app from notification');
  }

  // Schedule a notification
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('Failed to initialize notifications');
        return false;
      }
    }

    // Don't schedule if the time has already passed
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint('Cannot schedule notification for past time');
      return false;
    }

    final androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Notifications for diary reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF5E3A9E),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'SoulSync Reminder',
      ),
      category: AndroidNotificationCategory.reminder,
      channelShowBadge: true,
      autoCancel: true,
      ongoing: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'open_app',
          'Open App',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'stop',
          'Dismiss',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      threadIdentifier: 'soulsync-reminders',
      categoryIdentifier: 'REMINDER',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // Check if notification service is initialized
      if (!_initialized) {
        debugPrint('🔥 [NOTIFICATION] Service not initialized, initializing now...');
        final initResult = await initialize();
        if (!initResult) {
          debugPrint('🔥 [NOTIFICATION ERROR] ❌ Cannot schedule - service initialization failed');
          return false;
        }
        debugPrint('🔥 [NOTIFICATION] ✅ Service initialized successfully');
      }
      
      final scheduledTZ = _convertToTZDateTime(scheduledDate);
      final now = DateTime.now();
      final timeUntilNotification = scheduledDate.difference(now);
      
      debugPrint('🔥 [NOTIFICATION] ========== SCHEDULING NOTIFICATION ==========');
      debugPrint('🔥 [NOTIFICATION] ID: $id');
      debugPrint('🔥 [NOTIFICATION] Title: $title');
      debugPrint('🔥 [NOTIFICATION] Body: $body');
      debugPrint('🔥 [NOTIFICATION] Scheduled DateTime (local): $scheduledDate');
      debugPrint('🔥 [NOTIFICATION] TZDateTime: $scheduledTZ');
      debugPrint('🔥 [NOTIFICATION] Current DateTime: $now');
      debugPrint('🔥 [NOTIFICATION] Time until notification: $timeUntilNotification');
      debugPrint('🔥 [NOTIFICATION] ============================================');
      
      // Try exact alarms first, fall back to inexact if not permitted
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledTZ,
          notificationDetails,
          androidScheduleMode: scheduleMode,
          // Don't use matchDateTimeComponents for one-time notifications
          // matchDateTimeComponents is for recurring notifications
        );
        
        // Verify it was scheduled
        final pending = await _notifications.pendingNotificationRequests();
        final found = pending.any((n) => n.id == id);
        
        if (found) {
          final pendingNotif = pending.firstWhere((n) => n.id == id);
          debugPrint('🔥 [NOTIFICATION] ✅ Scheduled (exact): ID=$id');
          debugPrint('🔥 [NOTIFICATION] Pending notification details:');
          debugPrint('🔥 [NOTIFICATION]   - ID: ${pendingNotif.id}');
          debugPrint('🔥 [NOTIFICATION]   - Title: ${pendingNotif.title}');
          debugPrint('🔥 [NOTIFICATION]   - Body: ${pendingNotif.body}');
          debugPrint('🔥 [NOTIFICATION] Total pending: ${pending.length}');
        return true;
        } else {
          debugPrint('🔥 [NOTIFICATION] ⚠️ Scheduled but NOT found in pending list (exact)');
          debugPrint('🔥 [NOTIFICATION] Total pending: ${pending.length}');
          // List all pending for debugging
          for (final p in pending) {
            debugPrint('🔥 [NOTIFICATION]   - Pending ID: ${p.id}, Title: ${p.title}');
          }
          return false;
        }
      } catch (e) {
        // If exact alarms fail, try inexact alarms
        if (e.toString().contains('exact_alarms_not_permitted') || 
            e.toString().contains('Exact alarms are not permitted') ||
            e.toString().contains('SCHEDULE_EXACT_ALARM')) {
          debugPrint('🔥 [NOTIFICATION] Exact alarms not permitted, falling back to inexact alarms');
          
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            scheduledTZ,
            notificationDetails,
            androidScheduleMode: scheduleMode,
            // Don't use matchDateTimeComponents for one-time notifications
          );
          
          // Verify it was scheduled
          final pending = await _notifications.pendingNotificationRequests();
          final found = pending.any((n) => n.id == id);
          
          if (found) {
            final pendingNotif = pending.firstWhere((n) => n.id == id);
            debugPrint('🔥 [NOTIFICATION] ✅ Scheduled (inexact): ID=$id');
            debugPrint('🔥 [NOTIFICATION] Pending notification details:');
            debugPrint('🔥 [NOTIFICATION]   - ID: ${pendingNotif.id}');
            debugPrint('🔥 [NOTIFICATION]   - Title: ${pendingNotif.title}');
            debugPrint('🔥 [NOTIFICATION]   - Body: ${pendingNotif.body}');
            debugPrint('🔥 [NOTIFICATION] Total pending: ${pending.length}');
          return true;
          } else {
            debugPrint('🔥 [NOTIFICATION] ⚠️ Scheduled but NOT found in pending list (inexact)');
            debugPrint('🔥 [NOTIFICATION] Total pending: ${pending.length}');
            // List all pending for debugging
            for (final p in pending) {
              debugPrint('🔥 [NOTIFICATION]   - Pending ID: ${p.id}, Title: ${p.title}');
            }
            return false;
          }
        } else {
          // Re-throw if it's a different error
          debugPrint('🔥 [NOTIFICATION ERROR] Error during scheduling: $e');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('🔥 [NOTIFICATION ERROR] Failed to schedule notification: $e');
      debugPrint('🔥 [NOTIFICATION ERROR] Stack trace: $stackTrace');
      return false;
    }
  }

  // Convert DateTime to TZDateTime (required by flutter_local_notifications)
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    try {
      // Get the device's local timezone
      final local = tz.local;
      
      // Use TZDateTime.from() which properly converts a DateTime to TZDateTime
      // This preserves the exact wall-clock time the user selected
      final tzDateTime = tz.TZDateTime.from(dateTime, local);
      
      // Verify the conversion is correct
      final nowTZ = tz.TZDateTime.now(local);
      final timeDiff = tzDateTime.difference(nowTZ);
      
      debugPrint('🔥 [NOTIFICATION] Timezone conversion:');
      debugPrint('🔥 [NOTIFICATION]   Input DateTime: $dateTime');
      debugPrint('🔥 [NOTIFICATION]   Input timezone offset: ${dateTime.timeZoneOffset}');
      debugPrint('🔥 [NOTIFICATION]   Output TZDateTime: $tzDateTime');
      debugPrint('🔥 [NOTIFICATION]   Timezone: ${local.name}');
      debugPrint('🔥 [NOTIFICATION]   Current time (TZ): $nowTZ');
      debugPrint('🔥 [NOTIFICATION]   Time until notification: $timeDiff');
      
      // Double-check: ensure the scheduled time matches what user selected
      if (dateTime.hour != tzDateTime.hour || dateTime.minute != tzDateTime.minute) {
        debugPrint('🔥 [NOTIFICATION WARNING] ⚠️ Time mismatch detected!');
        debugPrint('🔥 [NOTIFICATION WARNING]   Selected: ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}');
        debugPrint('🔥 [NOTIFICATION WARNING]   Scheduled: ${tzDateTime.hour}:${tzDateTime.minute.toString().padLeft(2, '0')}');
      }
      
      return tzDateTime;
    } catch (e, stackTrace) {
      debugPrint('🔥 [NOTIFICATION ERROR] Error converting to TZDateTime: $e');
      debugPrint('🔥 [NOTIFICATION ERROR] Stack trace: $stackTrace');
      // Fallback: manually construct TZDateTime
      try {
        final local = tz.local;
        final tzDateTime = tz.TZDateTime(
          local,
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour,
          dateTime.minute,
          dateTime.second,
        );
        debugPrint('🔥 [NOTIFICATION] Using fallback conversion: $tzDateTime');
        return tzDateTime;
      } catch (e2) {
        debugPrint('🔥 [NOTIFICATION ERROR] Fallback conversion also failed: $e2');
        // Last resort: use current time + offset
    final local = tz.local;
        final now = tz.TZDateTime.now(local);
        final timeUntil = dateTime.difference(DateTime.now());
        final tzDateTime = now.add(timeUntil);
        debugPrint('🔥 [NOTIFICATION] Using last resort conversion: $tzDateTime');
        return tzDateTime;
      }
    }
  }

  // Cancel a notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('Notification cancelled: ID=$id');
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('All notifications cancelled');
  }

  // Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Show notification immediately (for testing or when app is in foreground)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    debugPrint('🔥 [NOTIFICATION] Showing immediate notification: ID=$id, Title=$title');
    if (!_initialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('Failed to initialize notifications');
        return;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Notifications for diary reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF5E3A9E),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'SoulSync Reminder',
      ),
      category: AndroidNotificationCategory.reminder,
      channelShowBadge: true,
      autoCancel: true,
      ongoing: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'open_app',
          'Open App',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'stop',
          'Dismiss',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
      threadIdentifier: 'soulsync-reminders',
      categoryIdentifier: 'REMINDER',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, notificationDetails);
    debugPrint('Notification shown immediately: ID=$id, Title=$title');
  }
}
