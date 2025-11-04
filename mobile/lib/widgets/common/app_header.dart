import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppHeader extends StatelessWidget {
  final String title;

  const AppHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.3),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderGray, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Menu Button (left)
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu, size: 24),
              color: AppColors.textWhite,
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),

          // Title (center)
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Spacer to balance the menu button
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
