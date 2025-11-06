import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/custom_calendar.dart';

/// Step 1: Date and time selection screen
class Step1DateTimeScreen extends StatefulWidget {
  final DateTime? initialDateTime;
  final Function(DateTime) onNext;
  final bool isEditMode;

  const Step1DateTimeScreen({
    super.key,
    this.initialDateTime,
    required this.onNext,
    this.isEditMode = false,
  });

  @override
  State<Step1DateTimeScreen> createState() => _Step1DateTimeScreenState();
}

class _Step1DateTimeScreenState extends State<Step1DateTimeScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _hasInitialValue = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDateTime != null) {
      final initial = widget.initialDateTime!;
      _selectedDate = DateTime(initial.year, initial.month, initial.day);
      _selectedTime = TimeOfDay(hour: initial.hour, minute: initial.minute);
      _hasInitialValue = true;
    }
  }

  void _onNextPressed() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('日時を選択してください'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    widget.onNext(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildPromptCard(),
                    const SizedBox(height: 16),
                    _buildCalendar(),
                    const SizedBox(height: 16),
                    _buildTimePicker(),
                  ],
                ),
              ),
            ),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  /// Header with back button and progress
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEditMode ? '日時を編集' : '日時を設定',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ステップ 1 / 4',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress indicator
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Prompt card "いつ行きますか？"
  Widget _buildPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'いつ行きますか？',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '選択中の日時',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedDate != null && _selectedTime != null
                      ? _formatFullDateTime(_selectedDate!, _selectedTime!)
                      : '---',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDateTime(DateTime date, TimeOfDay time) {
    return '${date.year}年${date.month}月${date.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Calendar widget
  Widget _buildCalendar() {
    return Center(
      child: CustomCalendar(
        selectedDate: _selectedDate ?? DateTime.now(),
        minDate: DateTime.now(),
        maxDate: DateTime.now().add(const Duration(days: 365)),
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
            // Set default time if not set yet
            if (_selectedTime == null) {
              _selectedTime = TimeOfDay.now();
            }
          });
        },
      ),
    );
  }

  /// Time picker with scrollable hours and minutes
  Widget _buildTimePicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '時刻を選択',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '時',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildScrollablePicker(
                      itemCount: 24,
                      selectedIndex: _selectedTime?.hour ?? 0,
                      onChanged: (index) {
                        setState(() {
                          _selectedTime = TimeOfDay(
                            hour: index,
                            minute: _selectedTime?.minute ?? 0,
                          );
                          // Set default date if not set yet
                          if (_selectedDate == null) {
                            _selectedDate = DateTime.now();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '分',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildScrollablePicker(
                      itemCount: 60,
                      selectedIndex: _selectedTime?.minute ?? 0,
                      onChanged: (index) {
                        setState(() {
                          _selectedTime = TimeOfDay(
                            hour: _selectedTime?.hour ?? 0,
                            minute: index,
                          );
                          // Set default date if not set yet
                          if (_selectedDate == null) {
                            _selectedDate = DateTime.now();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'スクロールまたはタップで時刻を選択',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Scrollable picker for hours/minutes
  Widget _buildScrollablePicker({
    required int itemCount,
    required int selectedIndex,
    required Function(int) onChanged,
  }) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.inputBorder.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Next button at bottom
  Widget _buildNextButton() {
    final bool isEnabled = _selectedDate != null && _selectedTime != null;

    return Container(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isEnabled ? _onNextPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.inputBorder,
            disabledForegroundColor: AppColors.textSecondary,
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            '次へ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.3125,
            ),
          ),
        ),
      ),
    );
  }
}
