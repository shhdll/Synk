import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activity_model.dart';
import 'activity_thumbnail.dart';

// Surprise Me's puzzle.
//
// Before a shuffle, nine pieces float loosely, each cut from a different
// activity's photo ([pieces]). Each new [playToken] plays the shuffle: the
// pieces mix and spin, then fly into a 3 x 3 board that makes up [chosen]'s
// photo, one piece at a time. The middle piece lands last, into a gap
// marked "?", and the finished picture glows. [onDone] runs a moment after.
class SurprisePuzzle extends StatefulWidget {
  const SurprisePuzzle({
    super.key,
    required this.pieces,
    required this.playToken,
    this.chosen,
    this.onDone,
    this.size = 300,
  });

  // Activities on the loose pieces; repeated, or left plain, when fewer
  // than nine.
  final List<Activity> pieces;
  final Activity? chosen;
  final int playToken;
  final VoidCallback? onDone;
  final double size;

  // How long one shuffle takes, including a pause on the finished picture.
  static const duration = Duration(milliseconds: 5600);

  @override
  State<SurprisePuzzle> createState() => _SurprisePuzzleState();
}

class _SurprisePuzzleState extends State<SurprisePuzzle>
    with TickerProviderStateMixin {
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: SurprisePuzzle.duration,
  )..addListener(_onTick);

  // The loose pieces bobbing while they wait.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  // Where the loose pieces wait, and where they fly while mixing.
  final List<_Pose> _loose = _randomPoses(math.Random(7), spin: 0.5);
  List<_Pose> _mixed = const [];
  final Set<int> _landed = {};

  // Activity photos, decoded for the painter, by URL.
  final Map<String, ui.Image> _photos = {};
  final Set<String> _loading = {};

  // A loose 3 x 3 spread, each piece nudged off its spot so they don't pile
  // up, in a random order.
  static List<_Pose> _randomPoses(math.Random random, {required double spin}) {
    return [
      for (var i = 0; i < _pieceCount; i++)
        _Pose(
          Offset(
            0.2 + (i % 3) * 0.3 + (random.nextDouble() - 0.5) * 0.14,
            0.2 + (i ~/ 3) * 0.3 + (random.nextDouble() - 0.5) * 0.14,
          ),
          (random.nextDouble() - 0.5) * 2 * spin,
        ),
    ]..shuffle(random);
  }

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    // "Shuffle again" builds a new puzzle with a token already set.
    if (widget.playToken > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void didUpdateWidget(SurprisePuzzle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPhotos();
    if (widget.playToken != oldWidget.playToken) _start();
  }

  @override
  void dispose() {
    _play.dispose();
    _float.dispose();
    for (final image in _photos.values) {
      image.dispose();
    }
    super.dispose();
  }

  void _loadPhotos() {
    for (final activity in [
      ...widget.pieces,
      if (widget.chosen != null) widget.chosen!,
    ]) {
      final url = _urlOf(activity);
      if (url == null || _photos.containsKey(url) || !_loading.add(url)) {
        continue;
      }
      final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          stream.removeListener(listener);
          if (mounted) {
            setState(() => _photos[url] = info.image);
          } else {
            info.image.dispose();
          }
        },
        // No photo: the piece shows its category instead.
        onError: (_, _) => stream.removeListener(listener),
      );
      stream.addListener(listener);
    }
  }

  static String? _urlOf(Activity? activity) {
    final url = activity?.photoUrl?.trim();
    return url != null && url.startsWith('http') ? url : null;
  }

  Future<void> _start() async {
    _mixed = _randomPoses(math.Random(), spin: math.pi);
    _landed.clear();

    if (MediaQuery.disableAnimationsOf(context)) {
      _play.value = 1;
      widget.onDone?.call();
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    await _play.forward(from: 0);
    if (mounted) widget.onDone?.call();
  }

  void _onTick() {
    for (var i = 0; i < _pieceCount; i++) {
      if (!_landed.contains(i) && _play.value >= _landAt(i)) {
        _landed.add(i);
        if (i == _lastPiece) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      }
    }
  }

  // Without a photo, the same icon and colour as the activity's card
  // elsewhere in the app.
  _Face _faceOf(Activity? activity, int index) {
    final visual = activity == null ? null : ActivityVisual.of(activity);
    return _Face(
      photo: _photos[_urlOf(activity)],
      icon: visual?.icon ?? Icons.extension_rounded,
      tint: visual?.tint ?? _colors[index % _colors.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = _play.isAnimating || _play.value == 1;
    final pieces = widget.pieces;
    return Semantics(
      image: true,
      label: playing ? widget.chosen?.title : null,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_play, _float]),
            builder: (context, _) => CustomPaint(
              painter: _PuzzlePainter(
                progress: playing ? _play.value : 0,
                float: _float.value,
                loose: _loose,
                mixed: _mixed,
                looseFaces: [
                  for (var i = 0; i < _pieceCount; i++)
                    _faceOf(
                      pieces.isEmpty ? null : pieces[i % pieces.length],
                      i,
                    ),
                ],
                picture: _faceOf(widget.chosen, 4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Layout and timing ------------------------------------------------------

const _pieceCount = 9;

// The middle of the board lands last.
const _lastPiece = 4;

// For pieces without a photo.
const _colors = <Color>[
  Color(0xFFFCD3B8),
  SynkColors.teal,
  SynkColors.pink,
  SynkColors.orange,
  SynkColors.orangeDark,
  Color(0xFFFCD3B8),
  SynkColors.pink,
  SynkColors.teal,
  SynkColors.orange,
];

// Shuffle timeline, as fractions of the whole: the pieces mix, fly home one
// by one (the middle one last), then the picture glows.
const _mixEnd = 0.36;
const _homeStart = 0.38;
const _homeStep = 0.04;
const _homeLength = 0.1;
const _lastStart = 0.72;
const _lastEnd = 0.82;
const _glowEnd = 0.9;

int _order(int piece) => piece < _lastPiece ? piece : piece - 1;

double _homeAt(int piece) =>
    piece == _lastPiece ? _lastStart : _homeStart + _order(piece) * _homeStep;

double _landAt(int piece) =>
    piece == _lastPiece ? _lastEnd : _homeAt(piece) + _homeLength;

double _phase(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);

class _Pose {
  const _Pose(this.center, this.turn);

  final Offset center;
  final double turn;

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
    Offset.lerp(a.center, b.center, t)!,
    ui.lerpDouble(a.turn, b.turn, t)!,
  );
}

// An activity's look: its photo, or its kind's icon on its colour.
class _Face {
  const _Face({required this.photo, required this.icon, required this.tint});

  final ui.Image? photo;
  final IconData icon;
  final Color tint;
}

// ---- Drawing ----------------------------------------------------------------

class _PuzzlePainter extends CustomPainter {
  _PuzzlePainter({
    required this.progress,
    required this.float,
    required this.loose,
    required this.mixed,
    required this.looseFaces,
    required this.picture,
  });

  final double progress;
  final double float;
  final List<_Pose> loose;
  final List<_Pose> mixed;
  final List<_Face> looseFaces;
  final _Face picture;

  // The finished board fills most of the square, centred.
  static const _boardFraction = 0.84;
  // Loose pieces are a little smaller than board pieces.
  static const _looseScale = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = size.width * _boardFraction;
    final cell = boardSize / 3;
    final board = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: boardSize,
      height: boardSize,
    );

    Offset px(_Pose pose) =>
        Offset(pose.center.dx * size.width, pose.center.dy * size.height);
    _Pose home(int i) => _Pose(
      Offset(
        (board.left + (i % 3 + 0.5) * cell) / size.width,
        (board.top + (i ~/ 3 + 0.5) * cell) / size.height,
      ),
      0,
    );
    // Each loose piece drifts in a small loop and rocks, out of step with
    // the others, so the pile feels alive.
    _Pose bobbing(int i) {
      final angle = (float + i / _pieceCount) * 2 * math.pi;
      final way = i.isEven ? 1.0 : -1.0;
      return _Pose(
        loose[i].center +
            Offset(math.cos(angle) * 0.028 * way, math.sin(angle) * 0.036),
        loose[i].turn + math.sin(angle + i) * 0.16,
      );
    }

    // While mixing, the pieces go once all the way round the middle, each
    // spinning two full turns, half one way and half the other.
    _Pose swirling(int i, double mix) {
      final pose = _Pose.lerp(loose[i], mixed[i], mix);
      final orbit = mix * 2 * math.pi;
      final from = pose.center - const Offset(0.5, 0.5);
      final round = Offset(
        from.dx * math.cos(orbit) - from.dy * math.sin(orbit),
        from.dx * math.sin(orbit) + from.dy * math.cos(orbit),
      );
      return _Pose(
        const Offset(0.5, 0.5) + round,
        pose.turn + mix * 4 * math.pi * (i.isEven ? 1 : -1),
      );
    }

    // The same angle within one turn, so a piece flying home doesn't
    // unwind the turns it spun.
    double oneTurn(double turn) =>
        turn - (turn / (2 * math.pi)).roundToDouble() * 2 * math.pi;

    final t = progress;
    final started = t > 0 && mixed.length == _pieceCount;
    final mix = Curves.easeInOutCubic.transform(_phase(t, 0, _mixEnd));

    // The middle gap, once the board starts filling in.
    if (started && t >= _homeStart && t < _lastEnd) {
      _drawGap(canvas, px(home(_lastPiece)), cell);
    }

    // The last piece is drawn on top of the others.
    final order = [
      for (var i = 0; i < _pieceCount; i++)
        if (i != _lastPiece) i,
      _lastPiece,
    ];
    for (final i in order) {
      final start = _homeAt(i);
      final end = i == _lastPiece ? _lastEnd : start + _homeLength;

      var pose = bobbing(i);
      var scale = _looseScale;
      var heading = false;
      if (started) {
        final back = Curves.easeOutBack.transform(_phase(t, start, end));
        heading = t > start;
        // Where the swirl left it, so it flies home without a jump.
        final swirled = swirling(i, mix);
        if (back > 0) {
          // One more full turn on the way into place.
          final spin = 2 * math.pi * (i.isEven ? 1 : -1);
          pose = _Pose.lerp(
            _Pose(swirled.center, oneTurn(swirled.turn) + spin),
            home(i),
            back,
          );
          scale = ui.lerpDouble(_looseScale, 1, back)!;
        } else {
          pose = swirled;
        }
      }

      // Once it heads home, a piece shows its part of the chosen picture.
      _drawPiece(
        canvas,
        index: i,
        center: px(pose),
        turn: pose.turn,
        cell: cell,
        scale: scale,
        face: heading ? picture : looseFaces[i],
        slice: heading,
        board: board,
      );
    }

    // The finished picture glows, with a ripple.
    final glow = started ? _phase(t, _lastEnd, _glowEnd) : 0.0;
    if (glow > 0) {
      final frame = RRect.fromRectAndRadius(board, const Radius.circular(6));
      canvas.drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = SynkColors.orangeDark.withValues(
            alpha: math.min(1, glow * 2),
          ),
      );
      if (glow < 1) {
        canvas.drawRRect(
          frame.inflate(cell * 0.4 * glow),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - glow)
            ..color = SynkColors.orangeDark.withValues(alpha: 0.6 * (1 - glow)),
        );
      }
    }
  }

  void _drawGap(Canvas canvas, Offset center, double cell) {
    final path = _piecePath(_lastPiece, cell);
    canvas.save();
    canvas.translate(center.dx - cell / 2, center.dy - cell / 2);
    canvas.drawPath(
      path,
      Paint()..color = SynkColors.orangeDark.withValues(alpha: 0.1),
    );
    canvas.drawPath(
      _dashed(path, cell * 0.07, cell * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = SynkColors.orangeDark,
    );
    _drawText(
      canvas,
      '?',
      Offset(cell / 2, cell / 2),
      cell * 0.42,
      SynkColors.orangeDark,
    );
    canvas.restore();
  }

  // With [slice], the piece shows its own part of [face] spread over the
  // whole [board]; otherwise the whole of [face].
  void _drawPiece(
    Canvas canvas, {
    required int index,
    required Offset center,
    required double turn,
    required double cell,
    required double scale,
    required _Face face,
    required bool slice,
    required Rect board,
  }) {
    final path = _piecePath(index, cell);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turn);
    canvas.scale(scale);
    canvas.translate(-cell / 2, -cell / 2);

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.3), 3, false);
    canvas.save();
    canvas.clipPath(path);
    if (slice) {
      // The whole board, placed so this piece's cell lines up with it.
      final area = Rect.fromLTWH(
        -(index % 3) * cell,
        -(index ~/ 3) * cell,
        board.width,
        board.height,
      );
      _paintFace(canvas, face, area, iconSize: cell * 1.1);
    } else {
      _paintFace(
        canvas,
        face,
        Rect.fromLTWH(0, 0, cell, cell).inflate(cell * 0.2),
        iconSize: cell * 0.42,
      );
    }
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / scale
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.restore();
  }

  // A photo fills [area]. Without one, a soft gradient of the activity's
  // colour with its icon in a light circle in the middle, like the
  // activity cards elsewhere in the app but bolder.
  static void _paintFace(
    Canvas canvas,
    _Face face,
    Rect area, {
    required double iconSize,
  }) {
    if (face.photo != null) {
      paintImage(
        canvas: canvas,
        rect: area,
        image: face.photo!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
      return;
    }
    final tint = face.tint;
    canvas.drawRect(area.inflate(iconSize), Paint()..color = Colors.white);
    canvas.drawRect(
      area.inflate(iconSize),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.28), tint.withValues(alpha: 0.6)],
        ).createShader(area),
    );
    canvas.drawCircle(
      area.center,
      iconSize * 0.78,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    final icon = face.icon;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Color.lerp(tint, SynkColors.textPrimary, 0.35),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      area.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  static void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize, [
    Color color = SynkColors.ink,
  ]) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        out.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return out;
  }

  // The piece at [index] on the 3 x 3 board, in a [cell]-sized square.
  // Neighbouring edges fit together: one has a knob where the other has a
  // hollow. Board edges are flat.
  static Path _piecePath(int index, double cell) {
    final row = index ~/ 3;
    final col = index % 3;
    int down(int r, int c) => (r + c).isEven ? 1 : -1;
    int across(int r, int c) => (r + c).isEven ? -1 : 1;

    final top = row > 0 ? -down(row - 1, col) : 0;
    final right = col < 2 ? across(row, col) : 0;
    final bottom = row < 2 ? down(row, col) : 0;
    final left = col > 0 ? -across(row, col - 1) : 0;

    final path = Path()..moveTo(0, 0);
    _edge(path, Offset.zero, Offset(cell, 0), top);
    _edge(path, Offset(cell, 0), Offset(cell, cell), right);
    _edge(path, Offset(cell, cell), Offset(0, cell), bottom);
    _edge(path, Offset(0, cell), Offset.zero, left);
    return path..close();
  }

  // One side, clockwise from [a] to [b]: flat (0), a knob sticking out (1)
  // or a hollow going in (-1). The same rounded knob as PuzzlePieceTile.
  static void _edge(Path path, Offset a, Offset b, int knob) {
    if (knob == 0) {
      path.lineTo(b.dx, b.dy);
      return;
    }
    final along = b - a;
    final length = along.distance;
    final u = along / length;
    // Outward for a clockwise square in screen coordinates.
    final n = Offset(u.dy, -u.dx) * knob.toDouble();
    Offset at(double s, double h) => a + u * (s * length) + n * (h * length);

    final p1 = at(0.367, 0);
    final c1 = at(0.367, 0.133);
    final c2 = at(0.433, 0.2);
    final top = at(0.5, 0.2);
    final c3 = at(0.567, 0.2);
    final c4 = at(0.633, 0.133);
    final p2 = at(0.633, 0);
    path
      ..lineTo(p1.dx, p1.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, top.dx, top.dy)
      ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, p2.dx, p2.dy)
      ..lineTo(b.dx, b.dy);
  }

  // Only repaints while animating or when a photo arrives.
  @override
  bool shouldRepaint(_PuzzlePainter old) => true;
}
