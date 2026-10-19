import 'package:flutter/material.dart';

const Color _errorColor = Color(0xFFE53935);
const Color _iconGrey = Color(0xFF6B7280);

// The sign-up field look: white rounded box, label inside it with a red *,
// red outline and message on error.
InputDecoration synkInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  bool isRequired = true,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.95),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: Icon(icon, size: 20, color: _iconGrey),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    label: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: _errorColor),
            ),
        ],
        style: const TextStyle(fontSize: 14, color: _iconGrey),
      ),
    ),
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
    errorStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _errorColor,
    ),
    border: const _BoxBorder(),
    enabledBorder: const _BoxBorder(),
    focusedBorder: const _BoxBorder(),
    errorBorder: const _BoxBorder(
      borderSide: BorderSide(color: _errorColor, width: 1.2),
    ),
    focusedErrorBorder: const _BoxBorder(
      borderSide: BorderSide(color: _errorColor, width: 1.2),
    ),
  );
}

// Text style for what the user types, matching sign-up.
const TextStyle synkInputTextStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: Color(0xFF1E1E1E),
);

// Rounded box that keeps the floating label inside (an outline border
// would put it on the border line instead).
class _BoxBorder extends InputBorder {
  const _BoxBorder({super.borderSide = BorderSide.none});

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  _BoxBorder copyWith({BorderSide? borderSide}) =>
      _BoxBorder(borderSide: borderSide ?? this.borderSide);

  @override
  ShapeBorder scale(double t) =>
      _BoxBorder(borderSide: borderSide.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_radius.toRRect(rect).deflate(borderSide.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_radius.toRRect(rect));

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none) return;
    canvas.drawRRect(
      _radius.toRRect(rect).deflate(borderSide.width / 2),
      borderSide.toPaint(),
    );
  }
}
