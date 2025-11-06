import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Custom calendar widget matching Figma design
class CustomCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final Function(DateTime) onDateSelected;

  const CustomCalendar({
    super.key,
    required this.selectedDate,
    this.minDate,
    this.maxDate,
    required this.onDateSelected,
  });

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<CustomCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      1,
    );
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  List<DateTime?> _generateCalendarDays() {
    final firstDayOfMonth = _displayedMonth;
    final lastDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    );

    // Get the weekday of the first day (0 = Sunday)
    final firstWeekday = firstDayOfMonth.weekday % 7;

    // Previous month days to fill
    final previousMonthDays = <DateTime?>[];
    final previousMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      0,
    );

    for (int i = firstWeekday - 1; i >= 0; i--) {
      previousMonthDays.add(DateTime(
        previousMonth.year,
        previousMonth.month,
        previousMonth.day - i,
      ));
    }

    // Current month days
    final currentMonthDays = <DateTime?>[];
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      currentMonthDays.add(DateTime(
        _displayedMonth.year,
        _displayedMonth.month,
        day,
      ));
    }

    // Next month days to fill (up to 6 weeks = 42 days)
    final totalDays = previousMonthDays.length + currentMonthDays.length;
    final nextMonthDaysCount = 42 - totalDays;
    final nextMonthDays = <DateTime?>[];

    for (int day = 1; day <= nextMonthDaysCount; day++) {
      nextMonthDays.add(DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        day,
      ));
    }

    return [...previousMonthDays, ...currentMonthDays, ...nextMonthDays];
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInCurrentMonth(DateTime? date) {
    if (date == null) return false;
    return date.year == _displayedMonth.year &&
        date.month == _displayedMonth.month;
  }

  Color _getDateColor(DateTime? date, bool isSelected) {
    if (date == null) return const Color(0xFFD8D4CF);
    if (isSelected) return Colors.white;
    if (!_isInCurrentMonth(date)) return const Color(0xFFD8D4CF);

    final weekday = date.weekday % 7;
    if (weekday == 0) return const Color(0xFFE57373); // Sunday - red
    if (weekday == 6) return const Color(0xFF64B5F6); // Saturday - blue
    return const Color(0xFF3D3D3D); // Weekday - dark gray
  }

  @override
  Widget build(BuildContext context) {
    final calendarDays = _generateCalendarDays();
    final today = DateTime.now();

    return Container(
      width: 330,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 1),
            blurRadius: 3,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 1),
            blurRadius: 2,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with month/year and navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _previousMonth,
                  icon: const Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
              ),
              // Month and year
              Text(
                '${_displayedMonth.year}年 ${_displayedMonth.month}月',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF3D3D3D),
                  letterSpacing: -0.3125,
                ),
              ),
              // Next button
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _nextMonth,
                  icon: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeekdayHeader('日', const Color(0xFFE57373)),
              _buildWeekdayHeader('月', const Color(0xFF5A4A40)),
              _buildWeekdayHeader('火', const Color(0xFF5A4A40)),
              _buildWeekdayHeader('水', const Color(0xFF5A4A40)),
              _buildWeekdayHeader('木', const Color(0xFF5A4A40)),
              _buildWeekdayHeader('金', const Color(0xFF5A4A40)),
              _buildWeekdayHeader('土', const Color(0xFF64B5F6)),
            ],
          ),
          const SizedBox(height: 8),
          // Calendar grid
          SizedBox(
            height: 241,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: calendarDays.length,
              itemBuilder: (context, index) {
                final date = calendarDays[index];
                if (date == null) {
                  return const SizedBox();
                }

                final isSelected = _isSameDay(date, widget.selectedDate);
                final dateColor = _getDateColor(date, isSelected);

                return GestureDetector(
                  onTap: () {
                    if (_isInCurrentMonth(date)) {
                      widget.onDateSelected(date);
                    }
                  },
                  child: Container(
                    width: 36.852,
                    height: 36.852,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFB85D4D)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: dateColor,
                        letterSpacing: -0.1504,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Today indicator
          Text(
            '今日: ${today.year}年${today.month}月${today.day}日',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7969),
              letterSpacing: -0.1504,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(String text, Color color) {
    return SizedBox(
      width: 36.852,
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: color,
            letterSpacing: -0.1504,
          ),
        ),
      ),
    );
  }
}
