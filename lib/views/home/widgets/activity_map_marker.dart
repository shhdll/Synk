import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/synk_colors.dart';

/// Draws a native Google Maps marker with Synk's orange gradient and a white icon.
class ActivityMapMarker {
  static Future<BitmapDescriptor> create(IconData icon, {bool selected = false}) async {
    const logicalWidth = 72.0;
    const logicalHeight = 92.0;
    const scale = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);

    if (selected) {
      canvas.drawCircle(
        const Offset(36, 34),
        35,
        Paint()..color = SynkColors.orange.withValues(alpha: 0.25),
      );
    }

    final pin = Path()
      ..moveTo(36, 87)
      ..cubicTo(26, 73, 9, 53, 9, 35)
      ..cubicTo(9, 19, 21, 8, 36, 8)
      ..cubicTo(51, 8, 63, 19, 63, 35)
      ..cubicTo(63, 53, 46, 73, 36, 87)
      ..close();

    canvas.drawShadow(pin, const Color(0x55000000), 5, false);
    canvas.drawPath(
      pin,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(36, 8),
          const Offset(36, 87),
          const [SynkColors.orange, SynkColors.orangeDark],
        ),
    );
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4 : 3,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 28,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(36 - painter.width / 2, 35 - painter.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalWidth * scale).round(),
      (logicalHeight * scale).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Failed to render Synk map marker');
    return BitmapDescriptor.bytes(data.buffer.asUint8List(), imagePixelRatio: scale);
  }
}
