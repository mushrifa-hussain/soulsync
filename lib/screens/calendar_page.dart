import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/screens/new_entry_screen.dart';
import 'package:soulsync_dairyapp/screens/month_gallery_page.dart';
import 'package:soulsync_dairyapp/services/settings_service.dart';
import 'package:soulsync_dairyapp/widgets/mood_selection_dialog.dart';
import 'package:soulsync_dairyapp/widgets/soulsync_card.dart';
import 'package:soulsync_dairyapp/widgets/theme_background_wrapper.dart';
import 'package:soulsync_dairyapp/utils/theme_utils.dart';
import 'package:soulsync_dairyapp/services/theme_storage_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  bool _displayMoodOnCalendar = true;
  late AnimationController _monthAnimationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _monthAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _monthAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _loadDisplayMoodSetting();
  }

  @override
  void dispose() {
    _monthAnimationController.dispose();
    super.dispose();
  }

  void _goToPreviousMonth() {
    _monthAnimationController.forward(from: 0.0);
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    _onMonthChanged(previousMonth);
  }

  void _goToNextMonth() {
    _monthAnimationController.forward(from: 0.0);
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    _onMonthChanged(nextMonth);
  }

  Future<void> _loadDisplayMoodSetting() async {
    final displayMood = await SettingsService.getDisplayMoodOnCalendar();
    if (mounted) {
      setState(() {
        _displayMoodOnCalendar = displayMood;
      });
    }
  }

  // Helper method to get mood map and dates with entries from provider
  Map<DateTime, String?> _getMoodMap(DiaryEntriesProvider provider) {
    final moods = <DateTime, String?>{};
    final datesWithEntries = provider.getDatesWithEntries(_currentMonth);
    
    for (final date in datesWithEntries) {
      final mood = provider.getMoodForDate(date);
      if (mood != null && mood.isNotEmpty) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        moods[normalizedDate] = mood;
      }
    }
    
    return moods;
  }

  Set<DateTime> _getDatesWithEntries(DiaryEntriesProvider provider) {
    final datesWithEntries = provider.getDatesWithEntries(_currentMonth);
    return datesWithEntries.map((d) => DateTime(d.year, d.month, d.day)).toSet();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
      // Update selected date to first day of new month if it's outside the new month
      if (_selectedDate.year != newMonth.year || _selectedDate.month != newMonth.month) {
        _selectedDate = DateTime(newMonth.year, newMonth.month, 1);
      }
    });
  }

  void _navigateToAddEntry() async {
    // Check if mood selection should be skipped
    final skipMoodSelection = await SettingsService.getSkipMoodSelection();
    String? selectedMood;
    
    // Get theme bottom color to match home screen background (needed for dialog background)
    final themeBottomColor = await ThemeStorageService.getBottomColor();
    // Properly detect dark theme using ThemeUtils
    final isDarkTheme = await ThemeUtils.isDarkTheme();
    final isLightTheme = !isDarkTheme;
    
    // Show mood selection dialog if not skipped
    if (!skipMoodSelection) {
      if (!mounted) return;
      // Calculate background color to match the entry screen
      Color? dialogBackgroundColor;
      if (themeBottomColor != null) {
        final color = themeBottomColor;
        dialogBackgroundColor = Color.fromRGBO(
          ((color.r * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          ((color.g * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          ((color.b * 255.0) * 0.85 + 255 * 0.15).round().clamp(0, 255),
          1.0,
        );
      } else {
        dialogBackgroundColor = const Color(0xFFE8D5FF);
      }
      selectedMood = await MoodSelectionDialog.show(context, backgroundColor: dialogBackgroundColor);
      // If user cancelled mood selection, don't proceed
      if (selectedMood == null || !mounted) return;
    }
    
    // Navigate to entry screen with selected mood and theme color
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewEntryScreen(
          themeBottomColor: themeBottomColor,
          isLightTheme: isLightTheme,
          existingEntry: null, // New entry
          initialDate: _selectedDate, // Pass selected date
          initialMood: selectedMood, // Pass selected mood
        ),
      ),
    );
    // Provider will automatically update - no need to reload
    // Refresh calendar to show mood changes and reload display setting
    if (mounted) {
      await _loadDisplayMoodSetting();
      setState(() {});
    }
  }

  void _navigateToGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthGalleryPage(month: _currentMonth),
      ),
    );
  }

  Future<void> _showMonthYearPicker() async {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final isDarkTheme = await ThemeUtils.isDarkTheme();
    
    // Generate list of months
    final months = List.generate(12, (index) => index + 1);
    final currentYear = _currentMonth.year;
    final years = List.generate(50, (index) => currentYear - 25 + index);
    
    int selectedMonth = _currentMonth.month;
    int selectedYear = _currentMonth.year;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        backgroundColor: isLightTheme
            ? Colors.white
            : const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Select Month & Year',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkTheme
                ? const Color(0xFF5E3A9E) // Purple on white dialog
                : (isLightTheme ? const Color(0xFF5E3A9E) : Colors.white),
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Row(
            children: [
              // Month dropdown
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDarkTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on white dialog
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selectedMonth,
                      decoration: InputDecoration(
                        filled: false,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      dropdownColor: isLightTheme ? Colors.white : const Color(0xFF2E2E2E),
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: isDarkTheme
                            ? const Color(0xFF5E3A9E) // Purple on white dialog
                            : (isLightTheme ? const Color(0xFF5E3A9E) : Colors.white),
                      ),
                      items: months.map((month) {
                        return DropdownMenuItem<int>(
                          value: month,
                          child: Text(DateFormat('MMMM').format(DateTime(2024, month))),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedMonth = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Year dropdown
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Year',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDarkTheme
                            ? const Color(0xFF5E3A9E).withValues(alpha: 0.9) // Purple on white dialog
                            : (isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selectedYear,
                      decoration: InputDecoration(
                        filled: false,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isLightTheme
                                ? const Color(0xFF5E3A9E)
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      dropdownColor: isLightTheme ? Colors.white : const Color(0xFF2E2E2E),
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: isDarkTheme
                            ? const Color(0xFF5E3A9E) // Purple on white dialog
                            : (isLightTheme ? const Color(0xFF5E3A9E) : Colors.white),
                      ),
                      items: years.map((year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text('$year'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedYear = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {'month': selectedMonth, 'year': selectedYear});
            },
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5E3A9E),
              ),
            ),
          ),
        ],
      ),
      ),
    );

    if (result != null) {
      final newMonth = DateTime(result['year']!, result['month']!, 1);
      _onMonthChanged(newMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    return FutureBuilder<bool>(
      future: ThemeUtils.isDarkTheme(),
      builder: (context, snapshot) {
        final isDarkTheme = snapshot.data ?? false;
        return _buildContent(context, isLightTheme, isDarkTheme);
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isLightTheme, bool isDarkTheme) {
    return Scaffold(
      body: ThemeBackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              // App Bar with Gallery button
              _buildAppBar(isLightTheme, isDarkTheme),
              
              // Month & Year Dropdown Selector (20% smaller)
              _buildMonthYearSelector(isLightTheme, isDarkTheme),
              
              // Calendar Grid (20% smaller)
              Expanded(
                child: Consumer<DiaryEntriesProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: isDarkTheme
                              ? Colors.white
                              : const Color(0xFF5E3A9E),
                        ),
                      );
                    }
                    
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Column(
                        children: [
                          _buildCalendarGrid(isLightTheme, provider, isDarkTheme),
                          const SizedBox(height: 12),
                          _buildSelectedDateInfo(isLightTheme, isDarkTheme),
                          const SizedBox(height: 20),
                          _buildEntriesList(isLightTheme, provider, isDarkTheme),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Add Entry Button
              _buildAddEntryButton(isLightTheme, isDarkTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isLightTheme, bool isDarkTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isDarkTheme
        ? Colors.white
        : (isLightTheme ? colorScheme.primary : colorScheme.onSurface);
    final textColor = isDarkTheme
        ? Colors.white
        : (isLightTheme ? colorScheme.primary : colorScheme.onSurface);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: iconColor,
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text(
            'Calendar',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, size: 22),
            color: iconColor,
            onPressed: _navigateToGallery,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector(bool isLightTheme, bool isDarkTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDarkTheme
        ? Colors.white
        : (isLightTheme ? colorScheme.primary : colorScheme.onSurface);
    final iconColor = isDarkTheme
        ? Colors.white.withValues(alpha: 0.9)
        : colorScheme.onSurfaceVariant;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Center(
        child: GestureDetector(
            onTap: _showMonthYearPicker,
            child: SlideTransition(
              position: _slideAnimation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${DateFormat('MMMM').format(_currentMonth)} ${_currentMonth.year}',
                    style: GoogleFonts.poppins(
                    fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    letterSpacing: 0.3,
                    ),
                  ),
                const SizedBox(width: 8),
                  Icon(
                  Icons.calendar_today,
                  color: iconColor,
                  size: 18,
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }

  Widget _buildCalendarGrid(bool isLightTheme, DiaryEntriesProvider provider, bool isDarkTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Convert to Sun=0, Mon=1, etc.
    final daysInMonth = lastDayOfMonth.day;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null) return;
        
        // Swipe right to go to previous month
        if (velocity > 0) {
          _goToPreviousMonth();
        }
        // Swipe left to go to next month
        else if (velocity < 0) {
          _goToNextMonth();
        }
      },
      child: SoulSyncCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 24,
      border: Border.all(
        color: isLightTheme
            ? const Color(0xFF5E3A9E).withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.4),
        width: 2.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Day headers (Sun-Sat)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.white.withValues(alpha: 0.9)
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          ),
          const SizedBox(height: 2),
          // Calendar days
          ...List.generate(6, (weekIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;
                  
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const Expanded(child: SizedBox());
                  }
                  
                  final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                  // Normalize dates to compare only year, month, day (ignore time)
                  final normalizedDate = DateTime(date.year, date.month, date.day);
                  final normalizedSelected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                  final isSelected = normalizedDate == normalizedSelected;
                  
                  // Check if this date has entries (normalize dates in set too)
                  final datesWithEntries = _getDatesWithEntries(provider);
                  final hasEntry = datesWithEntries.contains(normalizedDate);
                  
                  // Get mood emoji for this date (normalize key dates too)
                  final moodMap = _getMoodMap(provider);
                  final moodEmoji = moodMap[normalizedDate];
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onDateSelected(date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.all(1.5),
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                                  ? const Color(0xFF5E3A9E)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: hasEntry && !isSelected
                              ? Border.all(
                                  color: isLightTheme
                                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                )
                              : isSelected
                                  ? null
                                  : Border.all(
                                      color: Colors.transparent,
                                      width: 1.5,
                                    ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF5E3A9E).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Date number
                            Text(
                              '$dayNumber',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDarkTheme
                                    ? Colors.white
                                    : (isLightTheme
                                        ? const Color(0xFF5E3A9E)
                                            : Colors.white)),
                              ),
                            ),
                            // Mood emoji overlay (inside circle, top-center)
                            if (_displayMoodOnCalendar && moodEmoji != null && moodEmoji.isNotEmpty)
                              Positioned(
                                top: 1,
                                child: Text(
                                  moodEmoji,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
      ),
    );
  }

  Widget _buildSelectedDateInfo(bool isLightTheme, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 15,
        color: isDarkTheme
                ? Colors.white.withValues(alpha: 0.9)
                : (isLightTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 8),
          Text(
        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
        style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            color: isDarkTheme
                  ? Colors.white.withValues(alpha: 0.95)
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildEntriesList(bool isLightTheme, DiaryEntriesProvider provider, bool isDarkTheme) {
    final entriesForSelectedDate = provider.getEntriesForDate(_selectedDate);
    
    if (entriesForSelectedDate.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.edit_note_outlined,
              size: 40,
              color: isDarkTheme
                  ? Colors.white.withValues(alpha: 0.5)
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 12),
            Text(
              'No entries on this day',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkTheme
                    ? Colors.white.withValues(alpha: 0.8)
                    : (isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.7)),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
          'Entries (${entriesForSelectedDate.length})',
          style: GoogleFonts.poppins(
              fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDarkTheme
                ? Colors.white
                : (isLightTheme ? const Color(0xFF5E3A9E) : Colors.white),
          ),
        ),
        ),
        ...entriesForSelectedDate.map((entry) {
          return GestureDetector(
            onTap: () async {
              // Get theme bottom color to match home screen background
              final themeBottomColor = await ThemeStorageService.getBottomColor();
              
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewEntryScreen(
                    themeBottomColor: themeBottomColor,
                    isLightTheme: isLightTheme,
                    existingEntry: entry,
                  ),
                ),
              );
              // Provider will automatically update - no need to reload
            },
            child: _buildEntryCard(entry, isLightTheme, isDarkTheme),
          );
        }),
      ],
    );
  }

  /// Build entry card - clean professional design matching SoulSync aesthetic
  Widget _buildEntryCard(DiaryEntry entry, bool isLightTheme, bool isDarkTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLightTheme
              ? const Color(0xFF5E3A9E).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date and mood row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('d MMM').format(entry.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isDarkTheme
                      ? const Color(0xFF5E3A9E).withValues(alpha: 0.7) // Purple on white card
                      : (isLightTheme
                          ? const Color(0xFF5E3A9E).withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.6)),
                ),
              ),
              Text(
                entry.mood,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            entry.title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkTheme
                  ? const Color(0xFF5E3A9E) // Purple on white card
                  : (isLightTheme
                      ? const Color(0xFF5E3A9E)
                      : Colors.white),
            ),
          ),
          if (entry.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Content preview
            Text(
              entry.content,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDarkTheme
                    ? const Color(0xFF5E3A9E).withValues(alpha: 0.85) // Purple on white card
                    : (isLightTheme
                        ? const Color(0xFF5E3A9E).withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.75)),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddEntryButton(bool isLightTheme, bool isDarkTheme) {
    final textColor = isDarkTheme
        ? Colors.white
        : (isLightTheme ? const Color(0xFF5E3A9E) : Colors.white);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GestureDetector(
        onTap: _navigateToAddEntry,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(
              Icons.add_rounded,
              size: 20,
              color: textColor,
            ),
              const SizedBox(width: 8),
              Text(
                'Add Entry',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                color: textColor,
                ),
              ),
            ],
        ),
      ),
    );
  }
}
