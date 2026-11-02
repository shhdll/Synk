import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';

// Formats half stars as a star count, e.g. 9 -> "4.5" and 8 -> "4".
String formatHalfStars(int halfStars) {
  return halfStars.isEven ? '${halfStars ~/ 2}' : '${halfStars / 2}';
}

// Five stars that accept 0.5 to 5 in half steps, by tap or drag.
// Stars fill from the reading direction's start, so they mirror in Arabic.
// Tapping the current value again clears it (value 0).
class HalfStarRatingInput extends StatelessWidget {
  const HalfStarRatingInput({
    super.key,
    required this.halfStars,
    required this.onChanged,
    this.starSize = 30,
    this.enabled = true,
  });

  static const int maxHalfStars = 10;

  final int halfStars;
  final ValueChanged<int> onChanged;
  final double starSize;
  final bool enabled;

  // Maps a touch position to 1–10 half stars from the start edge.
  int _halfStarsAt(double dx, double width, TextDirection direction) {
    final fromStart = direction == TextDirection.rtl ? width - dx : dx;
    final fraction = (fromStart / width).clamp(0.0, 1.0);
    return (fraction * maxHalfStars).ceil().clamp(1, maxHalfStars);
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final width = starSize * 5;
    final value = halfStars == 0
        ? context.l10n.tapToRate
        : context.l10n.starsOutOfFive(formatHalfStars(halfStars));

    return Semantics(
      slider: true,
      label: context.l10n.rating,
      value: value,
      enabled: enabled,
      increasedValue: halfStars < maxHalfStars
          ? context.l10n.starsOutOfFive(formatHalfStars(halfStars + 1))
          : null,
      decreasedValue: halfStars > 1
          ? context.l10n.starsOutOfFive(formatHalfStars(halfStars - 1))
          : null,
      onIncrease: enabled && halfStars < maxHalfStars
          ? () => onChanged(halfStars + 1)
          : null,
      onDecrease: enabled && halfStars > 1
          ? () => onChanged(halfStars - 1)
          : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: enabled
              ? (details) {
                  final value = _halfStarsAt(
                    details.localPosition.dx,
                    width,
                    direction,
                  );
                  onChanged(value == halfStars ? 0 : value);
                }
              : null,
          onHorizontalDragUpdate: enabled
              ? (details) {
                  final value = _halfStarsAt(
                    details.localPosition.dx,
                    width,
                    direction,
                  );
                  if (value != halfStars) onChanged(value);
                }
              : null,
          child: SizedBox(
            width: width,
            height: starSize,
            child: Row(
              children: [
                for (var star = 0; star < 5; star++)
                  _Star(
                    fill: ((halfStars - star * 2).clamp(0, 2)) / 2,
                    size: starSize,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// One star, filled 0, half, or fully from the start edge.
class _Star extends StatelessWidget {
  const _Star({required this.fill, required this.size});

  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final outline = Icon(
      Icons.star_rounded,
      size: size,
      color: SynkColors.textSecondary.withValues(alpha: 0.22),
    );
    if (fill <= 0) return outline;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          outline,
          ClipRect(
            clipper: _StartClipper(
              fraction: fill,
              direction: Directionality.of(context),
            ),
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: SynkColors.orangeDark,
            ),
          ),
        ],
      ),
    );
  }
}

// Keeps [fraction] of the width, measured from the start edge.
class _StartClipper extends CustomClipper<Rect> {
  const _StartClipper({required this.fraction, required this.direction});

  final double fraction;
  final TextDirection direction;

  @override
  Rect getClip(Size size) {
    final width = size.width * fraction;
    return direction == TextDirection.rtl
        ? Rect.fromLTWH(size.width - width, 0, width, size.height)
        : Rect.fromLTWH(0, 0, width, size.height);
  }

  @override
  bool shouldReclip(_StartClipper oldClipper) {
    return oldClipper.fraction != fraction ||
        oldClipper.direction != direction;
  }
}
