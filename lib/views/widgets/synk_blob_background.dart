import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import 'blob_layout.dart';

// The drifting blob background from the first onboarding slide: four soft
// circles at 20% opacity under a 55 sigma blur, on a 6s back-and-forth loop.
class SynkBlobBackground extends StatefulWidget {
  const SynkBlobBackground({super.key});

  @override
  State<SynkBlobBackground> createState() => _SynkBlobBackgroundState();
}

class _SynkBlobBackgroundState extends State<SynkBlobBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Isolated so scrolling content above never repaints the blur.
    return RepaintBoundary(
      child: ClipRect(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  final layout = BlobLayout.intro(
                    size,
                    math.sin(t * math.pi),
                    math.cos(t * math.pi),
                  );

                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: layout.pinkTop,
                          left: layout.pinkLeft,
                          child: _blob(SynkColors.pink, 280),
                        ),
                        Positioned(
                          bottom: layout.orangeBottom,
                          right: layout.orangeRight,
                          child: _blob(SynkColors.orange, 320),
                        ),
                        Positioned(
                          top: layout.smallTop,
                          right: layout.smallRight,
                          child: _blob(SynkColors.orange, 120),
                        ),
                        Positioned(
                          bottom: layout.tealBottom,
                          left: layout.tealLeft,
                          child: _blob(SynkColors.teal, 150),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.20),
      ),
    );
  }
}
