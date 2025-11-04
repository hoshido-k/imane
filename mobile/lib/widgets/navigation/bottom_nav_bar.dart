import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.8),
        border: const Border(
          top: BorderSide(color: AppColors.borderGray, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: EdgeInsets.zero, // Remove minimum padding
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10), // Reduced from 8 to 4
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.map_rounded,
                label: 'Map',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              // _NavBarItem(
              //   icon: Icons.add_box,
              //   label: 'Post',
              //   isActive: currentIndex == 1,
              //   // onTap: () => onTap(2),
              // ),
              _NavBarItem(
                icon: Icons.star,
                label: 'Reaction',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavBarItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              // _NavBarItem(
              //   icon: Icons.account_circle_rounded,
              //   label: 'Profile',
              //   isActive: currentIndex == 3,
              //   onTap: () => onTap(3),
              // ),
            ],
          ),
        ),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Reduced from 8 to 4
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textGrayDark,
              size: 24,
            ),
            const SizedBox(height: 2), // Reduced from 4 to 2
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textGrayDark,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
