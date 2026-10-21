import 'package:flutter/material.dart';

/// Softly fades out the bottom edge of a sign up page, so content that runs
/// under the floating arrows looks blurred away instead of cut off.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, required this.child, this.height = 100});

  /// Bottom padding a scroll view inside needs so its last item can scroll
  /// clear of the arrows (their top is about 90 above the bottom) and the fade.
  static const double scrollPadding = 110;

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fadeStart = bounds.height <= 0
            ? 0.0
            : ((bounds.height - height) / bounds.height).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.black, Colors.transparent],
          stops: [fadeStart, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
