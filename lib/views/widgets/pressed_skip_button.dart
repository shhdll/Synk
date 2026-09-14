import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// The "Skip" text button on onboarding slides, which turns orange while
// pressed and can hide itself while keeping the layout stable.
class PressedSkipButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isVisible;

  const PressedSkipButton({
    super.key,
    required this.onTap,
    this.isVisible = true,
  });

  @override
  State<PressedSkipButton> createState() => _PressedSkipButtonState();
}

class _PressedSkipButtonState extends State<PressedSkipButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not visible, render an empty SizedBox with identical padding/height
    // so layout alignments (dots, back/forward buttons) remain stable.
    if (!widget.isVisible) {
      return const SizedBox(
        height: 25, // Height of the text + padding
        child: SizedBox.shrink(),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 100),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _isPressed ? SynkColors.orange : SynkColors.textSecondary,
          ),
          child: const Text('Skip'),
        ),
      ),
    );
  }
}
