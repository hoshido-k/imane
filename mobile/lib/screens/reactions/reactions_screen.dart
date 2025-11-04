import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/app_header.dart';

class ReactionsScreen extends StatelessWidget {
  const ReactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reactions = [
      Reaction(
        id: '1',
        userName: 'サクラ',
        userAvatar: '👩',
        reactionType: ReactionType.like,
        reactionEmoji: '⭐️',
        reactionText: '興味あり',
        message: '',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        distance: '500m',
        popEmoji: '☕',
        popMessage: 'カフェで作業したい！',
        popTimeRemaining: '残り 45分',
        popColor: const Color(0xFF8B4513), // Brown color
        isFriend: true,
      ),
      Reaction(
        id: '2',
        userName: 'ケンタ',
        userAvatar: '👨',
        reactionType: ReactionType.heart,
        reactionEmoji: '⭐️',
        reactionText: '私も！',
        message: '',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        distance: '1.2km',
        popEmoji: '🏃',
        popMessage: 'ランニング仲間募集',
        popTimeRemaining: '残り 2時間',
        popColor: const Color(0xFF22C55E), // Green color
        isFriend: false,
        reactionComment: '明日の朝7時から皇居周辺でどうですか？',
      ),
      Reaction(
        id: '3',
        userName: 'ユウキ',
        userAvatar: '🧑',
        reactionType: ReactionType.comment,
        reactionEmoji: '⭐️',
        reactionText: 'いいね！',
        message: '',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        distance: '300m',
        popEmoji: '🎬',
        popMessage: '映画見に行きたい',
        popTimeRemaining: '残り 1時間30分',
        popColor: const Color(0xFF9A59A9), // Purple color
        isFriend: false,
        reactionComment: '新宿で最新作見ませんか？',
      ),
      Reaction(
        id: '4',
        userName: 'アヤ',
        userAvatar: '👧',
        reactionType: ReactionType.like,
        reactionEmoji: '⭐️',
        reactionText: '興味あり',
        message: '',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        distance: '800m',
        popEmoji: '🎮',
        popMessage: 'ゲームしよう',
        popTimeRemaining: '残り 3時間',
        popColor: const Color(0xFF6366F1), // Indigo color
        isFriend: true,
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              const AppHeader(title: 'Reaction'),

              // Reactions List
              Expanded(
                child: reactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.favorite_outline,
                              size: 64,
                              color: AppColors.textGrayDark,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'まだリアクションはありません',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: reactions.length,
                        itemBuilder: (context, index) {
                          final reaction = reactions[index];
                          return _ReactionItem(reaction: reaction);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionItem extends StatelessWidget {
  final Reaction reaction;

  const _ReactionItem({required this.reaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF211570).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with notification badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF5B6FED), Color(0xFF7389F4)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        reaction.userAvatar,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  // Notification badge
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB2C36),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF1A1F3A),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name with friend badge row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          reaction.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.3125,
                          ),
                        ),
                        if (!reaction.isFriend)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE91E63).withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFFE91E63),
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'フレンドではありません',
                                  style: TextStyle(
                                    color: Color(0xFFE91E63),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Distance and time row
                    Row(
                      children: [
                        Text(
                          reaction.distance,
                          style: const TextStyle(
                            color: Color(0xFF99A1AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(reaction.timestamp),
                          style: const TextStyle(
                            color: Color(0xFF99A1AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                      const SizedBox(height: 6),
                      // Pop card
                      Container(
                        padding: const EdgeInsets.only(
                          left: 15,
                          right: 12,
                          top: 12,
                          bottom: 0,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              reaction.popColor.withValues(alpha: 0.35),
                              reaction.popColor.withValues(alpha: 0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(
                              color: reaction.popColor,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pop emoji and message
                            Row(
                              children: [
                                Text(
                                  reaction.popEmoji,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.56,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  reaction.popMessage,
                                  style: const TextStyle(
                                    color: Color(0xFFFFFFFF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.1504,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Time remaining
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                reaction.popTimeRemaining,
                                style: const TextStyle(
                                  color: Color(0xFF99A1AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.33,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Reaction card (emoji + text + optional comment)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reaction emoji + text
                            Row(
                              children: [
                                Text(
                                  reaction.reactionEmoji,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    reaction.reactionText,
                                    style: const TextStyle(
                                      color: Color(0xFFE0E5ED),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1504,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Reaction comment
                            if (reaction.reactionComment != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                reaction.reactionComment!,
                                style: const TextStyle(
                                  color: Color(0xFFE0E5ED),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Action buttons
                      Row(
                        children: [
                          // Start chat button
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF170FF6),
                                    Color(0xFF765BEE),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF170FF6).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    // TODO: Open chat
                                  },
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'チャットを開始',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.1504,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Spacing between buttons
                          if (!reaction.isFriend) const SizedBox(width: 8),

                          // Add friend button
                          if (!reaction.isFriend)
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFE91E63),
                                      Color(0xFFAB47BC),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE91E63).withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      // TODO: Add friend
                                    },
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_add,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'フレンドに追加',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.1504,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else {
      return '${difference.inDays}日前';
    }
  }
}

enum ReactionType {
  like,
  heart,
  comment,
}

class Reaction {
  final String id;
  final String userName;
  final String userAvatar;
  final ReactionType reactionType;
  final String reactionEmoji;
  final String reactionText;
  final String message;
  final DateTime timestamp;
  final String distance;
  final String popEmoji;
  final String popMessage;
  final String popTimeRemaining;
  final Color popColor;
  final bool isFriend;
  final String? reactionComment;

  Reaction({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.reactionType,
    required this.reactionEmoji,
    required this.reactionText,
    required this.message,
    required this.timestamp,
    required this.distance,
    required this.popEmoji,
    required this.popMessage,
    required this.popTimeRemaining,
    required this.popColor,
    this.isFriend = false,
    this.reactionComment,
  });
}
