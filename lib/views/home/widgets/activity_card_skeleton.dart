import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

class ActivityCardSkeleton extends StatefulWidget {
  const ActivityCardSkeleton({super.key});

  @override
  State<ActivityCardSkeleton> createState() => _ActivityCardSkeletonState();
}

class _ActivityCardSkeletonState extends State<ActivityCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final shimmerValue = _shimmerController.value;
        final baseColor = const Color(0xFFEFE8DB);
        final highlightColor = Colors.white.withValues(alpha: 0.65);
        final activeColor = Color.lerp(
          baseColor,
          highlightColor,
          shimmerValue,
        )!;

        Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: activeColor,
            borderRadius: BorderRadius.circular(6),
          ),
        );

        // Mirrors DiscoveryActivityCard: thumbnail + three lines, then footer.
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SynkColors.textSecondary.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        bar(double.infinity, 14),
                        const SizedBox(height: 12),
                        bar(120, 11),
                        const SizedBox(height: 8),
                        bar(150, 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(radius: 10, backgroundColor: activeColor),
                  const SizedBox(width: 6),
                  bar(80, 11),
                  const Spacer(),
                  bar(36, 11),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
