import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';
import '../core/constants/synk_colors.dart';

import '../controllers/signup_controller.dart';
import 'signup/personal_details_slide.dart';
import 'signup/account_setup_slide.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with SingleTickerProviderStateMixin {
  late final OnboardingController _controller;
  late final SignupController _signupController;
  late final AnimationController _blobAnimationController;
  late final PageController _pageController;

  static const List<Map<String, String>> _interests = [
    {'emoji': '🎾', 'label': 'Padel'},
    {'emoji': '🎲', 'label': 'Board Games'},
    {'emoji': '🏎️', 'label': 'Karting'},
    {'emoji': '🗝️', 'label': 'Escape Room'},
    {'emoji': '♟️', 'label': 'Chess'},
    {'emoji': '🧗', 'label': 'Climbing'},
    {'emoji': '🎳', 'label': 'Bowling'},
    {'emoji': '🏓', 'label': 'Table Tennis'},
    {'emoji': '⚽', 'label': 'Football'},
    {'emoji': '🏀', 'label': 'Basketball'},
    {'emoji': '🥾', 'label': 'Hiking'},
    {'emoji': '🏕️', 'label': 'Camping'},
    {'emoji': '🍳', 'label': 'Cooking'},
    {'emoji': '🍿', 'label': 'Movies'},
    {'emoji': '🎨', 'label': 'Art'},
    {'emoji': '🎤', 'label': 'Karaoke'},
  ];

  @override
  void initState() {
    super.initState();

    _controller = OnboardingController();
    _controller.addListener(_onControllerChanged);

    _signupController = SignupController();

    _pageController = PageController();
    _pageController.addListener(_onPageScrollChanged);

    _blobAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _blobAnimationController.addListener(_onAnimationChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onPageScrollChanged() {
    if (mounted) setState(() {});
  }

  void _onAnimationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();

    _signupController.dispose();

    _pageController.removeListener(_onPageScrollChanged);
    _pageController.dispose();

    _blobAnimationController.removeListener(_onAnimationChanged);
    _blobAnimationController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentStep = _controller.currentStep;

    return PopScope(
      canPop: currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && currentStep > 0) {
          _goToPreviousPage();
        }
      },
      child: Scaffold(
        backgroundColor: SynkColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildAnimatedBackground()),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      _buildHeader(),
                      const SizedBox(height: 34),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: _onPageChanged,
                          children: [
                            _buildInterestsStep(),
                            _buildActivityTypeStep(),
                            _buildLocationStep(),
                            PersonalDetailsSlide(controller: _signupController),
                            AccountSetupSlide(
                              signupController: _signupController,
                              onboardingController: _controller,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildNavigation(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/synk_logo.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Synk',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -1.2,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ANIMATED BACKGROUND
  // ---------------------------------------------------------------------------

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _blobAnimationController,
      builder: (context, _) {
        final anim = _blobAnimationController.value;
        final size = MediaQuery.of(context).size;

        final wave = math.sin(anim * math.pi);
        final reverseWave = math.cos(anim * math.pi);

        final page = _pageController.hasClients
            ? (_pageController.page ?? _controller.currentStep.toDouble())
            : _controller.currentStep.toDouble();

        final clampedPage = page.clamp(0.0, 4.0);

        final lowerStep = clampedPage.floor();
        final upperStep = clampedPage.ceil();
        final pageProgress = clampedPage - lowerStep;

        final firstLayout = _blobLayoutForStep(
          lowerStep,
          size,
          wave,
          reverseWave,
        );

        final secondLayout = _blobLayoutForStep(
          upperStep,
          size,
          wave,
          reverseWave,
        );

        final layout = _BlobLayout.lerp(
          firstLayout,
          secondLayout,
          pageProgress,
        );

        return Stack(
          children: [
            Positioned(
              top: layout.pinkTop,
              left: layout.pinkLeft,
              child: _buildBlob(
                SynkColors.pink,
                _diameterForBlob(clampedPage, 0),
              ),
            ),

            Positioned(
              bottom: layout.orangeBottom,
              right: layout.orangeRight,
              child: _buildBlob(
                SynkColors.orange,
                _diameterForBlob(clampedPage, 1),
              ),
            ),

            Positioned(
              top: layout.smallTop,
              right: layout.smallRight,
              child: _buildBlob(
                _smallBlobColor(clampedPage),
                _smallBlobDiameter(clampedPage),
              ),
            ),

            Positioned(
              bottom: layout.tealBottom,
              left: layout.tealLeft,
              child: _buildBlob(SynkColors.teal, _tealDiameter(clampedPage)),
            ),

            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }

  double _diameterForBlob(double page, int blob) {
    final step = page.round();

    if (blob == 0) {
      return step == 1 ? 310 : 280;
    }

    return step == 2 ? 350 : 320;
  }

  Color _smallBlobColor(double page) {
    final progress = page.clamp(0.0, 4.0);

    if (progress <= 1.0) {
      return Color.lerp(SynkColors.orange, SynkColors.pink, progress)!;
    }

    if (progress <= 2.0) {
      return Color.lerp(SynkColors.pink, SynkColors.orange, progress - 1.0)!;
    }

    return SynkColors.orange;
  }

  double _smallBlobDiameter(double page) {
    if (page >= 1.0 && page <= 2.0) {
      final progress = page - 1.0;
      return 120 + (20 * progress);
    }

    if (page > 2.0) {
      return 140;
    }

    return 120;
  }

  double _tealDiameter(double page) {
    if (page < 1.0) {
      return 150;
    }

    if (page < 2.0) {
      return 150 + ((page - 1.0) * 30);
    }

    return 135;
  }

  _BlobLayout _blobLayoutForStep(
    int step,
    Size screenSize,
    double wave,
    double reverseWave,
  ) {
    final width = screenSize.width;
    final height = screenSize.height;

    switch (step) {
      case 0:
        return _BlobLayout(
          pinkTop: -70 + (wave * 35),
          pinkLeft: -55 + (reverseWave * 30),
          orangeBottom: -90 - (wave * 30),
          orangeRight: -60 - (reverseWave * 25),
          smallTop: height * 0.45 + (wave * 25),
          smallRight: 35 - (reverseWave * 30),
          tealBottom: height * 0.20 - (wave * 25),
          tealLeft: 70 + (reverseWave * 35),
        );

      case 1:
        return _BlobLayout(
          pinkTop: 80 + (reverseWave * 45),
          pinkLeft: width - 170 + (wave * 40),
          orangeBottom: height * 0.28 + (wave * 35),
          orangeRight: 80 - (reverseWave * 40),
          smallTop: height * 0.62 - (wave * 35),
          smallRight: width * 0.55 + (reverseWave * 30),
          tealBottom: -40 + (wave * 30),
          tealLeft: -45 + (reverseWave * 50),
        );

      case 2:
        return _BlobLayout(
          pinkTop: -100 + (wave * 50),
          pinkLeft: width * 0.35 - (reverseWave * 55),
          orangeBottom: -40 - (reverseWave * 45),
          orangeRight: width * 0.20 + (wave * 35),
          smallTop: height * 0.25 + (reverseWave * 45),
          smallRight: -20 + (wave * 50),
          tealBottom: height * 0.40 - (wave * 35),
          tealLeft: width * 0.50 + (reverseWave * 45),
        );

      case 3:
        return _BlobLayout(
          pinkTop: height * 0.15 + (wave * 40),
          pinkLeft: -70 + (reverseWave * 45),
          orangeBottom: height * 0.05 - (wave * 40),
          orangeRight: -70 - (reverseWave * 35),
          smallTop: height * 0.55 + (reverseWave * 35),
          smallRight: width * 0.25 + (wave * 35),
          tealBottom: -40 + (wave * 25),
          tealLeft: width * 0.55 - (reverseWave * 40),
        );

      case 4:
        return _BlobLayout(
          pinkTop: -80 + (reverseWave * 40),
          pinkLeft: width * 0.55 + (wave * 35),
          orangeBottom: height * 0.20 + (wave * 35),
          orangeRight: width * 0.35 - (reverseWave * 45),
          smallTop: height * 0.50 - (wave * 30),
          smallRight: -30 + (reverseWave * 45),
          tealBottom: height * 0.05 - (wave * 30),
          tealLeft: -50 + (reverseWave * 35),
        );

      default:
        return _BlobLayout(
          pinkTop: -70,
          pinkLeft: -55,
          orangeBottom: -90,
          orangeRight: -60,
          smallTop: height * 0.45,
          smallRight: 35,
          tealBottom: height * 0.20,
          tealLeft: 70,
        );
    }
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

  // ---------------------------------------------------------------------------
  // PAGE 1 — INTERESTS
  // ---------------------------------------------------------------------------

  Widget _buildInterestsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What are you into?',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -1.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pick the activities you enjoy.',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: SynkColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _interests.map(_buildInterestChip).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestChip(Map<String, String> interest) {
    final label = interest['label']!;
    final emoji = interest['emoji']!;
    final isSelected = _controller.selectedInterests.contains(label);

    return GestureDetector(
      onTap: () => _controller.toggleInterest(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? SynkColors.orange.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? SynkColors.orange
                : Colors.white.withValues(alpha: 0.65),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: SynkColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 2 — INDOOR / OUTDOOR
  // ---------------------------------------------------------------------------

  Widget _buildActivityTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where do you like to have fun?',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -1.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tell us what kind of activities you prefer.',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: SynkColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 30),
        _buildChoiceCard(
          emoji: '🏠',
          title: 'Indoor',
          value: 'Indoor',
          selectedValue: _controller.activityType,
          onTap: () => _controller.setActivityType('Indoor'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🌳',
          title: 'Outdoor',
          value: 'Outdoor',
          selectedValue: _controller.activityType,
          onTap: () => _controller.setActivityType('Outdoor'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🤙🏻',
          title: 'I don’t mind',
          value: 'I don’t mind',
          selectedValue: _controller.activityType,
          onTap: () => _controller.setActivityType('I don’t mind'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 3 — LOCATION
  // ---------------------------------------------------------------------------

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How far are you willing to go?',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -1.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose how close you want your activities to be.',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: SynkColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 30),
        _buildChoiceCard(
          emoji: '🏙️',
          title: 'In the city',
          value: 'In the city',
          selectedValue: _controller.locationPreference,
          onTap: () => _controller.setLocationPreference('In the city'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🛣️',
          title: 'Away from the city',
          value: 'Away from the city',
          selectedValue: _controller.locationPreference,
          onTap: () => _controller.setLocationPreference('Away from the city'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🤙🏻',
          title: 'I don’t mind',
          value: 'I don’t mind',
          selectedValue: _controller.locationPreference,
          onTap: () => _controller.setLocationPreference('I don’t mind'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 4 — INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildInfoStep() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 5 — FINAL INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildFinalStep() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [],
      ),
    );
  }

  Widget _buildInfoCard({
    required String emoji,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.70),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: SynkColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHOICE CARD
  // ---------------------------------------------------------------------------

  Widget _buildChoiceCard({
    required String emoji,
    required String title,
    required String value,
    required String? selectedValue,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedValue == value;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? SynkColors.orange.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? SynkColors.orange
                : Colors.white.withValues(alpha: 0.70),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 23)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: SynkColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE CHANGES
  // ---------------------------------------------------------------------------

  void _onPageChanged(int page) {
    if (_controller.currentStep != page) {
      _controller.goToStep(page);
    }
  }

  Future<void> _goToNextPage() async {
    // 1. If on Slide 4 (Personal Details), validate name, age, and gender first
    if (_controller.currentStep == 3) {
      final isValid = _signupController.validatePersonalDetails();
      if (!isValid) return; // Halts transition and displays inline errors
    }

    // 2. Check the existing continuation guard
    if (!_canContinue()) return;

    // 3. Final step check
    if (_controller.currentStep == 4) {
      _finishOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToPreviousPage() async {
    if (_controller.currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skipQuestion() async {
    if (_controller.currentStep == 4) {
      _finishOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Widget _buildNavigation() {
    final isLastStep = _controller.currentStep == 4;
    final canContinue = _canContinue();

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _PressedCircleButton(
                  icon: Icons.arrow_back_rounded,
                  enabled: true,
                  onTap: _goToPreviousPage,
                ),
              ),
              Center(
                child: Visibility(
                  visible: _controller.currentStep < 3,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: _PressedSkipButton(onTap: _skipQuestion),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Visibility(
                  visible: !isLastStep, // Hides the arrow on Slide 5 (Registration button submits instead)
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: _PressedCircleButton(
                    icon: Icons.arrow_forward_rounded,
                    enabled: canContinue,
                    onTap: canContinue ? _goToNextPage : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildProgress(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PROGRESS
  // ---------------------------------------------------------------------------
  Widget _buildProgress() {
    const stepCount = 5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(stepCount, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index == stepCount - 1 ? 0 : 7),
          child: _buildProgressItem(_controller.currentStep == index),
        );
      }),
    );
  }

  Widget _buildProgressItem(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: active ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? SynkColors.orange
            : SynkColors.textSecondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  bool _canContinue() {
    switch (_controller.currentStep) {
      case 0:
        return _controller.selectedInterests.isNotEmpty;

      case 1:
        return _controller.activityType != null;

      case 2:
        return _controller.locationPreference != null;

      case 3:
      case 4:
        return true;

      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // FINISH
  // ---------------------------------------------------------------------------

  void _finishOnboarding() {
    final data = _controller.onboardingData;
  }
}

// =============================================================================
// BLOB LAYOUT
// =============================================================================

class _BlobLayout {
  final double pinkTop;
  final double pinkLeft;
  final double orangeBottom;
  final double orangeRight;
  final double smallTop;
  final double smallRight;
  final double tealBottom;
  final double tealLeft;

  const _BlobLayout({
    required this.pinkTop,
    required this.pinkLeft,
    required this.orangeBottom,
    required this.orangeRight,
    required this.smallTop,
    required this.smallRight,
    required this.tealBottom,
    required this.tealLeft,
  });

  static _BlobLayout lerp(_BlobLayout a, _BlobLayout b, double t) {
    return _BlobLayout(
      pinkTop: lerpDouble(a.pinkTop, b.pinkTop, t)!,
      pinkLeft: lerpDouble(a.pinkLeft, b.pinkLeft, t)!,
      orangeBottom: lerpDouble(a.orangeBottom, b.orangeBottom, t)!,
      orangeRight: lerpDouble(a.orangeRight, b.orangeRight, t)!,
      smallTop: lerpDouble(a.smallTop, b.smallTop, t)!,
      smallRight: lerpDouble(a.smallRight, b.smallRight, t)!,
      tealBottom: lerpDouble(a.tealBottom, b.tealBottom, t)!,
      tealLeft: lerpDouble(a.tealLeft, b.tealLeft, t)!,
    );
  }
}

// =============================================================================
// PRESSED CIRCLE BUTTON
// =============================================================================

class _PressedCircleButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PressedCircleButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_PressedCircleButton> createState() => _PressedCircleButtonState();
}

class _PressedCircleButtonState extends State<_PressedCircleButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;

    if (mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: !widget.enabled
              ? Colors.white.withValues(alpha: 0.35)
              : _isPressed
              ? SynkColors.orange
              : Colors.white.withValues(alpha: 0.82),
          boxShadow: widget.enabled
              ? [
                  BoxShadow(
                    color: SynkColors.orangeDark.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Icon(
          widget.icon,
          size: 24,
          color: !widget.enabled
              ? SynkColors.textSecondary.withValues(alpha: 0.4)
              : _isPressed
              ? Colors.white
              : SynkColors.textPrimary,
        ),
      ),
    );
  }
}

// =============================================================================
// PRESSED SKIP BUTTON
// =============================================================================

class _PressedSkipButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isVisible;

  const _PressedSkipButton({required this.onTap, this.isVisible = true});

  @override
  State<_PressedSkipButton> createState() => _PressedSkipButtonState();
}

class _PressedSkipButtonState extends State<_PressedSkipButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not visible, render an empty SizedBox with identical padding/height
    // so layout alignments (dots, back/forward buttons) remain stable.
    if (!widget.isVisible) {
      return const SizedBox(
        height: 25, // Height of the text + padding
        child: SizedBox.shrink(),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 100),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _isPressed ? SynkColors.orange : SynkColors.textSecondary,
          ),
          child: const Text('Skip'),
        ),
      ),
    );
  }
}
