import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/reminder_service.dart';
import '../utils/theme_utils.dart';
import '../widgets/theme_background_wrapper.dart';

class AddReminderPage extends StatefulWidget {
  const AddReminderPage({super.key});

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  final ReminderService _reminderService = ReminderService();
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF5E3A9E),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF5E3A9E),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF5E3A9E),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF5E3A9E),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a reminder title',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.withValues(alpha: 0.85),
        ),
      );
      return;
    }

    // Combine date and time (this creates a DateTime in local timezone)
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    debugPrint('🔥 [ADD REMINDER] Creating reminder:');
    debugPrint('🔥 [ADD REMINDER]   Title: ${_titleController.text}');
    debugPrint('🔥 [ADD REMINDER]   Selected date: $_selectedDate');
    debugPrint('🔥 [ADD REMINDER]   Selected time: $_selectedTime');
    debugPrint('🔥 [ADD REMINDER]   Combined DateTime: $dateTime');
    debugPrint('🔥 [ADD REMINDER]   DateTime timezone offset: ${dateTime.timeZoneOffset}');
    debugPrint('🔥 [ADD REMINDER]   Current time: ${DateTime.now()}');
    debugPrint('🔥 [ADD REMINDER]   Is future: ${dateTime.isAfter(DateTime.now())}');

    // Check if the time is in the past
    if (dateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a future date and time',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.withValues(alpha: 0.85),
        ),
      );
      return;
    }

    final saved = await _reminderService.addReminder(
      title: _titleController.text.trim(),
      dateTime: dateTime,
    );

    if (mounted) {
      if (saved) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder added successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF5E3A9E).withValues(alpha: 0.85),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save reminder',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.withValues(alpha: 0.85),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final dateFormat = DateFormat('MMM d, yyyy');

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
                        color: isLightTheme
                            ? const Color(0xFF5E3A9E)
                            : Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Add Reminder',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isLightTheme
                              ? const Color(0xFF5E3A9E)
                              : Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _saveReminder,
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF5E3A9E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Title field
                      _buildTextField(
                        isLightTheme,
                        'Reminder Title',
                        _titleController,
                        Icons.edit_outlined,
                      ),
                      const SizedBox(height: 18),
                      // Date picker
                      _buildDateTimePicker(
                        isLightTheme,
                        'Date',
                        dateFormat.format(_selectedDate),
                        Icons.calendar_today_outlined,
                        _selectDate,
                      ),
                      const SizedBox(height: 16),
                      // Time picker
                      _buildDateTimePicker(
                        isLightTheme,
                        'Time',
                        _selectedTime.format(context),
                        Icons.access_time_rounded,
                        _selectTime,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    bool isLightTheme,
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isLightTheme
                ? const Color(0xFF5E3A9E)
                : Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Container(
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
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Enter reminder title',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                color: isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(
                icon,
                size: 20,
                color: isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker(
    bool isLightTheme,
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isLightTheme
                ? const Color(0xFF5E3A9E)
                : Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE8D5FF).withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    icon,
                    color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: isLightTheme ? const Color(0xFF5E3A9E) : Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
