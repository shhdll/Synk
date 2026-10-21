import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// A schedule conflict message with the other activity's title as a link.
// [message] builds the sentence around the title it's given.
class ScheduleConflictText extends StatefulWidget {
  const ScheduleConflictText({
    super.key,
    required this.title,
    required this.message,
    required this.onTitleTap,
    this.style,
    this.textAlign,
  });

  final String title;
  final String Function(String title) message;
  final VoidCallback onTitleTap;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<ScheduleConflictText> createState() => _ScheduleConflictTextState();
}

class _ScheduleConflictTextState extends State<ScheduleConflictText> {
  // Stands in for the title so the translated sentence can be split.
  static const String _marker = '\u0000';

  late final TapGestureRecognizer _recognizer = TapGestureRecognizer()
    ..onTap = () => widget.onTitleTap();

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.message(_marker).split(_marker);
    final before = parts.first;
    final after = parts.length > 1 ? parts.sublist(1).join() : '';

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: widget.title,
            recognizer: _recognizer,
            style: const TextStyle(
              color: SynkColors.orangeDark,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: SynkColors.orangeDark,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}
