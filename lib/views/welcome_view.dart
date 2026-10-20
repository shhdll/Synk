import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/welcome_controller.dart';
import '../core/constants/synk_colors.dart';
import '../l10n/l10n.dart';
import 'widgets/language_toggle.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView>
    with TickerProviderStateMixin {
  late final WelcomeController _controller;
  late final AnimationController _blobAnimationController;
  late final AnimationController _marqueeAnimationController;

  @override
  void initState() {
    super.initState();
    _controller = WelcomeController()..addListener(() => setState(() {}));

    _blobAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _marqueeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _blobAnimationController.dispose();
    _marqueeAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.scrollProgress.clamp(0.0, 1.0);
    final blob1Color = Color.lerp(SynkColors.pink, SynkColors.teal, progress)!;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: Stack(
        children: [
          // 1. Background Animated Blobs
          AnimatedBuilder(
            animation: _blobAnimationController,
            builder: (context, _) {
              final anim = _blobAnimationController.value;
              return Stack(
                children: [
                  Positioned(
                    top: -60 + (anim * 24),
                    left: -40 + (anim * 20),
                    child: _buildBlob(blob1Color, 280),
                  ),
                  Positioned(
                    bottom: -80 - (anim * 28),
                    right: -50 - (anim * 18),
                    child: _buildBlob(SynkColors.orange, 320),
                  ),
                  Positioned(
                    top:
                        MediaQuery.of(context).size.height * 0.45 + (anim * 18),
                    right: 40 - (anim * 24),
                    child: _buildBlob(SynkColors.orange, 120),
                  ),
                ],
              );
            },
          ),

          // 2. Gaussian Blur Filter Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: const SizedBox.expand(),
            ),
          ),

          // 3. Slide PageView
          PageView(
            controller: _controller.pageController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSlideOne(context, progress),
              _buildSlideTwo(context),
            ],
          ),

          // 4. Top Header (Logo + Name)
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 28.0,
                top: 12.0,
                end: 20.0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/synk_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.all_inclusive_rounded,
                          color: SynkColors.orange,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Synk',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const LanguageToggle(),
                ],
              ),
            ),
          ),

          // 5. Bottom Navigation Overlays
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28.0,
                  vertical: 20.0,
                ),
                child: IgnorePointer(
                  ignoring: progress > 0.6,
                  child: Opacity(
                    opacity: (1.0 - (progress * 2.5)).clamp(0.0, 1.0),
                    child: _buildSlide1Nav(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 1: Headline on top, larger and shifted Puzzle Image below
  Widget _buildSlideOne(BuildContext context, double scrollProgress) {
    final activities = _controller.model.activities;
    final marqueeOpacity = (1.0 - (scrollProgress * 3.0)).clamp(0.0, 1.0);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final puzzleSize = (screenHeight * 0.42).clamp(240.0, 420.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keep the headline below the logo and app name layered above it.
            const SizedBox(height: 72),
            Text(
              context.l10n.findYourMissingPiece,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: -1.4,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.only(right: 20.0),
                child: Image.asset(
                  'assets/puzzle.png',
                  width: puzzleSize,
                  height: puzzleSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Spacer(flex: 1),
            Opacity(
              opacity: marqueeOpacity,
              child: SizedBox(
                height: 58,
                child: AnimatedBuilder(
                  animation: _marqueeAnimationController,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        const estimatedItemSpan = 150.0;
                        final totalSetWidth =
                            estimatedItemSpan * activities.length;
                        final currentOffset =
                            _marqueeAnimationController.value * totalSetWidth;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: -currentOffset,
                              top: 0,
                              bottom: 0,
                              child: Row(
                                children: List.generate(activities.length * 4, (
                                  i,
                                ) {
                                  final item =
                                      activities[i % activities.length];
                                  return Container(
                                    margin: const EdgeInsetsDirectional.only(
                                      end: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.emoji,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          valueLabel(item.label),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: SynkColors.textPrimary,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
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
            const SizedBox(height: 105),
          ],
        ),
      ),
    );
  }

  // Slide 2: Centered Typography + Balanced Auth Buttons
  Widget _buildSlideTwo(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Centered Header & Tagline
            Text(
              context.l10n.readyToSynk,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: -1.4,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                context.l10n.joinThousandsAlreadyDoingWhatThey,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: SynkColors.textSecondary.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),

            const Spacer(flex: 3),

            // Primary Action: Sign Up
            GestureDetector(
              onTap: () => _controller.onSignUp(context),
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [SynkColors.orange, SynkColors.orangeDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SynkColors.orange.withValues(alpha: 0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.signUp,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Secondary Action: Log In
            GestureDetector(
              onTap: () => _controller.onLogIn(context),
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withValues(alpha: 0.85),
                  border: Border.all(
                    color: SynkColors.textPrimary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    context.l10n.logIn,
                    style: TextStyle(
                      color: SynkColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bottom Pagination Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleIndicator(isActive: false),
                const SizedBox(width: 6),
                _buildPillIndicator(isActive: true),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildBlob(Color color, double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.20),
      ),
    );
  }

  Widget _buildSlide1Nav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildPillIndicator(isActive: true),
            const SizedBox(width: 6),
            _buildCircleIndicator(isActive: false),
          ],
        ),
        GestureDetector(
          onTap: _controller.nextSlide,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [SynkColors.orange, SynkColors.orangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: SynkColors.orangeDark.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPillIndicator({required bool isActive}) {
    return Container(
      width: 28,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isActive
            ? SynkColors.orange
            : SynkColors.textSecondary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildCircleIndicator({required bool isActive}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? SynkColors.orange
            : SynkColors.textSecondary.withValues(alpha: 0.3),
      ),
    );
  }
}
