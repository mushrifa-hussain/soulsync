class Reminder {
  final String id;
  final String title;
  final DateTime dateTime;
  final int notificationId; // Unique ID for notification cancellation
  final bool enabled; // Whether the reminder is enabled

  Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.notificationId,
    this.enabled = true, // Default to enabled
  });

  // Convert to JSON for storageb
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'notificationId': notificationId,
      'enabled': enabled,
    };
  }

  // Create from JSON
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      notificationId: json['notificationId'] as int,
      enabled:
          json['enabled'] as bool? ??
          true, // Default to true for backward compatibility
    );
  }

  // Copy with method for updates
  Reminder copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    int? notificationId,
    bool? enabled,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      notificationId: notificationId ?? this.notificationId,
      enabled: enabled ?? this.enabled,
    );
  }
}
