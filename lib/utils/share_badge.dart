import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/badges.dart';
import '../core/constants/synk_colors.dart';
import '../l10n/l10n.dart';
import '../views/home/widgets/badge_celebration.dart';
import '../views/home/widgets/badge_widgets.dart';

// Story-sized card, drawn at 3x.
const Size _cardSize = Size(360, 640);
const double _cardScale = 3;

// Opens the phone's share menu with a story card of an earned badge. Synk
// is in that menu too, for sending it into chats.
// [buttonContext] is the tapped button's context; iPads point the menu at it.
Future<void> shareBadge(
  BuildContext buttonContext, {
  required String id,
  required DateTime earnedAt,
}) async {
  final l10n = buttonContext.l10n;
  final box = buttonContext.findRenderObject() as RenderBox?;
  final messenger = ScaffoldMessenger.maybeOf(buttonContext);
  final card = _cardMaker(buttonContext, id, earnedAt);
  try {
    final file = await card();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: l10n.badgeShareMessage(badgeName(l10n, id)),
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.couldntOpenTheShareMenu)));
  }
}

// Reads what the card needs from [context] now, and draws it to a file
// when called.
Future<File> Function() _cardMaker(
  BuildContext context,
  String id,
  DateTime earnedAt,
) {
  final badge = badgeInfo(id)!;
  final l10n = context.l10n;
  final name = badgeName(l10n, id);
  final rule = badgeRule(l10n, id);
  final label = l10n.badgeNewTitle;
  final date = DateFormat.yMMMd(l10n.localeName).format(earnedAt.toLocal());
  final direction = Directionality.of(context);
  return () async {
    final png = await _drawCard(
      badge: badge,
      name: name,
      rule: rule,
      label: label,
      date: date,
      direction: direction,
    );
    final dir = await getTemporaryDirectory();
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    final file = File('${dir.path}/synk_badge_$safeId.png');
    await file.writeAsBytes(png, flush: true);
    return file;
  };
}

Future<Uint8List> _drawCard({
  required BadgeInfo badge,
  required String name,
  required String rule,
  required String label,
  required String date,
  required TextDirection direction,
}) async {
  // Offline, the card falls back to the system font.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.nunito(fontWeight: FontWeight.w900),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {}
  final logo = await _loadImage('assets/synk_logo_transparent.png');

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(_cardScale);
  final w = _cardSize.width;
  final h = _cardSize.height;
  final full = Offset.zero & _cardSize;
  final glow = badgeGlow(badge.tier);
  const center = Offset(180, 250);

  // The same dark night as the celebration, with Synk pink and teal
  // glowing in from the corners.
  canvas.drawRect(full, Paint()..color = const Color(0xFF15121B));
  void corner(Offset at, Color color, double alpha) => canvas.drawRect(
    full,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: at, radius: 460)),
  );
  corner(const Offset(20, -20), SynkColors.pink, 0.32);
  corner(Offset(w + 20, h + 20), SynkColors.teal, 0.30);

  // Soft rays and a glow in the badge's color.
  const rays = 12;
  final rayPaint = Paint()
    ..shader = RadialGradient(
      colors: [glow.withValues(alpha: 0.16), glow.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: center, radius: 380));
  for (var i = 0; i < rays; i++) {
    final a = i * 2 * math.pi / rays + 0.1;
    const half = math.pi / rays / 2.2;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a - half) * 700,
          center.dy + math.sin(a - half) * 700,
        )
        ..lineTo(
          center.dx + math.cos(a + half) * 700,
          center.dy + math.sin(a + half) * 700,
        )
        ..close(),
      rayPaint,
    );
  }
  canvas.drawCircle(
    center,
    150,
    Paint()
      ..shader = RadialGradient(
        colors: [
          glow.withValues(alpha: 0.5),
          glow.withValues(alpha: 0.12),
          glow.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: 150)),
  );

  // A little confetti, kept away from the text.
  final random = math.Random(badge.id.hashCode);
  final colors = [glow, SynkColors.pink, SynkColors.orange, SynkColors.teal];
  for (var i = 0; i < 46; i++) {
    final p = Offset(random.nextDouble() * w, 20 + random.nextDouble() * 430);
    if ((p - center).distance < 120) continue;
    final paint = Paint()
      ..color = colors[i % colors.length].withValues(
        alpha: 0.45 + random.nextDouble() * 0.45,
      );
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(random.nextDouble() * math.pi);
    if (i % 3 == 0) {
      canvas.drawCircle(Offset.zero, 2 + random.nextDouble() * 1.5, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 7 + random.nextDouble() * 4,
            height: 3 + random.nextDouble() * 2,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  _text(
    canvas,
    label,
    TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: glow),
    64,
    direction,
  );
  paintEarnedBadge(
    canvas,
    badge,
    Rect.fromCenter(center: center, width: 210, height: 210),
  );
  var y = 392.0;
  y += _text(
    canvas,
    name,
    GoogleFonts.nunito(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w900,
      color: Colors.white,
    ),
    y,
    direction,
  );
  y += 8;
  y += _text(
    canvas,
    rule,
    TextStyle(
      fontSize: 15,
      height: 1.35,
      color: Colors.white.withValues(alpha: 0.75),
    ),
    y,
    direction,
  );
  _text(
    canvas,
    date,
    TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.5),
    ),
    y + 12,
    direction,
  );

  // The knot logo on a white tile, then the name and site.
  const tile = 48.0;
  final word = TextPainter(
    text: TextSpan(
      text: 'Synk',
      style: GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final rowWidth = tile + 12 + word.width;
  final left = (w - rowWidth) / 2;
  const top = 540.0;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, tile, tile),
      const Radius.circular(13),
    ),
    Paint()..color = Colors.white,
  );
  canvas.drawImageRect(
    logo,
    Offset.zero & Size(logo.width.toDouble(), logo.height.toDouble()),
    Rect.fromLTWH(left + 6, top + 6, tile - 12, tile - 12),
    Paint()..filterQuality = FilterQuality.high,
  );
  word.paint(canvas, Offset(left + tile + 12, top + (tile - word.height) / 2));
  word.dispose();
  _text(
    canvas,
    'synk.cc',
    TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.6),
    ),
    h - 38,
    TextDirection.ltr,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (w * _cardScale).round(),
    (h * _cardScale).round(),
  );
  picture.dispose();
  logo.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

// Centered text, up to two lines. Returns its height.
double _text(
  Canvas canvas,
  String text,
  TextStyle style,
  double top,
  TextDirection direction,
) {
  const maxWidth = 260.0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: direction,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, Offset((_cardSize.width - painter.width) / 2, top));
  final height = painter.height;
  painter.dispose();
  return height;
}

Future<ui.Image> _loadImage(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
