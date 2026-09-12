import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/constants/synk_colors.dart';
import '../utils/custom_widgets/puzzle_piece_tile.dart';
import 'login_view.dart';

class ResetSuccessView extends StatefulWidget {
  const ResetSuccessView({super.key});

  @override
  State<ResetSuccessView> createState() => _ResetSuccessViewState();
}

class _ResetSuccessViewState extends State<ResetSuccessView>
    with TickerProviderStateMixin {
  // Same slow drift as the Welcome screen's background blobs.
  late final AnimationController _blobAnimationController;

  // Staggered entrance for the tile, headline and button.
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();

    _blobAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _blobAnimationController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  // Returns to Login and clears every recovery screen from the stack,
  // keeping only the Welcome screen underneath.
  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginView()),
      (route) => route.isFirst,
    );
  }

  // Fades and slides a child in during [start]..[end] of the entrance.
  Widget _enter({
    required double start,
    required double end,
    required Widget child,
  }) {
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToLogin();
      },
      child: Scaffold(
        backgroundColor: SynkColors.background,
        body: Stack(
          children: [
            // 1. Background animated blobs (Welcome screen treatment).
            AnimatedBuilder(
              animation: _blobAnimationController,
              builder: (context, _) {
                final anim = _blobAnimationController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -60 + (anim * 24),
                      left: -40 + (anim * 20),
                      child: _buildBlob(SynkColors.teal, 280),
                    ),
                    Positioned(
                      bottom: -80 - (anim * 28),
                      right: -50 - (anim * 18),
                      child: _buildBlob(SynkColors.orange, 320),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.45 +
                          (anim * 18),
                      right: 40 - (anim * 24),
                      child: _buildBlob(SynkColors.orange, 120),
                    ),
                  ],
                );
              },
            ),

            // 2. Gaussian blur layer.
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: const SizedBox.expand(),
              ),
            ),

            // 3. Content.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeader(),
                    const Spacer(flex: 2),

                    _enter(
                      start: 0.0,
                      end: 0.6,
                      child: const Center(
                        child: PuzzlePieceTile(
                          state: PieceState.connected,
                          size: 96,
                          badgeIcon: Icons.check_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    _enter(
                      start: 0.15,
                      end: 0.75,
                      child: const Column(
                        children: [
                          Text(
                            "You're back in.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              letterSpacing: -1.4,
                              color: SynkColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Your new password is set. Log in to pick up where you left off.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: SynkColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Primary action: same gradient pill as Welcome's Sign Up.
                    _enter(
                      start: 0.35,
                      end: 1.0,
                      child: GestureDetector(
                        onTap: _goToLogin,
                        child: Container(
                          height: 56,
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
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Log In',
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
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Logo tile + wordmark, as on Welcome (no back button here).
  Widget _buildHeader() {
    return Row(
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
      ],
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
}