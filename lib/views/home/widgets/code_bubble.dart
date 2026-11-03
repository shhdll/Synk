import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';

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
    borderRadius: BorderRadiusDirectional.only(
      topStart: Radius.circular(24),
      topEnd: Radius.circular(24),
      bottomStart: Radius.circular(24),
      bottomEnd: Radius.circular(6),
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
        alignment: AlignmentDirectional.bottomEnd,
        child: child,
      ),
      child: Semantics(
        button: true,
        label: context.l10n.haveAnActivityCodeJoinWith,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: _shape,
            shadows: [
              BoxShadow(
                color: SynkColors.orangeDark.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                  horizontal: expanded ? 12 : 11,
                  vertical: 10,
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.key_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      if (expanded) ...[
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.haveACode,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.5,
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
