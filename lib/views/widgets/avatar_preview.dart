import 'dart:math' as math;

import 'package:flutter/material.dart';

// Shows a profile photo large, in a circle. Tap anywhere to close.
Future<void> showAvatarPreview(BuildContext context, ImageProvider image) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, _) {
      final size = math.min(MediaQuery.sizeOf(dialogContext).width - 48, 340.0);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Center(
          child: ClipOval(
            child: Image(
              image: image,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
