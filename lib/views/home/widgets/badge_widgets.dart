import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/constants/badges.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/badges_model.dart';
import '../../../utils/share_badge.dart';
import '../badges_view.dart';
import 'badge_celebration.dart';
import 'recent_activities_section.dart';

// A medal in its group's shape and its tier's color. Higher levels add
// ribbons, then a rosette, then a bigger rosette and a gem, so the level
// shows even while locked and grey. A secret one shows "?" until earned.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({
    super.key,
    required this.badge,
    required this.earned,
    this.sealed = false,
    this.size = 56,
    this.shine,
    this.concealed = false,
  });

  final BadgeInfo badge;
  final bool earned;

  // Someone else's secret badge the viewer hasn't earned: "?" on the medal.
  final bool concealed;

  // Two or more levels away: a lock instead of the icon.
  final bool sealed;
  final double size;

  // Where a band of light crosses the face, from -1 (top left) to 1 (bottom
  // right). For the earned badge celebration.
  final double? shine;

  @override
  Widget build(BuildContext context) {
    final hidden = badge.isSecret && (!earned || concealed);
    final iconColor = !earned
        ? const Color(0xFF9AA0A9)
        : badge.tier == BadgeTier.secret
        ? BadgeTier.gold.light
        : Colors.white;
    // The face is centered a little above the middle, over the ribbons.
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedalPainter(
          shape: badge.group.shape,
          tier: badge.tier,
          earned: earned,
          shine: shine,
        ),
        child: Align(
          alignment: const Alignment(0, -0.04),
          child: hidden
              ? Text(
                  '?',
                  style: GoogleFonts.nunito(
                    fontSize: size * 0.26,
                    fontWeight: FontWeight.w900,
                    color: iconColor,
                  ),
                )
              : Icon(
                  sealed && !earned ? Icons.lock_rounded : badge.iconData,
                  size: size * 0.26,
                  color: iconColor,
                ),
        ),
      ),
    );
  }
}

// An earned badge as BadgeIcon shows it, for images drawn outside the
// widget tree, like the share card.
void paintEarnedBadge(Canvas canvas, BadgeInfo badge, Rect rect) {
  canvas.save();
  canvas.translate(rect.left, rect.top);
  _MedalPainter(
    shape: badge.group.shape,
    tier: badge.tier,
    earned: true,
  ).paint(canvas, rect.size);
  final icon = badge.iconData;
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: rect.width * 0.26,
        height: 1,
        color: badge.tier == BadgeTier.secret
            ? BadgeTier.gold.light
            : Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      (rect.width - painter.width) / 2,
      rect.height * 0.48 - painter.height * 0.48,
    ),
  );
  painter.dispose();
  canvas.restore();
}

// Drawn on a 100 x 100 grid, scaled to the widget.
class _MedalPainter extends CustomPainter {
  const _MedalPainter({
    required this.shape,
    required this.tier,
    required this.earned,
    this.shine,
  });

  final MedalShape shape;
  final BadgeTier tier;
  final bool earned;
  final double? shine;

  static const Offset _center = Offset(50, 48);
  static const double _radius = 24;
  static const Color _lockedLight = Color(0xFFEDEAE3);
  static const Color _lockedDark = Color(0xFFC3BDB2);
  static const Color _lockedTrim = Color(0xFFD3CDC2);
  static const Color _lockedTrimDark = Color(0xFFBFB9AE);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final light = earned ? tier.light : _lockedLight;
    final dark = earned ? tier.dark : _lockedDark;
    final trim = earned ? tier.light : _lockedTrim;
    final trimDark = earned ? tier.dark : _lockedTrimDark;
    final level = tier.level;

    if (level >= 1) {
      final ribbon = Paint()..color = trimDark;
      canvas.drawPath(
        Path()
          ..moveTo(40, 66)
          ..lineTo(32, 95)
          ..lineTo(38.5, 90)
          ..lineTo(43, 97)
          ..lineTo(49, 70)
          ..close(),
        ribbon,
      );
      canvas.drawPath(
        Path()
          ..moveTo(60, 66)
          ..lineTo(68, 95)
          ..lineTo(61.5, 90)
          ..lineTo(57, 97)
          ..lineTo(51, 70)
          ..close(),
        ribbon..color = trimDark.withValues(alpha: 0.85),
      );
    }

    if (level >= 2) {
      final points = level == 3 ? 22 : 18;
      final outer = _polygon(
        points * 2,
        -math.pi / 2,
        level == 3 ? 38 : 34,
        (i) => i.isEven ? 1 : 0.84,
      );
      canvas.drawPath(outer, Paint()..color = trim);
      canvas.drawPath(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = trimDark,
      );
      if (level == 3) {
        canvas.drawPath(
          _polygon(
            points * 2,
            -math.pi / 2 + math.pi / points / 2,
            33,
            (i) => i.isEven ? 1 : 0.86,
          ),
          Paint()..color = trim,
        );
      }
    }

    // The base, a little lower, gives the medal some thickness.
    final face = _face(_radius);
    final rounded = Paint()
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;
    canvas.drawPath(face.shift(const Offset(0, 3)), rounded..color = dark);
    canvas.drawPath(
      face.shift(const Offset(0, 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 4
        ..color = dark,
    );
    final gradient = LinearGradient(
      colors: [light, dark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: _center, radius: _radius + 2));
    canvas.drawPath(face, Paint()..shader = gradient);
    canvas.drawPath(
      face,
      Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 4,
    );
    canvas.drawPath(
      _face(_radius - 6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    if (earned) {
      canvas.save();
      canvas.translate(41, 36);
      canvas.rotate(-math.pi / 6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 10),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
      canvas.restore();
    }

    final band = shine;
    if (earned && band != null) {
      final along = band * (_radius + 14);
      canvas.save();
      canvas.clipPath(face);
      canvas.drawRect(
        Rect.fromCircle(center: _center, radius: _radius + 4),
        Paint()
          ..shader =
              LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.4, 0.5, 0.6],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(
                Rect.fromCircle(
                  center: _center + Offset(along, along),
                  radius: _radius + 4,
                ),
              ),
      );
      canvas.restore();
    }

    if (level == 3) {
      final gem = Path()
        ..moveTo(50, 2)
        ..lineTo(57, 10)
        ..lineTo(50, 18)
        ..lineTo(43, 10)
        ..close();
      canvas.drawPath(
        gem,
        Paint()..color = earned ? Colors.white : _lockedTrim,
      );
      canvas.drawPath(
        gem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = dark,
      );
    }
    canvas.restore();
  }

  Path _polygon(
    int sides,
    double rotation,
    double radius, [
    double Function(int)? scale,
  ]) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = rotation + i * 2 * math.pi / sides;
      final r = radius * (scale?.call(i) ?? 1);
      final point = _center + Offset(math.cos(angle), math.sin(angle)) * r;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _face(double r) {
    switch (shape) {
      case MedalShape.circle:
        return Path()..addOval(Rect.fromCircle(center: _center, radius: r));
      case MedalShape.shield:
        // Drawn for a radius of 26, then scaled.
        final k = r / 26;
        Offset p(double x, double y) =>
            _center + Offset((x - 50) * k, (y - 50) * k);
        final a = p(50, 24), b = p(74, 32), c = p(74, 52), d = p(74, 70);
        final e = p(50, 78), f = p(26, 70), g = p(26, 52), h = p(26, 32);
        return Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..quadraticBezierTo(d.dx, d.dy, e.dx, e.dy)
          ..quadraticBezierTo(f.dx, f.dy, g.dx, g.dy)
          ..lineTo(h.dx, h.dy)
          ..close();
      case MedalShape.diamond:
        return _polygon(4, -math.pi / 2, r * 1.1);
      case MedalShape.hexagon:
        return _polygon(6, -math.pi / 2, r);
      case MedalShape.octagon:
        return _polygon(8, math.pi / 8, r);
      case MedalShape.pentagon:
        return _polygon(5, -math.pi / 2, r * 1.04);
      case MedalShape.starburst:
        return _polygon(20, -math.pi / 2, r, (i) => i.isEven ? 1.04 : 0.86);
      case MedalShape.scallop:
        return _polygon(
          80,
          -math.pi / 2,
          r,
          (i) => 0.95 + 0.07 * math.cos(i * 2 * math.pi * 10 / 80),
        );
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.shape != shape ||
      old.tier != tier ||
      old.earned != earned ||
      old.shine != shine;
}

// The latest badges on a profile, with "See all". On someone else's profile
// it's hidden until they have one.
class BadgesSection extends StatefulWidget {
  const BadgesSection({
    super.key,
    required this.userId,
    required this.isMine,
    this.name,
    this.gender,
    this.frame,
    this.model,
  });

  final String userId;
  final bool isMine;

  // Someone else's name and gender, for "Shahad attended ...".
  final String? name;
  final String? gender;

  // Wraps the row in another card, e.g. the profile's own sections.
  final Widget Function(String title, Widget child)? frame;

  // Injectable for tests.
  final BadgesModel? model;

  // Bumped after the new badge popup, so open sections reload.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  @override
  State<BadgesSection> createState() => _BadgesSectionState();
}

class _BadgesSectionState extends State<BadgesSection> {
  static const int _previewCount = 4;

  List<EarnedBadge>? _earned;

  // The viewer's own badges, to hide secret ones they haven't earned.
  Set<String> _mine = const {};

  BadgesModel get _model => widget.model ?? BadgesModel();

  @override
  void initState() {
    super.initState();
    BadgesSection.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    BadgesSection.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final earned = widget.isMine
          ? (await _model.fetchMine()).earned
          : await _model.fetchFor(widget.userId);
      if (mounted) setState(() => _earned = earned);
    } catch (_) {
      // The section stays hidden when badges cannot be loaded.
    }
    if (widget.isMine) return;
    try {
      final mine = await _model.fetchMine();
      if (mounted) {
        setState(() => _mine = {for (final b in mine.earned) b.id});
      }
    } catch (_) {
      // Secret badges stay hidden.
    }
  }

  void _openAll() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BadgesView(
          userId: widget.isMine ? null : widget.userId,
          earned: widget.isMine ? null : _earned,
          name: widget.name,
          gender: widget.gender,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final earned = _earned;
    if (earned == null || (earned.isEmpty && !widget.isMine)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final total = kBadges.length;
    final normalCount = earned
        .where((b) => !b.id.startsWith(kCategoryFanPrefix))
        .length;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (earned.isEmpty)
          Text(
            l.badgesNoneYet,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: SynkColors.textSecondary,
            ),
          )
        else
          Row(
            children: [
              for (final badge in earned.take(_previewCount))
                Expanded(
                  child: _BadgeTile(
                    badge: badgeInfo(badge.id)!,
                    id: badge.id,
                    earnedAt: badge.earnedAt,
                    isMine: widget.isMine,
                    ownerName: widget.name,
                    ownerGender: widget.gender,
                    concealed: !widget.isMine && !_mine.contains(badge.id),
                    size: 64,
                  ),
                ),
              for (var i = earned.length; i < _previewCount; i++)
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (widget.isMine)
              Text(
                l.badgesEarnedCount(normalCount, total),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textSecondary,
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: _openAll,
              style: TextButton.styleFrom(
                foregroundColor: SynkColors.orangeDark,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                l.seeAll,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: (widget.frame ?? _foldCard)(l.badgesTitle, content),
    );
  }

  static Widget _foldCard(String title, Widget child) =>
      FoldCard(title: title, child: child);
}

// A badge with its name under it; tap for the rule.
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.id,
    this.earnedAt,
    this.progress = 0,
    this.current,
    this.sealed = false,
    this.isMine = true,
    this.ownerName,
    this.ownerGender,
    this.concealed = false,
    this.size = 76,
  });

  final BadgeInfo badge;
  final String id;
  final DateTime? earnedAt;
  final double progress;
  final int? current;
  final bool sealed;
  // Off on someone else's badges: no share or replay.
  final bool isMine;
  final String? ownerName;
  final String? ownerGender;
  final bool concealed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final earned = earnedAt != null;
    final hidden = badge.isSecret && (!earned || concealed);
    final l = context.l10n;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showBadgeDetails(
        context,
        badge: badge,
        id: id,
        earnedAt: earnedAt,
        current: current,
        isMine: isMine,
        ownerName: ownerName,
        ownerGender: ownerGender,
        concealed: concealed,
      ),
      // Hold one of your own earned badges to play its celebration again.
      onLongPress: earned && isMine
          ? () => showBadgeCelebration(context, [
              EarnedBadge(id: id, earnedAt: earnedAt!),
            ])
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          children: [
            BadgeIcon(
              badge: badge,
              earned: earned,
              sealed: sealed,
              concealed: concealed,
              size: size,
            ),
            const SizedBox(height: 6),
            Text(
              hidden ? l.badgeSecretName : badgeName(l, id),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: earned
                    ? SynkColors.textPrimary
                    : SynkColors.textSecondary,
              ),
            ),
            if (!earned && !sealed && progress > 0) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1).toDouble(),
                    minHeight: 4,
                    color: SynkColors.orangeDark,
                    backgroundColor: SynkColors.backgroundDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.children, this.columns = 3});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / columns;
        return Wrap(
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

// One tile for the full list.
Widget badgeTile({
  required BadgeInfo badge,
  required String id,
  DateTime? earnedAt,
  int? current,
  bool sealed = false,
  bool isMine = true,
  String? ownerName,
  String? ownerGender,
  bool concealed = false,
}) {
  final progress = earnedAt == null && current != null && badge.goal > 1
      ? current / badge.goal
      : 0.0;
  return _BadgeTile(
    badge: badge,
    id: id,
    earnedAt: earnedAt,
    progress: progress,
    current: earnedAt == null && badge.goal > 1 ? current : null,
    sealed: sealed,
    isMine: isMine,
    ownerName: ownerName,
    ownerGender: ownerGender,
    concealed: concealed,
  );
}

Future<void> showBadgeDetails(
  BuildContext context, {
  required BadgeInfo badge,
  required String id,
  DateTime? earnedAt,
  int? current,
  bool isMine = true,
  String? ownerName,
  String? ownerGender,
  bool concealed = false,
}) {
  final l = context.l10n;
  final earned = earnedAt != null;
  final hidden = badge.isSecret && (!earned || concealed);
  final firstName = ownerName?.trim().split(RegExp(r'\s+')).first ?? '';
  final rule = hidden
      ? l.badgeSecretRule
      : !isMine && firstName.isNotEmpty
      ? badgeRuleBy(l, id, firstName, ownerGender)
      : badgeRule(l, id);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SheetFrame(
      children: [
        BadgeIcon(
          badge: badge,
          earned: earned,
          concealed: concealed,
          size: 124,
        ),
        const SizedBox(height: 14),
        Text(
          badgeGroupLabel(l, badge.group),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: SynkColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hidden ? l.badgeSecretName : badgeName(l, id),
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: SynkColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rule,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: SynkColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (earned)
          Text(
            l.badgeEarnedOn(
              DateFormat.yMMMd(l.localeName).format(earnedAt.toLocal()),
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SynkColors.tealText,
            ),
          )
        else if (current != null)
          Text(
            '${current.clamp(0, badge.goal)} / ${badge.goal}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SynkColors.orangeDeep,
            ),
          ),
        if (earned && isMine) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (buttonContext) => _sheetButton(
                icon: Icons.ios_share_rounded,
                label: l.badgeShare,
                onPressed: () =>
                    shareBadge(buttonContext, id: id, earnedAt: earnedAt),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _sheetButton({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    height: 52,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: SynkColors.orangeDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

// "You earned ..." for badges the user hasn't seen yet.
Future<void> showNewBadgesSheet(
  BuildContext context,
  List<EarnedBadge> badges,
) {
  final l = context.l10n;
  final first = badges.first;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SheetFrame(
      children: [
        Text(
          badges.length == 1 ? l.badgeNewTitle : l.badgesNewTitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: SynkColors.orangeDeep,
          ),
        ),
        const SizedBox(height: 18),
        if (badges.length == 1) ...[
          BadgeIcon(badge: badgeInfo(first.id)!, earned: true, size: 124),
          const SizedBox(height: 16),
          Text(
            badgeName(l, first.id),
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: SynkColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badgeRule(l, first.id),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: SynkColors.textSecondary,
            ),
          ),
        ] else
          BadgeGrid(
            children: [
              for (final badge in badges.take(8))
                _BadgeTile(
                  badge: badgeInfo(badge.id)!,
                  id: badge.id,
                  earnedAt: badge.earnedAt,
                ),
            ],
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: SynkColors.orangeDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              l.badgeNewAction,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const BadgesView()));
          },
          style: TextButton.styleFrom(
            foregroundColor: SynkColors.textSecondary,
          ),
          child: Text(
            l.badgesSeeAllMine,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SynkColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
  }
}
