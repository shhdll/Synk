import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// Behind the messages in a chat: two still, soft glows, faint doodles of
// the things people do on Synk and a few outlined Synk knots. Drawn once;
// it doesn't move.
class ChatWallpaper extends StatefulWidget {
  const ChatWallpaper({super.key});

  @override
  State<ChatWallpaper> createState() => _ChatWallpaperState();
}

class _ChatWallpaperState extends State<ChatWallpaper> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _logo = info.image);
  });
  ui.Image? _logo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = const AssetImage(
      'assets/synk_logo_transparent.png',
    ).resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The doodles show right away; the knots join once the logo has loaded.
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _WallpaperPainter(_logo),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter(this.logo);

  final ui.Image? logo;

  static const _doodles = [
    Icons.sports_tennis_rounded,
    Icons.directions_bike_rounded,
    Icons.directions_run_rounded,
    Icons.palette_outlined,
    Icons.camera_alt_outlined,
    Icons.extension_outlined,
    Icons.fitness_center_rounded,
    Icons.coffee_outlined,
    Icons.favorite_border_rounded,
    Icons.star_border_rounded,
  ];

  static const double _cell = 76;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = SynkColors.background);

    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(Offset(0, size.height * 0.12), size.width * 0.8, SynkColors.pink);
    glow(
      Offset(size.width, size.height * 0.85),
      size.width * 0.9,
      SynkColors.teal,
    );

    // Same seed every time, so the doodles stay put between rebuilds.
    final random = math.Random(7);
    final color = SynkColors.ink.withValues(alpha: 0.05);
    final rows = (size.height / _cell).ceil() + 1;
    final columns = (size.width / _cell).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final isLogo = random.nextDouble() < 0.12;
        final icon = _doodles[random.nextInt(_doodles.length)];
        final rotation = (random.nextDouble() - 0.5) * 0.9;
        final jitter = Offset(
          (random.nextDouble() - 0.5) * 26,
          (random.nextDouble() - 0.5) * 26,
        );
        // Every other row shifts by half a cell, like a brick wall.
        final center =
            Offset(column * _cell + (row.isOdd ? _cell / 2 : 0), row * _cell) +
            jitter;
        final logo = this.logo;
        if (isLogo && logo != null) {
          _drawLogoOutline(canvas, logo, center, 34, rotation);
        } else {
          _drawIcon(
            canvas,
            icon,
            center,
            20 + random.nextDouble() * 6,
            rotation,
            color,
          );
        }
      }
    }
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    double rotation,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }

  // The logo grown by a hair, with the logo itself cut out of it, leaves
  // just its outline.
  void _drawLogoOutline(
    Canvas canvas,
    ui.Image logo,
    Offset center,
    double size,
    double rotation,
  ) {
    const stroke = 1.6;
    final source = Rect.fromLTWH(
      0,
      0,
      logo.width.toDouble(),
      logo.height.toDouble(),
    );
    final target = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );
    final tint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = const ColorFilter.mode(SynkColors.ink, BlendMode.srcIn);

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation)
      ..saveLayer(
        target.inflate(stroke * 2),
        Paint()..color = Colors.black.withValues(alpha: 0.07),
      );
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawImageRect(
        logo,
        source,
        target.shift(Offset(math.cos(angle), math.sin(angle)) * stroke),
        tint,
      );
    }
    canvas
      ..drawImageRect(
        logo,
        source,
        target,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = BlendMode.dstOut,
      )
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_WallpaperPainter oldDelegate) => oldDelegate.logo != logo;
}
