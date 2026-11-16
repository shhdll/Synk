import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Text where web links are underlined and open on tap.
class LinkedText extends StatefulWidget {
  const LinkedText(
    this.text, {
    super.key,
    this.style,
    this.textDirection,
  });

  final String text;
  final TextStyle? style;
  final TextDirection? textDirection;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  static final _linkPattern = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(String link) async {
    final uri = Uri.tryParse(link.startsWith('http') ? link : 'https://$link');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in _linkPattern.allMatches(widget.text)) {
      var link = match.group(0)!;
      // Leave trailing punctuation out of the link.
      final trimmed = link.replaceAll(RegExp(r'[.,!?;:)\]]+$'), '');
      final end = match.start + trimmed.length;
      link = trimmed;
      if (match.start > start) {
        spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      }
      final recognizer = TapGestureRecognizer()..onTap = () => _open(link);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: link,
        style: const TextStyle(decoration: TextDecoration.underline),
        recognizer: recognizer,
      ));
      start = end;
    }
    if (start < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(start)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      textDirection: widget.textDirection,
    );
  }
}
