import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/constants/badges.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/badges_model.dart';
import '../../../utils/share_badge.dart';
import '../badges_view.dart';
import 'badge_widgets.dart';

// New badges: the full screen celebration when one of them is platinum or
// secret, otherwise the simple sheet.
Future<void> showNewBadges(BuildContext context, List<EarnedBadge> badges) {
  final big = badges.any((b) => _tierStrength(badgeInfo(b.id)!.tier) == 3);
  return big
      ? showBadgeCelebration(context, badges)
      : showNewBadgesSheet(context, badges);
}

// Full screen "you earned it" for badges. The best one gets the show;
// the rest sit in a row under it. Light gathers, the medal bursts in with
// confetti, a sound and a buzz, then it tilts with the phone.
//
// The confetti and sparks are drawn here for now. A Rive file can take their
// place later without changing the flow.
Future<void> showBadgeCelebration(
  BuildContext context,
  List<EarnedBadge> badges,
) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _Celebration(badges: badges),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

// 0 for bronze and category badges up to 3 for platinum and secret.
int _tierStrength(BadgeTier tier) => switch (tier) {
  BadgeTier.bronze || BadgeTier.fan => 0,
  BadgeTier.silver => 1,
  BadgeTier.gold => 2,
  BadgeTier.platinum || BadgeTier.secret => 3,
};

// The glow color. Secret badges are dark, so they glow lavender.
Color badgeGlow(BadgeTier tier) =>
    tier == BadgeTier.secret ? const Color(0xFFB9A3F0) : tier.light;

class _Celebration extends StatefulWidget {
  const _Celebration({required this.badges});

  final List<EarnedBadge> badges;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  // Seconds after the burst before the buttons show; tapping skips to here.
  static const double _settled = 0.9;

  late final EarnedBadge _main;
  late final List<EarnedBadge> _others;
  late final BadgeInfo _info;
  late final int _strength;
  late final double _charge;
  late final List<_Piece> _confetti;
  late final List<_Spark> _sparks;
  late final Ticker _ticker;

  final ValueNotifier<double> _time = ValueNotifier(0);
  double _skipped = 0;
  bool _burst = false;
  bool _reduceMotion = false;
  double _lastTick = 0;

  AudioPlayer? _player;
  StreamSubscription<AccelerometerEvent>? _motion;
  Offset? _restingTilt;
  Offset _phoneTilt = Offset.zero;
  Offset _dragTilt = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _main = widget.badges.reduce(
      (best, b) =>
          _tierStrength(badgeInfo(b.id)!.tier) >
              _tierStrength(badgeInfo(best.id)!.tier)
          ? b
          : best,
    );
    _others = [
      for (final b in widget.badges)
        if (b != _main) b,
    ];
    _info = badgeInfo(_main.id)!;
    _strength = _tierStrength(_info.tier);
    _charge = const [0.45, 0.6, 0.75, 1.1][_strength];
    final random = math.Random(_main.id.hashCode);
    final colors = [
      badgeGlow(_info.tier),
      _info.tier.dark,
      SynkColors.pink,
      SynkColors.orange,
      SynkColors.teal,
      Colors.white,
    ];
    _confetti = [
      for (var i = 0; i < const [40, 60, 90, 130][_strength]; i++)
        _Piece.random(random, colors, power: 0.85 + _strength * 0.1),
      // A second, smaller burst for gold and up.
      if (_strength >= 2)
        for (var i = 0; i < 40; i++)
          _Piece.random(random, colors, power: 0.7, delay: 0.35),
    ];
    _sparks = [
      if (_strength >= 3)
        for (var i = 0; i < 10; i++) _Spark.random(random),
    ];
    _ticker = createTicker(_onTick)..start();
    unawaited(_prepareSound());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && !_reduceMotion) {
      _reduceMotion = true;
      // Everything already in place, nothing flying.
      _skipped = _charge + 4;
      unawaited(_motion?.cancel());
      _motion = null;
    } else if (!reduce && _motion == null) {
      _listenToTilt();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    unawaited(_motion?.cancel());
    final player = _player;
    if (player != null) {
      unawaited(
        player.dispose().whenComplete(() async {
          // Back to what voice messages use.
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music());
        }),
      );
    }
    super.dispose();
  }

  // A short chime that mixes with music and stays quiet on silent.
  Future<void> _prepareSound() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.assistanceSonification,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
        ),
      );
      if (!mounted) return;
      final player = AudioPlayer();
      _player = player;
      await player.setAsset('assets/sounds/badge_earned.wav');
      await player.setVolume(_strength == 0 ? 0.6 : 1);
    } catch (_) {
      // No sound is fine.
    }
  }

  void _listenToTilt() {
    try {
      _motion =
          accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
              .listen((event) {
                final reading = Offset(event.x, event.z);
                final rest = _restingTilt ??= reading;
                final target = Offset(
                  ((rest.dx - reading.dx) / 4).clamp(-1.0, 1.0),
                  ((reading.dy - rest.dy) / 4).clamp(-1.0, 1.0),
                );
                _phoneTilt = Offset.lerp(_phoneTilt, target, 0.2)!;
              }, onError: (_) {});
    } catch (_) {
      // No sensor, the medal sways on its own.
    }
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6 + _skipped;
    if (!_dragging) _dragTilt *= 0.9;
    if (_info.isSecret && !_burst) {
      // The "?" medal rattles as it builds.
      if ((t / 0.09).floor() != (_lastTick / 0.09).floor()) {
        HapticFeedback.selectionClick();
      }
    }
    _lastTick = t;
    if (!_burst && t >= _charge) _fireBurst();
    _time.value = t;
  }

  void _fireBurst() {
    _burst = true;
    unawaited(_playSound());
    HapticFeedback.heavyImpact();
    final steps = <(int, Future<void> Function())>[
      if (_strength >= 1) (110, HapticFeedback.mediumImpact),
      if (_strength >= 2) (220, HapticFeedback.lightImpact),
      if (_strength >= 2) (350, HapticFeedback.mediumImpact),
      if (_strength >= 3) (520, HapticFeedback.heavyImpact),
    ];
    for (final (ms, buzz) in steps) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted && !_reduceMotion) buzz();
      });
    }
  }

  Future<void> _playSound() async {
    try {
      await _player?.play();
    } catch (_) {}
  }

  void _skip() {
    final t = _time.value;
    if (t >= _charge + _settled) return;
    _skipped += _charge + _settled - t;
  }

  void _seeAll() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => const BadgesView()));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final medalSize = math.min(200.0, size.height * 0.25);
              final center = Offset(size.width / 2, size.height * 0.31);
              return ValueListenableBuilder<double>(
                valueListenable: _time,
                builder: (context, t, _) {
                  final since = t - _charge;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BackdropPainter(
                            t: t,
                            charge: _charge,
                            center: center,
                            accent: badgeGlow(_info.tier),
                            strength: _strength,
                          ),
                        ),
                      ),
                      _medal(t, since, center, medalSize),
                      Positioned(
                        left: 24,
                        right: 24,
                        top: center.dy + medalSize / 2 + 34,
                        child: _details(l, since),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: padding.bottom + 12,
                        child: _buttons(l, since),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ConfettiPainter(
                              since: since,
                              center: center,
                              pieces: _confetti,
                              sparks: _sparks,
                              sparkRadius: medalSize * 0.75,
                            ),
                          ),
                        ),
                      ),
                      // The flash at the burst.
                      if (since >= 0 && since < 0.3)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: Colors.white.withValues(
                                alpha: 0.7 * (1 - since / 0.3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _medal(double t, double since, Offset center, double size) {
    double scale;
    if (since < 0) {
      scale = _info.isSecret ? 0.7 : 0;
    } else {
      // A spring that overshoots and settles.
      final from = _info.isSecret ? 0.7 : 0.0;
      final spring = 1 - math.exp(-6 * since) * math.cos(14 * since);
      scale = from + (1 - from) * spring;
    }
    if (scale <= 0) return const SizedBox.shrink();

    // Phone tilt and finger drag, with a slow sway when neither moves it.
    final moved = (_phoneTilt.distance + _dragTilt.distance).clamp(0.0, 1.0);
    final sway = _reduceMotion
        ? Offset.zero
        : Offset(math.sin(t * 1.3) * 0.18, math.sin(t * 0.9) * 0.08) *
              (1 - moved);
    final tilt = _phoneTilt + _dragTilt + sway;

    // A band of light sweeps over once, then follows the tilt.
    final double? shine;
    if (since < 0) {
      shine = null;
    } else if (since < 0.8) {
      shine = -1.4 + since / 0.8 * 2.8;
    } else {
      shine = ((tilt.dx + tilt.dy) * 0.9).clamp(-1.2, 1.2);
    }

    var shake = Offset.zero;
    if (_info.isSecret && since < 0) {
      final build = (t / _charge).clamp(0.0, 1.0);
      shake = Offset(
        math.sin(t * 70) * 7 * build,
        math.cos(t * 55) * 3 * build,
      );
    }

    final medal = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateX(-tilt.dy * 0.5)
        ..rotateY(tilt.dx * 0.6),
      child: BadgeIcon(
        badge: _info,
        earned: since >= 0,
        size: size,
        shine: shine,
      ),
    );

    return Positioned(
      left: center.dx - size / 2 + shake.dx,
      top: center.dy - size / 2 + shake.dy,
      width: size,
      height: size,
      child: GestureDetector(
        onPanStart: (_) => _dragging = true,
        onPanUpdate: (d) {
          _dragTilt = Offset(
            (_dragTilt.dx + d.delta.dx / 120).clamp(-1.0, 1.0),
            (_dragTilt.dy + d.delta.dy / 120).clamp(-1.0, 1.0),
          );
        },
        onPanEnd: (_) => _dragging = false,
        onPanCancel: () => _dragging = false,
        child: Transform.scale(scale: scale, child: medal),
      ),
    );
  }

  // Fades and slides up [delay] seconds after the burst.
  Widget _reveal(double since, double delay, Widget child) {
    final p = Curves.easeOutCubic.transform(
      ((since - delay) / 0.35).clamp(0.0, 1.0),
    );
    if (p <= 0) return Opacity(opacity: 0, child: child);
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, 16 * (1 - p)), child: child),
    );
  }

  Widget _details(AppLocalizations l, double since) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _reveal(
          since,
          0.25,
          Text(
            badgeGroupLabel(l, _info.group),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: badgeGlow(_info.tier),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _reveal(
          since,
          0.35,
          Text(
            badgeName(l, _main.id),
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _reveal(
          since,
          0.45,
          Text(
            badgeRule(l, _main.id),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
        if (_others.isNotEmpty) ...[
          const SizedBox(height: 18),
          _reveal(
            since,
            0.55,
            Text(
              l.badgesAlsoEarned,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < math.min(_others.length, 6); i++)
                _popIn(
                  since - 0.6 - i * 0.08,
                  BadgeIcon(
                    badge: badgeInfo(_others[i].id)!,
                    earned: true,
                    size: 44,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _popIn(double since, Widget child) {
    final scale = since <= 0
        ? 0.0
        : 1 - math.exp(-8 * since) * math.cos(16 * since);
    return Transform.scale(scale: scale, child: child);
  }

  Widget _whiteButton({
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
          backgroundColor: Colors.white,
          foregroundColor: SynkColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buttons(AppLocalizations l, double since) {
    final ready = since >= _settled - 0.1;
    return IgnorePointer(
      ignoring: !ready,
      child: _reveal(
        since,
        _settled - 0.1,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: Builder(
                builder: (buttonContext) => _whiteButton(
                  icon: Icons.ios_share_rounded,
                  label: l.badgeShare,
                  onPressed: () => shareBadge(
                    buttonContext,
                    id: _main.id,
                    earnedAt: _main.earnedAt,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  l.badgeNewAction,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _seeAll,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.7),
              ),
              child: Text(
                l.badgesSeeAllMine,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The dark screen, the Synk colors glowing in, light gathering into the
// middle, then rays and rings once the medal bursts.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({
    required this.t,
    required this.charge,
    required this.center,
    required this.accent,
    required this.strength,
  });

  final double t;
  final double charge;
  final Offset center;
  final Color accent;
  final int strength;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Curves.easeOut.transform((t / 0.3).clamp(0.0, 1.0));
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()..color = const Color(0xFF15121B).withValues(alpha: 0.93 * dim),
    );

    // Synk pink from the top, teal from the bottom.
    final corner = size.longestSide * 0.7;
    canvas.drawRect(
      full,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                SynkColors.pink.withValues(alpha: 0.28 * dim),
                SynkColors.pink.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.1, 0),
                radius: corner,
              ),
            ),
    );
    canvas.drawRect(
      full,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                SynkColors.teal.withValues(alpha: 0.24 * dim),
                SynkColors.teal.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.9, size.height),
                radius: corner,
              ),
            ),
    );

    final since = t - charge;
    final build = (t / charge).clamp(0.0, 1.0);

    // The glow behind the medal.
    final glow = since < 0
        ? build * build * 0.7
        : 0.75 + 0.06 * math.sin(since * 2.2);
    final glowRadius = since < 0 ? 60 + build * 120 : 220.0;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.6 * glow),
            accent.withValues(alpha: 0.15 * glow),
            accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    if (since < 0) {
      // Light pulled into the middle.
      final count = 18 + strength * 6;
      for (var i = 0; i < count; i++) {
        final seed = i * 2.399963;
        final start = 140 + (i * 37 % 120);
        final phase = ((build + (i % 5) * 0.11) % 1.0);
        final r = start * (1 - Curves.easeIn.transform(phase));
        final angle = seed + t * 0.6;
        final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
        canvas.drawCircle(
          p,
          1.5 + 2 * phase,
          Paint()..color = Colors.white.withValues(alpha: 0.8 * phase * build),
        );
      }
      canvas.drawCircle(
        center,
        4 + build * 18,
        Paint()
          ..color = Colors.white.withValues(alpha: build)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      return;
    }

    // Slowly turning rays.
    final raysIn = Curves.easeOut.transform((since / 0.5).clamp(0.0, 1.0));
    final reach = size.longestSide;
    final rayAlpha = (strength == 0 ? 0.07 : 0.12) * raysIn;
    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: rayAlpha),
          accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: reach * 0.6));
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays + since * 0.25;
      const half = math.pi / rays / 2.2;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + math.cos(a - half) * reach,
            center.dy + math.sin(a - half) * reach,
          )
          ..lineTo(
            center.dx + math.cos(a + half) * reach,
            center.dy + math.sin(a + half) * reach,
          )
          ..close(),
        rayPaint,
      );
    }

    // Rings rushing out from the burst.
    for (final delay in [0.0, if (strength >= 2) 0.14]) {
      final p = ((since - delay) / 0.6).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        center,
        40 + Curves.easeOutCubic.transform(p) * 260,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - p)
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t;
}

// One bit of confetti. Its path is worked out from the time alone: thrown
// out, slowed by the air, falling, and fluttering side to side.
class _Piece {
  _Piece({
    required this.color,
    required this.round,
    required this.width,
    required this.height,
    required this.drag,
    required this.spin,
    required this.flip,
    required this.flutter,
    required this.phase,
    required this.life,
    required this.delay,
    required this.velocity,
  });

  factory _Piece.random(
    math.Random r,
    List<Color> colors, {
    double power = 1,
    double delay = 0,
  }) {
    // Mostly up and out.
    final angle = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.7;
    final speed = (420 + r.nextDouble() * 680) * power;
    return _Piece(
      color: colors[r.nextInt(colors.length)],
      round: r.nextDouble() < 0.3,
      width: 6 + r.nextDouble() * 6,
      height: 3 + r.nextDouble() * 3,
      drag: 1.6 + r.nextDouble() * 0.8,
      spin: (r.nextDouble() - 0.5) * 12,
      flip: 4 + r.nextDouble() * 8,
      flutter: 6 + r.nextDouble() * 14,
      phase: r.nextDouble() * math.pi * 2,
      life: 2.8 + r.nextDouble() * 1.2,
      delay: delay,
      velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
    );
  }

  final Color color;
  final bool round;
  final double width;
  final double height;
  final double drag;
  final double spin;
  final double flip;
  final double flutter;
  final double phase;
  final double life;
  final double delay;
  final Offset velocity;

  static const double _gravity = 620;
}

// A twinkle that stays around platinum and secret medals.
class _Spark {
  _Spark.random(math.Random r)
    : angle = r.nextDouble() * math.pi * 2,
      distance = 0.8 + r.nextDouble() * 0.5,
      size = 4 + r.nextDouble() * 5,
      speed = 2 + r.nextDouble() * 2,
      phase = r.nextDouble() * math.pi * 2;

  final double angle;
  final double distance;
  final double size;
  final double speed;
  final double phase;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.since,
    required this.center,
    required this.pieces,
    required this.sparks,
    required this.sparkRadius,
  });

  final double since;
  final Offset center;
  final List<_Piece> pieces;
  final List<_Spark> sparks;
  final double sparkRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (since < 0) return;
    final paint = Paint();
    for (final piece in pieces) {
      final t = since - piece.delay;
      if (t <= 0 || t >= piece.life) continue;
      final k = piece.drag;
      final slow = (1 - math.exp(-k * t)) / k;
      final fall = _Piece._gravity / k * (t - slow);
      final sway =
          math.sin(piece.phase + t * 5) * piece.flutter * math.min(1, t);
      final p =
          center +
          Offset(
            piece.velocity.dx * slow + sway,
            piece.velocity.dy * slow + fall,
          );
      if (p.dy > size.height + 20) continue;
      final fade = ((piece.life - t) / 0.6).clamp(0.0, 1.0);
      paint.color = piece.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(piece.spin * t);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.height * 0.8, paint);
      } else {
        // Turning over in the air.
        canvas.scale(1, math.cos(piece.flip * t + piece.phase).abs() + 0.15);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.width,
              height: piece.height,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }

    final sparksIn = ((since - 0.4) / 0.5).clamp(0.0, 1.0);
    for (final spark in sparks) {
      final twinkle = math.pow(
        math.max(0, math.sin(since * spark.speed + spark.phase)),
        3,
      );
      final alpha = sparksIn * twinkle;
      if (alpha <= 0.01) continue;
      final p =
          center +
          Offset(math.cos(spark.angle), math.sin(spark.angle)) *
              sparkRadius *
              spark.distance;
      _star(canvas, p, spark.size * (0.6 + 0.4 * twinkle), alpha.toDouble());
    }
  }

  void _star(Canvas canvas, Offset p, double r, double alpha) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.since != since;
}
