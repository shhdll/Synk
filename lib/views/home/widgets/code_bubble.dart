import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// Floating "Have a code?" bubble in the corner of Home, like a chat
// launcher. Shrinks to just the key while the user scrolls down the feed
// and opens back up when they scroll up.
class CodeBubble extends StatelessWidget {
  const CodeBubble({super.key, required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  // Chat-bubble shape: round everywhere except the corner nearest the
  // screen edge, which acts as the bubble's tail.
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Pops in once when Home first appears.
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.bottomRight,
        child: child,
      ),
      child: Semantics(
        button: true,
        label: 'Have an activity code? Join with it',
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: _shape,
            shadows: [
              BoxShadow(
                color: SynkColors.orangeDark.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            shape: _shape,
            clipBehavior: Clip.antiAlias,
            color: SynkColors.orangeDark,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 16 : 14,
                  vertical: 14,
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.key_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      if (expanded) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Have a code?',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
