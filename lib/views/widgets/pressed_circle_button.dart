import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// A circular icon button (back/forward on onboarding) that fills orange
// while pressed and dims when disabled.
class PressedCircleButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const PressedCircleButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<PressedCircleButton> createState() => _PressedCircleButtonState();
}

class _PressedCircleButtonState extends State<PressedCircleButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;

    if (mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: !widget.enabled
              ? Colors.white.withValues(alpha: 0.35)
              : _isPressed
              ? SynkColors.orange
              : Colors.white.withValues(alpha: 0.82),
          boxShadow: widget.enabled
              ? [
                  BoxShadow(
                    color: SynkColors.orangeDark.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Icon(
          widget.icon,
          size: 24,
          color: !widget.enabled
              ? SynkColors.textSecondary.withValues(alpha: 0.4)
              : _isPressed
              ? Colors.white
              : SynkColors.textPrimary,
        ),
      ),
    );
  }
}
