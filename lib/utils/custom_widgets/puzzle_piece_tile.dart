import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

/// Visual state of the puzzle piece inside the tile.
///
/// missing   – dashed outline, gently drifting (Forgot Password / Link expired)
/// sending   – outline traces itself in orange while a request is running
/// sent      – solid piece (Check your inbox)
/// almost    – solid piece hovering above a socket; [PuzzlePieceTile.fit]
///             levels it out as the form becomes valid (New Password)
/// connected – piece dropped into the socket, with a teal ripple (Success)
enum PieceState { missing, sending, sent, almost, connected }

class PuzzlePieceTile extends StatefulWidget {
  const PuzzlePieceTile({
    super.key,
    required this.state,
    this.size = 72,
    this.fit = 0.0,
    this.badgeIcon,
    this.badgeColor = SynkColors.teal,
  });

  final PieceState state;

  /// Side length of the white tile.
  final double size;

  /// 0.0 → piece tilted 12°, 1.0 → level. Only used by [PieceState.almost].
  final double fit;

  /// Optional small circular badge at the top-right corner.
  final IconData? badgeIcon;
  final Color badgeColor;

  @override
  State<PuzzlePieceTile> createState() => _PuzzlePieceTileState();
}

class _PuzzlePieceTileState extends State<PuzzlePieceTile>
    with TickerProviderStateMixin {
  // Repeating motion: float (missing) or trace (sending).
  late final AnimationController _loop;

  // One-shot motion: badge pop (sent) or drop + ripple (connected).
  late final AnimationController _once;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this);
    _once = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncAnimations(previous: null);
  }

  @override
  void didUpdateWidget(PuzzlePieceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.badgeIcon != widget.badgeIcon) {
      _syncAnimations(previous: oldWidget.state);
    }
  }

  void _syncAnimations({required PieceState? previous}) {
    _loop.stop();

    switch (widget.state) {
      case PieceState.missing:
        _loop.duration = const Duration(seconds: 3);
        if (!_reduceMotion) _loop.repeat(reverse: true);
        break;
      case PieceState.sending:
        _loop.duration = const Duration(milliseconds: 1100);
        if (!_reduceMotion) _loop.repeat();
        break;
      case PieceState.sent:
      case PieceState.almost:
      case PieceState.connected:
        break;
    }

    // Pop the badge / drop the piece when entering sent or connected.
    final entersOneShot =
        (widget.state == PieceState.sent && previous != PieceState.sent) ||
        (widget.state == PieceState.connected &&
            previous != PieceState.connected);

    if (entersOneShot) {
      _reduceMotion ? _once.value = 1.0 : _once.forward(from: 0.0);
    } else if (_once.value == 0.0 && widget.badgeIcon != null) {
      _once.value = 1.0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _once.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final pieceSize = size * 0.72;
    final radius = size >= 90 ? 28.0 : 22.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Tile
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),

          // Ripple (connected only)
          if (widget.state == PieceState.connected)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _once,
                builder: (context, _) => CustomPaint(
                  painter: _RipplePainter(progress: _once.value),
                ),
              ),
            ),

          // Piece
          _buildPiece(pieceSize),

          // Badge
          if (widget.badgeIcon != null)
            Positioned(
              top: -6,
              right: -6,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _once, curve: Curves.easeOutBack),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(widget.badgeIcon, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPiece(double pieceSize) {
    final lift = pieceSize * 0.26;

    switch (widget.state) {
      case PieceState.missing:
        return AnimatedBuilder(
          animation: _loop,
          builder: (context, child) {
            final dy = _reduceMotion ? 0.0 : -3.0 + (_loop.value * 6.0);
            return Transform.translate(
              offset: Offset(0, dy),
              child: Transform.rotate(angle: -8 * math.pi / 180, child: child),
            );
          },
          child: _piece(pieceSize, _PieceStyle.dashed),
        );

      case PieceState.sending:
        return AnimatedBuilder(
          animation: _loop,
          builder: (context, _) => _piece(
            pieceSize,
            _PieceStyle.trace,
            progress: _reduceMotion ? 1.0 : _loop.value,
          ),
        );

      case PieceState.sent:
        return _piece(pieceSize, _PieceStyle.solid);

      case PieceState.almost:
        return SizedBox(
          width: pieceSize,
          height: pieceSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, lift),
                child: _piece(pieceSize, _PieceStyle.socket),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(end: widget.fit.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, fit, child) => Transform.translate(
                  offset: Offset(0, -lift),
                  child: Transform.rotate(
                    angle: (1 - fit) * 12 * math.pi / 180,
                    child: child,
                  ),
                ),
                child: _piece(pieceSize, _PieceStyle.solid),
              ),
            ],
          ),
        );

      case PieceState.connected:
        return SizedBox(
          width: pieceSize,
          height: pieceSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _piece(pieceSize, _PieceStyle.socket),
              AnimatedBuilder(
                animation: _once,
                builder: (context, child) {
                  final t = Curves.easeOutBack.transform(_once.value);
                  return Transform.translate(
                    offset: Offset(0, -lift * (1 - t)),
                    child: child,
                  );
                },
                child: _piece(pieceSize, _PieceStyle.solid),
              ),
            ],
          ),
        );
    }
  }

  Widget _piece(double size, _PieceStyle style, {double progress = 1.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PuzzlePiecePainter(style: style, progress: progress),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Painters
// -----------------------------------------------------------------------------

enum _PieceStyle { dashed, trace, solid, socket }

class _PuzzlePiecePainter extends CustomPainter {
  _PuzzlePiecePainter({required this.style, required this.progress});

  final _PieceStyle style;
  final double progress;

  // Piece outline in a 100×100 box: knobs on top and right, sockets on
  // bottom and left. Same path as the design mockups.
  static Path _piecePath() {
    return Path()
      ..moveTo(20, 20)
      ..lineTo(42, 20)
      ..cubicTo(42, 12, 46, 8, 50, 8)
      ..cubicTo(54, 8, 58, 12, 58, 20)
      ..lineTo(80, 20)
      ..lineTo(80, 42)
      ..cubicTo(88, 42, 92, 46, 92, 50)
      ..cubicTo(92, 54, 88, 58, 80, 58)
      ..lineTo(80, 80)
      ..lineTo(58, 80)
      ..cubicTo(58, 72, 54, 68, 50, 68)
      ..cubicTo(46, 68, 42, 72, 42, 80)
      ..lineTo(20, 80)
      ..lineTo(20, 58)
      ..cubicTo(28, 58, 32, 54, 32, 50)
      ..cubicTo(32, 46, 28, 42, 20, 42)
      ..close();
  }

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        out.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dash + gap;
      }
    }
    return out;
  }

  static Path _partial(Path source, double fraction) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      out.addPath(
        metric.extractPath(0, metric.length * fraction.clamp(0.0, 1.0)),
        Offset.zero,
      );
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, scale);

    final path = _piecePath();

    switch (style) {
      case _PieceStyle.dashed:
        canvas.drawPath(
          _dashed(path, 9, 7),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = SynkColors.textSecondary,
        );
        break;

      case _PieceStyle.trace:
        canvas.drawPath(
          _dashed(path, 9, 7),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = SynkColors.textSecondary.withValues(alpha: 0.35),
        );
        canvas.drawPath(
          _partial(path, progress),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = SynkColors.orangeDark,
        );
        break;

      case _PieceStyle.socket:
        canvas.drawPath(
          path,
          Paint()..color = SynkColors.textPrimary.withValues(alpha: 0.06),
        );
        canvas.drawPath(
          _dashed(path, 7, 6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = SynkColors.textSecondary.withValues(alpha: 0.45),
        );
        break;

      case _PieceStyle.solid:
        canvas.drawPath(
          path,
          Paint()
            ..shader = const LinearGradient(
              colors: [SynkColors.orange, SynkColors.orangeDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
        );
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PuzzlePiecePainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.progress != progress;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final radius = size.width * (0.5 + 0.45 * progress);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = SynkColors.teal.withValues(alpha: (1 - progress) * 0.7),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}