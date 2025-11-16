import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import 'add_reminder_page.dart';
import '../utils/theme_utils.dart';
import '../widgets/theme_background_wrapper.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final ReminderService _reminderService = ReminderService();
  List<Reminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    final reminders = await _reminderService.getReminders();
    
    // Sort by date/time (earliest first)
    reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (mounted) {
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleReminder(Reminder reminder) async {
    final toggled = await _reminderService.toggleReminder(reminder.id);
    if (toggled && mounted) {
      _loadReminders();
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final isDarkTheme = await ThemeUtils.isDarkTheme();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLightTheme
            ? Colors.white
            : const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Reminder?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkTheme
                ? const Color(0xFF5E3A9E) // Purple on white dialog
                : (isLightTheme ? const Color(0xFF5E3A9E) : Colors.white),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${reminder.title}"?',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            color: isDarkTheme
                ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on white dialog
                : (isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDarkTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on white dialog
                    : (isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deleted = await _reminderService.deleteReminder(reminder.id);
      if (deleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder deleted',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadReminders();
      }
    }
  }

  Future<void> _navigateToAddReminder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddReminderPage(),
      ),
    );

    if (result == true) {
      _loadReminders();
    }
  }

  bool get isLightTheme => Theme.of(context).brightness == Brightness.light;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildContent(context, isLightTheme, isDarkTheme, colorScheme);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isLightTheme, bool isDarkTheme, ColorScheme colorScheme) {
    return Scaffold(
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDarkTheme
                            ? Colors.white
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white),
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Reminders',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDarkTheme
                              ? Colors.white
                              : (isLightTheme
                                  ? const Color(0xFF5E3A9E)
                                  : Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkTheme
                                ? Colors.white
                                : (isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white),
                          ),
                        ),
                      )
                    : _reminders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF5E3A9E).withValues(alpha: 0.12),
                                        const Color(0xFF9B7EDE).withValues(alpha: 0.15),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    size: 40,
                                    color: isDarkTheme
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : (isLightTheme
                                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                                            : Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No reminders yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkTheme
                                        ? Colors.white
                                        : (isLightTheme
                                            ? const Color(0xFF5E3A9E)
                                            : Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap the + button to add a reminder',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: isDarkTheme
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : (isLightTheme
                                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                                            : Colors.white.withValues(alpha: 0.6)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                            itemCount: _reminders.length,
                            itemBuilder: (context, index) {
                              final reminder = _reminders[index];
                              final dateFormat = DateFormat('MMM d, yyyy');
                              final timeFormat = DateFormat('h:mm a');
                              final isPast = reminder.dateTime.isBefore(DateTime.now());

                              return _buildReminderCard(
                                reminder,
                                dateFormat,
                                timeFormat,
                                isPast,
                                isLightTheme,
                                isDarkTheme,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddReminder,
        backgroundColor: const Color(0xFF5E3A9E),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
        elevation: 6,
        mini: false,
      ),
    );
  }

  Widget _buildReminderCard(
    Reminder reminder,
    DateFormat dateFormat,
    DateFormat timeFormat,
    bool isPast,
    bool isLightTheme,
    bool isDarkTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLightTheme
              ? const Color(0xFF5E3A9E).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.04 : 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Toggle Switch
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: reminder.enabled,
              onChanged: (value) => _toggleReminder(reminder),
              activeColor: const Color(0xFF5E3A9E),
              inactiveThumbColor: Colors.grey.shade300,
              inactiveTrackColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  reminder.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: !reminder.enabled
                        ? Colors.grey.shade400
                        : (isPast
                            ? Colors.grey.shade600
                            : (isDarkTheme
                                ? const Color(0xFF5E3A9E) // Purple on white card
                                : (isLightTheme
                                    ? const Color(0xFF5E3A9E)
                                    : Colors.white))),
                    decoration: !reminder.enabled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Time
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: !reminder.enabled
                          ? Colors.grey.shade400
                          : (isDarkTheme
                              ? const Color(0xFF5E3A9E).withValues(alpha: 0.8) // Purple on white card
                              : (isLightTheme
                                  ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.7))),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${dateFormat.format(reminder.dateTime)} at ${timeFormat.format(reminder.dateTime)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: !reminder.enabled
                              ? Colors.grey.shade400
                              : (isPast
                                  ? Colors.grey.shade500
                                  : (isDarkTheme
                                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.85) // Purple on white card
                                      : (isLightTheme
                                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                                          : Colors.white.withValues(alpha: 0.7)))),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Delete Button
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.withValues(alpha: 0.7),
              size: 20,
            ),
            onPressed: () => _deleteReminder(reminder),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
