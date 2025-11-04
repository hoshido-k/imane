import 'package:flutter/material.dart';
import '../../models/pop.dart';

class PopCard extends StatefulWidget {
  final Pop pop;
  final bool enableAnimation;
  final bool isLongPressed;

  const PopCard({
    super.key,
    required this.pop,
    this.enableAnimation = true,
    this.isLongPressed = false,
  });

  @override
  State<PopCard> createState() => _PopCardState();
}

class _PopCardState extends State<PopCard> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _bounceController;
  late Animation<double> _bounceScaleAnimation;

  bool _isHovered = false;
  int _floatCycleCount = 0;

  @override
  void initState() {
    super.initState();

    if (widget.enableAnimation) {
      // 既存の上下アニメーション
      _floatController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      )..repeat(reverse: true);

      _floatAnimation = Tween<double>(
        begin: -3.0,
        end: 3.0,
      ).animate(CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ));

      // 頂上検出とバウンストリガー
      double _previousValue = _floatAnimation.value;
      bool _wasAtTop = false;

      _floatController.addListener(() {
        final currentValue = _floatAnimation.value;

        // 頂上（2.5以上）に到達したか検出
        final isAtTop = currentValue >= 2.5;

        // 頂上から降りてきた瞬間を検出
        if (_wasAtTop && !isAtTop && _previousValue > currentValue) {
          _floatCycleCount++;

          // 2周ごとにバウンス
          if (_floatCycleCount % 2 == 0) {
            _bounceController.forward(from: 0.0);
          }
        }

        _wasAtTop = isAtTop;
        _previousValue = currentValue;
      });

      // 定期的なバウンスアニメーション
      _bounceController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );

      _bounceScaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.05)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.05, end: 0.95)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.95, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 40,
        ),
      ]).animate(_bounceController);

    }
  }

  @override
  void dispose() {
    if (widget.enableAnimation) {
      _floatController.dispose();
      _bounceController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = AnimatedScale(
          scale: widget.isLongPressed ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main card content
              Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(widget.pop.category.color),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                    if (widget.isLongPressed)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Icon and Name
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.pop.category.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.pop.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Message with lighter background
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.pop.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Footer: Time and Likes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Time
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.pop.timeAgo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Likes
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.pop.likeCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Pin "V" shape at the bottom
              CustomPaint(
                size: const Size(20, 10),
                painter: _PinPainter(color: Color(widget.pop.category.color)),
              ),
            ],
          ),
        );

    if (widget.enableAnimation) {
      // 上下フロートアニメーションを適用
      cardContent = AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: cardContent,
      );

      // バウンススケールアニメーションを適用（最後に適用して確実に弾むように）
      return AnimatedBuilder(
        animation: _bounceScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceScaleAnimation.value,
            child: child,
          );
        },
        child: cardContent,
      );
    }

    return cardContent;
  }
}

// Custom painter for the pin shape
class _PinPainter extends CustomPainter {
  final Color color;

  _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0) // Top left
      ..lineTo(size.width / 2, size.height) // Bottom center (point)
      ..lineTo(size.width, 0) // Top right
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => oldDelegate.color != color;
}
