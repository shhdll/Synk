import 'package:flutter/material.dart';

// Material Icons has no crown, so this draws one in the same flat, rounded
// style on a 24x24 grid. Sized and colored like an Icon.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CrownPainter(color ?? IconTheme.of(context).color!),
      ),
    );
  }
}

// The host's mark: a small yellow crown on a soft yellow circle.
class HostCrownBadge extends StatelessWidget {
  const HostCrownBadge({super.key});

  static const _yellow = Color(0xFFE0A800);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _yellow.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: CrownIcon(size: 13, color: _yellow.withValues(alpha: 0.85)),
    );
  }
}

class _CrownPainter extends CustomPainter {
  _CrownPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final rounded = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeJoin = StrokeJoin.round;

    // Body: three points rising from a base.
    final body = Path()
      ..moveTo(3.5 * s, 8 * s)
      ..lineTo(8 * s, 12 * s)
      ..lineTo(12 * s, 5.5 * s)
      ..lineTo(16 * s, 12 * s)
      ..lineTo(20.5 * s, 8 * s)
      ..lineTo(19 * s, 17 * s)
      ..lineTo(5 * s, 17 * s)
      ..close();
    canvas.drawPath(body, paint);
    canvas.drawPath(body, rounded);

    // Band under the body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(5 * s, 18.5 * s, 19 * s, 20.5 * s),
        Radius.circular(1 * s),
      ),
      paint,
    );

    // Jewels on the tips.
    for (final x in [3.5, 12.0, 20.5]) {
      canvas.drawCircle(
        Offset(x * s, (x == 12.0 ? 4.6 : 7.2) * s),
        1.5 * s,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}
