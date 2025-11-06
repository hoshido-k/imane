import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Bottom navigation bar matching Figma design for imane app
/// Displays three tabs: Schedule, Friends, Settings
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get bottom padding from MediaQuery (safe area insets)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFD8D4CF), width: 1),
        ),
      ),
      // Use device's actual bottom safe area, with minimum padding
      padding: EdgeInsets.only(
        top: 12,
        left: 24,
        right: 24,
        bottom: bottomPadding > 0 ? bottomPadding : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _NavBarItem(
              icon: Icons.calendar_today,
              label: 'スケジュール',
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _NavBarItem(
              icon: Icons.people_outline,
              label: 'フレンド',
              isActive: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: _NavBarItem(
              icon: Icons.settings_outlined,
              label: '設定',
              isActive: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container with background
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? Colors.white : AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Label text
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isActive ? AppColors.primary : AppColors.textPrimary,
              height: 1.33,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
