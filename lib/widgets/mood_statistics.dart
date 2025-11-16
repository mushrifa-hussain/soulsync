import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:soulsync_dairyapp/providers/diary_entries_provider.dart';
import 'package:soulsync_dairyapp/models/diary_entry.dart';

class MoodStatisticsWidget extends StatefulWidget {
  const MoodStatisticsWidget({super.key});

  @override
  State<MoodStatisticsWidget> createState() => _MoodStatisticsWidgetState();
}

class _MoodStatisticsWidgetState extends State<MoodStatisticsWidget> {
  String _moodFilter = 'Last 7 days';
  Map<String, int> _moodCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoodStatistics();
    });
  }

  void _loadMoodStatistics() {
    final provider = Provider.of<DiaryEntriesProvider>(context, listen: false);
    List<DiaryEntry> entries = provider.entries;

    final now = DateTime.now();
    switch (_moodFilter) {
      case 'Last 7 days':
        entries = entries.where((e) =>
            e.timestamp.isAfter(now.subtract(const Duration(days: 7)))).toList();
        break;
      case 'Last 30 days':
        entries = entries.where((e) =>
            e.timestamp.isAfter(now.subtract(const Duration(days: 30)))).toList();
        break;
      case 'All time':
      default:
        break;
    }

    final Map<String, int> counts = {};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty) {
        counts[entry.mood] = (counts[entry.mood] ?? 0) + 1;
      }
    }

    setState(() {
      _moodCounts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isLightTheme ? 0.5 : 0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLightTheme
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLightTheme ? 0.08 : 0.25),
            blurRadius: 18,
            offset: const Offset(0, 5),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mood Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              DropdownButton<String>(
                value: _moodFilter,
                items: const [
                  DropdownMenuItem(value: 'Last 7 days', child: Text('Last 7 days')),
                  DropdownMenuItem(value: 'Last 30 days', child: Text('Last 30 days')),
                  DropdownMenuItem(value: 'All time', child: Text('All time')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _moodFilter = value;
                    });
                    _loadMoodStatistics();
                  }
                },
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
                underline: Container(),
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                dropdownColor: colorScheme.surface,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_moodCounts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No mood data available',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _moodCounts.values.isEmpty
                      ? 1.0
                      : _moodCounts.values.reduce((a, b) => a > b ? a : b).toDouble() + 1,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => colorScheme.primaryContainer,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          // Show all possible mood emojis at bottom, not just used ones
                          final allMoods = ['😊', '😢', '😴', '😍', '🤔', '😌', '😎', '🥰'];
                          if (value.toInt() < allMoods.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                allMoods[value.toInt()],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 50,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(8, (index) {
                    // All possible mood emojis
                    final allMoods = ['😊', '😢', '😴', '😍', '🤔', '😌', '😎', '🥰'];
                    final mood = allMoods[index];
                    final count = _moodCounts[mood] ?? 0;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.6),
                            ],
                          ),
                          width: 28,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

