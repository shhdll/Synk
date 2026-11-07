import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../widgets/synk_blob_background.dart';
import 'widgets/settings_row.dart';

const _paper = Color(0xFFFFFDF8);
const _paperLine = Color(0x2E4FA89B);
const _marginLine = Color(0x66FF9EC0);
const _letterInk = Color(0xFF2D2A32);
const _sealInk = Color(0xFFC94A42);

// One line of the letter. The paper lines are drawn at the same spacing.
const _fontSize = 31.0;
const _lineHeight = 36.0;
const _padTop = 30.0;
const _padLeft = 40.0;

// The letter, one paragraph at a time, and the words marked with a
// highlighter.
const _letter = <(String, String?)>[
  ('Hey,', null),
  ("If you're reading this, you found the quiet corner of the app.", null),
  (
    "We're six Software Engineering students @ KSU. For a long time we kept "
        'saying the same thing: we should go out more, try new things, meet '
        'new friends. But someone always had to make the plan, and most of '
        'the time nobody did.',
    null,
  ),
  (
    'So we built Synk. A place where the plan is already there, and all you '
        'have to do is show up.',
    'we built Synk',
  ),
  (
    'It took a lot of late nights and more voice notes than we can count. We '
        'argued about colors, fixed bugs at 2 AM and found new ones by '
        'morning. And somewhere along the way we became closer friends.',
    null,
  ),
  (
    "So make a plan. Join something you've never tried. Say yes when "
        'someone invites you.',
    null,
  ),
  ('Thank you for being here. It means more to us than you know.', null),
  ('With love,', null),
];

class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView>
    with SingleTickerProviderStateMixin {
  // The title rises in, then the paper slides up.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  bool _paperReady = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Wait for the fonts first so the title doesn't jump when they swap in.
    GoogleFonts.pendingFonts([
          GoogleFonts.instrumentSerif(),
          GoogleFonts.instrumentSerif(fontStyle: FontStyle.italic),
          GoogleFonts.nanumPenScript(),
        ])
        .timeout(const Duration(seconds: 2), onTimeout: () => [])
        .whenComplete(() {
          if (!mounted) return;
          _intro.forward().then((_) {
            if (mounted) setState(() => _paperReady = true);
          });
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _intro.value = 1;
  }

  @override
  void dispose() {
    _intro.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Part of the intro between [from] and [to] (in 0 to 1), eased.
  double _step(double from, double to) => Curves.easeOutCubic.transform(
    ((_intro.value - from) / (to - from)).clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            // Let the letter scroll under the system bar at the bottom.
            bottom: false,
            child: Column(
              children: [
                SettingsHeader(title: l10n.aboutSynk),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        18,
                        0,
                        18,
                        48 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        children: [
                          // Leaves room so only the top of the paper shows
                          // at first.
                          SizedBox(
                            height: constraints.maxHeight * 0.56,
                            width: double.infinity,
                            child: AnimatedBuilder(
                              animation: _intro,
                              builder: (context, _) => _Hero(
                                title: _step(0.05, 0.4),
                                subtitle: _step(0.25, 0.55),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _intro,
                            builder: (context, child) {
                              // Rises from below the screen, overshoots a
                              // touch and settles straight, like a sheet
                              // slid onto a table.
                              final raw = ((_intro.value - 0.4) / 0.6).clamp(
                                0.0,
                                1.0,
                              );
                              final t = const Cubic(
                                0.22,
                                1.15,
                                0.36,
                                1,
                              ).transform(raw);
                              return Opacity(
                                opacity: (raw * 2.5).clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, (1 - t) * 320),
                                  child: Transform.rotate(
                                    angle: -5 * (1 - t) * math.pi / 180,
                                    child: Transform.scale(
                                      scale: 0.96 + 0.04 * t,
                                      child: child,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: _Letter(ready: _paperReady),
                          ),
                          const SizedBox(height: 40),
                          const AppVersionText(),
                          const SizedBox(height: 4),
                          Text(
                            l10n.madeInRiyadh,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SynkColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Blurs the bottom of the screen until the reader starts scrolling.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 170,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_scroll, _intro]),
                builder: (context, child) {
                  final scrolled = _scroll.hasClients ? _scroll.offset : 0.0;
                  final shown = (1 - scrolled / 120).clamp(0.0, 1.0);
                  return Opacity(opacity: shown * _step(0.45, 1), child: child);
                },
                child: const _BottomBlur(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Blur that builds up toward the bottom edge. It's many thin layers, each
// adding a little more blur, so there's no visible line where it starts.
class _BottomBlur extends StatelessWidget {
  const _BottomBlur();

  static const _layers = 16;
  static const _step = 10.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < _layers; i++)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 170 - i * _step,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 0.2 + i * 0.03,
                  sigmaY: 0.2 + i * 0.03,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00F6D3BE), Color(0x80F6D3BE)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// "Version 1.0.0 (1)", read from the installed app.
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Text(
          info == null
              ? ''
              : context.l10n.appVersion(info.version, info.buildNumber),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SynkColors.textSecondary,
          ),
        );
      },
    );
  }
}

// Cream at the top deepening into warm pink and peach at the bottom,
// with soft color glows, the drifting blobs and a faint dot grid that fades out downward.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF4EA), Color(0xFFF9E4DE), Color(0xFFF6D3BE)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: [
          // Soft glows in three of the app's colors, so no one color takes
          // over: orange low on the left, pink low on the right, and a
          // hint of teal up top.
          for (final (center, color) in const [
            (Alignment(-0.9, 1.1), Color(0x66FF9F5C)),
            (Alignment(0.95, 0.95), Color(0x66FF9EC0)),
            (Alignment(1.0, -0.7), Color(0x334FA89B)),
          ])
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: center,
                    radius: 0.9,
                    colors: [color, color.withAlpha(0)],
                  ),
                ),
              ),
            ),
          const Positioned.fill(child: SynkBlobBackground()),
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _DotGrid())),
          ),
        ],
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  const _DotGrid();

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 22.0;
    final paint = Paint();
    for (var y = gap / 2; y < size.height; y += gap) {
      final fade = 1 - (y / size.height);
      paint.color = SynkColors.ink.withValues(alpha: 0.09 * fade * fade);
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});

  // How far each part has risen in, 0 to 1.
  final double title;
  final double subtitle;

  Widget _rise(double t, Widget child) => Opacity(
    opacity: t,
    child: Transform.translate(offset: Offset(0, (1 - t) * 26), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = l10n.aboutLetterTitle.split(' ');
    final head = words.length > 1
        ? '${words.sublist(0, words.length - 1).join(' ')} '
        : '';
    final style =
        GoogleFonts.instrumentSerif(
          fontSize: 44,
          height: 1.05,
          letterSpacing: -0.8,
          color: SynkColors.textPrimary,
        ).copyWith(
          fontFamilyFallback: [GoogleFonts.ibmPlexSansArabic().fontFamily!],
        );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _rise(
          title,
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: head),
                TextSpan(
                  text: words.last,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        const SizedBox(height: 10),
        _rise(
          subtitle,
          Text(
            l10n.aboutLetterFrom,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: SynkColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// The team's letter on lined paper. The date, "Hey," and the first
// paragraph write themselves in one after another. Then the rest of the
// letter fades in and reads normally. Kept in English in both languages.
class _Letter extends StatefulWidget {
  const _Letter({required this.ready});

  final bool ready;

  @override
  State<_Letter> createState() => _LetterState();
}

class _LetterState extends State<_Letter> {
  static final _body = GoogleFonts.nanumPenScript(
    fontSize: _fontSize,
    height: _lineHeight / _fontSize,
    color: _letterInk,
  );

  // How many paragraphs are written in before the rest fades in.
  static const _writtenCount = 2;

  // 0 is the date, then each written paragraph. Past the end means the
  // opening is done.
  int _step = 0;

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    final ready = widget.ready;
    final openingDone = _step > _writtenCount;

    Widget rest(Widget child) => AnimatedOpacity(
      opacity: openingDone ? 1 : 0,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      child: child,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            painter: _PaperPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_padLeft, _padTop, 18, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WrittenText(
                    'Dec 2026',
                    style: _body.copyWith(
                      fontSize: 22,
                      height: _lineHeight / 22,
                      color: const Color(0xFF8A6F55),
                    ),
                    textAlign: TextAlign.right,
                    start: ready,
                    onDone: _next,
                  ),
                  for (final (i, (text, mark)) in _letter.indexed) ...[
                    if (i < _writtenCount)
                      _WrittenText(
                        text,
                        style: _body,
                        start: ready && _step >= i + 1,
                        onDone: _next,
                      )
                    else
                      rest(
                        _WhenVisible(
                          enabled: openingDone,
                          builder: (visible) => _WrittenText(
                            text,
                            style: _body,
                            start: visible,
                            writeIn: false,
                            highlight: mark,
                            highlightColor: SynkColors.orange.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    if (i < _letter.length - 1)
                      const SizedBox(height: _lineHeight),
                  ],
                  const SizedBox(height: _lineHeight / 2),
                  rest(const _SignatureLines()),
                  rest(
                    _WhenVisible(
                      enabled: openingDone,
                      builder: (visible) => Align(
                        alignment: const Alignment(0.7, 0),
                        child: _CompanySeal(size: 120, stamp: visible),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: -12,
            child: Center(child: _Tape(color: Color(0xA6FFD166), angle: -0.06)),
          ),
        ],
      ),
    );
  }
}

// Each name under an empty line, ready for the real signatures.
class _SignatureLines extends StatelessWidget {
  const _SignatureLines();

  static const _names = [
    'Shahad',
    'Laila',
    'Joud W.',
    'Muneerah',
    'Shaden',
    'Joud A.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _names.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: _SignatureLine(_names[i])),
                const SizedBox(width: 16),
                Expanded(child: _SignatureLine(_names[i + 1])),
              ],
            ),
          ),
      ],
    );
  }
}

class _SignatureLine extends StatelessWidget {
  const _SignatureLine(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 38),
        Container(
          padding: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _letterInk.withValues(alpha: 0.3)),
            ),
          ),
          child: Text(
            name.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xFF9A8F82),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paper = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawShadow(
      Path()..addRRect(paper),
      Colors.black.withValues(alpha: 0.45),
      10,
      false,
    );
    canvas.drawRRect(paper, Paint()..color = _paper);

    final line = Paint()
      ..color = _paperLine
      ..strokeWidth = 1;
    for (var y = _padTop + _lineHeight - 9; y < size.height; y += _lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawLine(
      const Offset(_padLeft - 12, 0),
      Offset(_padLeft - 12, size.height),
      Paint()
        ..color = _marginLine
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Tape extends StatelessWidget {
  const _Tape({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 78,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// Calls builder(true) once the widget has scrolled into view, and stays true.
class _WhenVisible extends StatefulWidget {
  const _WhenVisible({required this.enabled, required this.builder});

  final bool enabled;
  final Widget Function(bool visible) builder;

  @override
  State<_WhenVisible> createState() => _WhenVisibleState();
}

class _WhenVisibleState extends State<_WhenVisible> {
  ScrollPosition? _position;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_check);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(_WhenVisible old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !old.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  void _check() {
    if (_visible || !widget.enabled || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.85) {
      _position?.removeListener(_check);
      setState(() => _visible = true);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_visible);
}

// Text that appears line by line, as if someone is writing it.
class _WrittenText extends StatefulWidget {
  const _WrittenText(
    this.text, {
    required this.style,
    required this.start,
    this.textAlign = TextAlign.start,
    this.highlight,
    this.highlightColor = Colors.transparent,
    this.writeIn = true,
    this.onDone,
  });

  final String text;
  final TextStyle style;
  final bool start;

  // False shows the text straight away. Only the highlight animates.
  final bool writeIn;
  final VoidCallback? onDone;
  final TextAlign textAlign;

  // Words swiped with a highlighter once the writing is done.
  final String? highlight;
  final Color highlightColor;

  @override
  State<_WrittenText> createState() => _WrittenTextState();
}

class _WrittenTextState extends State<_WrittenText>
    with SingleTickerProviderStateMixin {
  late final int _writeMs = widget.writeIn
      ? (widget.text.length * 16).clamp(350, 2600)
      : 0;
  late final int _markMs = widget.highlight == null ? 0 : 500;
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: math.max(_writeMs + _markMs, 1)),
  );

  @override
  void initState() {
    super.initState();
    // Re-measure once the handwriting font has loaded.
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(_WrittenText old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  void _maybeStart() {
    if (!widget.start || _controller.isAnimating || _controller.isCompleted) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _fontsChanged() {
    if (mounted) setState(() {});
  }

  TextSelection? _markRange() {
    final mark = widget.highlight;
    if (mark == null) return null;
    final start = widget.text.indexOf(mark);
    if (start < 0) return null;
    return TextSelection(baseOffset: start, extentOffset: start + mark.length);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textAlign: widget.textAlign,
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
        );
        // Fill the full width when it's known, so right and center
        // alignment work.
        if (constraints.maxWidth.isFinite) {
          painter.layout(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
          );
        } else {
          painter.layout();
        }
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : painter.width;

        return Semantics(
          label: widget.text,
          child: SizedBox(
            width: width,
            height: painter.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final ms = _controller.value * (_writeMs + _markMs);
                return CustomPaint(
                  painter: _WrittenPainter(
                    painter,
                    _writeMs == 0 ? 1.0 : (ms / _writeMs).clamp(0.0, 1.0),
                    direction == TextDirection.rtl,
                    mark: _markRange(),
                    markColor: widget.highlightColor,
                    markProgress: _markMs == 0
                        ? 0
                        : ((ms - _writeMs) / _markMs).clamp(0.0, 1.0),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WrittenPainter extends CustomPainter {
  _WrittenPainter(
    this.text,
    this.progress,
    this.rtl, {
    this.mark,
    this.markColor = Colors.transparent,
    this.markProgress = 0,
  });

  final TextPainter text;
  final double progress;
  final bool rtl;
  final TextSelection? mark;
  final Color markColor;
  final double markProgress;

  // A highlighter stroke under the marked words, a little crooked like a
  // real one.
  void _paintMark(Canvas canvas) {
    final range = mark;
    if (range == null || markProgress <= 0) return;
    final boxes = text.getBoxesForSelection(range);
    final total = boxes.fold<double>(0, (sum, b) => sum + b.right - b.left);
    var left = total * markProgress;
    final paint = Paint()..color = markColor;
    for (final b in boxes) {
      if (left <= 0) break;
      final shown = math.min(left, b.right - b.left);
      left -= b.right - b.left;
      final h = b.bottom - b.top;
      final path = Path()
        ..moveTo(b.left - 3, b.top + h * 0.5)
        ..lineTo(b.left + shown + 3, b.top + h * 0.44)
        ..lineTo(b.left + shown + 2, b.top + h * 0.84)
        ..lineTo(b.left - 2, b.top + h * 0.9)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    if (progress >= 1) {
      _paintMark(canvas);
      text.paint(canvas, Offset.zero);
      return;
    }
    final lines = text.computeLineMetrics();
    final total = lines.fold<double>(0, (sum, l) => sum + l.width);
    var left = total * progress;

    for (final line in lines) {
      if (left <= 0) break;
      final shown = math.min(left, line.width);
      left -= line.width;
      final top = line.baseline - line.ascent;
      final x = rtl ? line.left + line.width - shown : line.left;
      canvas.save();
      // A little extra height so tall letters and tails aren't cut.
      canvas.clipRect(Rect.fromLTWH(x, top - 6, shown + 2, line.height + 12));
      text.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WrittenPainter old) =>
      old.progress != progress ||
      old.markProgress != markProgress ||
      old.text != text;
}

// Round blue ink company seal. It drops onto the paper once everyone has
// signed.
class _CompanySeal extends StatefulWidget {
  const _CompanySeal({required this.size, required this.stamp});

  final double size;
  final bool stamp;

  @override
  State<_CompanySeal> createState() => _CompanySealState();
}

class _CompanySealState extends State<_CompanySeal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(_CompanySeal old) {
    super.didUpdateWidget(old);
    if (widget.stamp && !old.stamp) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
        return;
      }
      // A short pause once the names are in view, then the stamp comes down.
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _controller.forward();
        Future.delayed(const Duration(milliseconds: 260), () {
          HapticFeedback.mediumImpact();
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    final seal = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SealPainter())),
          Align(
            alignment: const Alignment(0, -0.12),
            child: Image.asset(
              'assets/synk_logo_transparent.png',
              width: size * 0.26,
              color: _sealInk,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.36),
            child: Text(
              'with love',
              style: GoogleFonts.caveat(
                fontSize: size * 0.1,
                fontWeight: FontWeight.w700,
                color: _sealInk,
                height: 1,
              ),
            ),
          ),
          // Rubs out specks and patches of ink so it looks pressed by hand.
          // This works because the Opacity below always gives the seal its
          // own layer.
          Positioned.fill(child: CustomPaint(painter: _InkWear())),
        ],
      ),
    );

    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final v = _controller.value;
            // Falls in big over the first half, then settles with a tiny
            // bounce, like a stamp pressed onto paper.
            final fall = Curves.easeIn.transform((v / 0.5).clamp(0.0, 1.0));
            final settle = ((v - 0.5) / 0.5).clamp(0.0, 1.0);
            final scale = v < 0.5
                ? 2.4 - 1.4 * fall
                : 1 - 0.06 * math.sin(settle * math.pi);
            return Opacity(
              opacity: (v * 3).clamp(0.0, 1.0) * 0.62,
              child: Transform.rotate(
                angle: (-24 + 10 * fall) * math.pi / 180,
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: seal,
        ),
      ),
    );
  }
}

class _InkWear extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final erase = Paint()..blendMode = BlendMode.dstOut;
    final s = size.width;

    // Lighter patches where the stamp didn't press evenly.
    for (var i = 0; i < 7; i++) {
      erase.color = Colors.black.withValues(
        alpha: 0.18 + random.nextDouble() * 0.2,
      );
      canvas.drawCircle(
        Offset(random.nextDouble() * s, random.nextDouble() * s),
        s * (0.06 + random.nextDouble() * 0.1),
        erase,
      );
    }
    // Fine specks of missing ink.
    for (var i = 0; i < 420; i++) {
      erase.color = Colors.black.withValues(
        alpha: 0.5 + random.nextDouble() * 0.5,
      );
      canvas.drawCircle(
        Offset(random.nextDouble() * s, random.nextDouble() * s),
        0.3 + random.nextDouble() * 0.9,
        erase,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s / 2;
    final center = Offset(r, r);
    Paint ring(double width) => Paint()
      ..color = _sealInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    canvas.drawCircle(center, r - s * 0.02, ring(s * 0.028));
    canvas.drawCircle(center, r * 0.86, ring(s * 0.01));
    canvas.drawCircle(center, r * 0.52, ring(s * 0.013));

    final style = TextStyle(
      color: _sealInk,
      fontSize: s * 0.075,
      fontWeight: FontWeight.w800,
    );
    _arcText(
      canvas,
      center,
      r * 0.7,
      'SYNK',
      style.copyWith(fontSize: s * 0.11),
      top: true,
      spacing: 0.6,
    );
    _arcText(canvas, center, r * 0.7, '★ RIYADH 2026 ★', style, top: false);
  }

  // Draws text along the top arc (reading clockwise) or the bottom arc
  // (reading left to right, upright).
  void _arcText(
    Canvas canvas,
    Offset center,
    double radius,
    String text,
    TextStyle style, {
    required bool top,
    double spacing = 0.12,
  }) {
    final gap = style.fontSize! * spacing;
    final glyphs = [
      for (final ch in text.characters)
        TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final total = glyphs.fold<double>(0, (sum, g) => sum + g.width + gap) - gap;
    final sweep = total / radius;
    var run = 0.0;

    for (final g in glyphs) {
      final mid = (run + g.width / 2) / radius;
      final angle = top
          ? -math.pi / 2 - sweep / 2 + mid
          : math.pi / 2 + sweep / 2 - mid;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(top ? angle + math.pi / 2 : angle - math.pi / 2);
      canvas.translate(0, top ? -radius : radius);
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
      canvas.restore();
      run += g.width + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
