import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/synk_colors.dart';

/// Draws a native Google Maps marker: a round orange pin with a white icon
/// and a short point, like the iOS Maps pins.
/// A [count] above 1 adds a badge for activities sharing the same spot.
class ActivityMapMarker {
  static Future<BitmapDescriptor> create(
    IconData icon, {
    bool selected = false,
    int count = 1,
  }) async {
    const logicalWidth = 72.0;
    const logicalHeight = 92.0;
    const scale = 3.0;
    const head = Offset(36, 50);
    const radius = 23.0;
    const tip = Offset(36, 87);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);

    // Unselected pins are drawn at 68%, scaled around the tip so both sizes
    // point to the same place.
    if (!selected) {
      canvas.translate(tip.dx, tip.dy);
      canvas.scale(0.68);
      canvas.translate(-tip.dx, -tip.dy);
    }

    if (selected) {
      canvas.drawCircle(
        head,
        radius + 11,
        Paint()..color = SynkColors.orange.withValues(alpha: 0.22),
      );
    }

    // A small soft spot where the pin touches the map.
    canvas.drawOval(
      Rect.fromCenter(center: tip, width: 12, height: 4),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // The point under the head.
    final point = Path()
      ..moveTo(head.dx - 7, head.dy + radius - 3)
      ..lineTo(head.dx, tip.dy - 2)
      ..lineTo(head.dx + 7, head.dy + radius - 3)
      ..close();
    canvas.drawPath(point, Paint()..color = SynkColors.orangeDark);

    final circle = Path()
      ..addOval(Rect.fromCircle(center: head, radius: radius));
    canvas.drawShadow(circle, const Color(0x44000000), 4, false);
    canvas.drawCircle(head, radius, Paint()..color = Colors.white);
    canvas.drawCircle(head, radius - 3, Paint()..color = SynkColors.orangeDark);

    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(head.dx - painter.width / 2, head.dy - painter.height / 2),
    );

    if (count > 1) {
      const badgeCenter = Offset(57, 30);
      canvas.drawCircle(badgeCenter, 13, Paint()..color = Colors.white);
      canvas.drawCircle(
        badgeCenter,
        10.5,
        Paint()..color = SynkColors.textPrimary,
      );
      final badge = TextPainter(
        text: TextSpan(
          text: count > 9 ? '9+' : '$count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      badge.paint(
        canvas,
        badgeCenter - Offset(badge.width / 2, badge.height / 2),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalWidth * scale).round(),
      (logicalHeight * scale).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Failed to render Synk map marker');
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      imagePixelRatio: scale,
    );
  }
}
