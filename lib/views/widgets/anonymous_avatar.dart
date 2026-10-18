import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// Stand-in picture for a member whose identity is hidden (shown to users
// whose join request is still pending): a plain grey silhouette.
class AnonymousAvatar extends StatelessWidget {
  const AnonymousAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SynkColors.textSecondary.withValues(alpha: 0.18),
            SynkColors.textSecondary.withValues(alpha: 0.32),
          ],
        ),
      ),
      child: ClipOval(
        child: Align(
          alignment: const Alignment(0, 1.4),
          child: Icon(
            Icons.person_rounded,
            size: size * 0.95,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}
