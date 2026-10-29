import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';
import '../core/constants/interest_emojis.dart';
import '../core/constants/synk_colors.dart';

import '../controllers/signup_controller.dart';
import '../l10n/l10n.dart';
import 'signup/personal_details_slide.dart';
import 'signup/account_setup_slide.dart';
import '../screens/auth/email_verification_screen.dart';
import 'home/main_shell.dart';
import 'widgets/blob_layout.dart';
import 'widgets/pressed_circle_button.dart';
import 'widgets/pressed_skip_button.dart';
import 'widgets/bottom_fade.dart';

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

  @override
  void initState() {
    super.initState();

    _controller = OnboardingController();
    _controller.addListener(_onControllerChanged);

    _signupController = SignupController();
    _signupController.addListener(_onControllerChanged);

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

    _signupController.removeListener(_onControllerChanged);
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && currentStep > 0) {
          _goToPreviousPage();
        }
      },
      child: Scaffold(
        backgroundColor: SynkColors.background,
        // Background runs under the status and navigation bars; only the
        // content stays inside the safe area.
        // Tapping outside a field closes the keyboard, which brings the
        // arrows back.
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              Positioned.fill(child: _buildAnimatedBackground()),
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        _buildHeader(),
                        const SizedBox(height: 34),
                        // The arrows float over the pages, so content scrolls
                        // under them and fades out instead of stopping at a bar.
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: PageView(
                                  controller: _pageController,
                                  physics: const BouncingScrollPhysics(),
                                  onPageChanged: _onPageChanged,
                                  children: [
                                    _buildInterestsStep(),
                                    _buildActivityTypeStep(),
                                    _buildLocationStep(),
                                    PersonalDetailsSlide(
                                      controller: _signupController,
                                    ),
                                    AccountSetupSlide(
                                      signupController: _signupController,
                                      onboardingController: _controller,
                                    ),
                                  ],
                                ),
                              ),
                              // Hidden while typing so the arrows don't cover
                              // the fields above the keyboard.
                              if (!keyboardOpen)
                                PositionedDirectional(
                                  start: 0,
                                  end: 0,
                                  bottom: 20,
                                  child: _buildNavigation(),
                                ),
                            ],
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
        const Spacer(),
        _buildStepCounter(),
      ],
    );
  }

  // Small ring in the corner that fills up as the user moves through sign up.
  Widget _buildStepCounter() {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: (_controller.currentStep + 1) / _stepCount),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: 4,
          strokeCap: StrokeCap.round,
          color: SynkColors.orange,
          backgroundColor: SynkColors.textSecondary.withValues(alpha: 0.15),
        ),
      ),
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

        final layout = BlobLayout.lerp(firstLayout, secondLayout, pageProgress);

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

  BlobLayout _blobLayoutForStep(
    int step,
    Size screenSize,
    double wave,
    double reverseWave,
  ) {
    final width = screenSize.width;
    final height = screenSize.height;

    switch (step) {
      case 0:
        return BlobLayout.intro(screenSize, wave, reverseWave);

      case 1:
        return BlobLayout(
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
        return BlobLayout(
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
        return BlobLayout(
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
        return BlobLayout(
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
        return BlobLayout(
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
        Text(
          context.l10n.whatAreYouInto,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -1.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.pickTheActivitiesYouEnjoy,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: SynkColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: BottomFade(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: BottomFade.scrollPadding),
              child: Wrap(
                spacing: 7,
                runSpacing: 8,
                children: [
                  for (final entry in kInterestEmojis.entries)
                    _buildInterestChip(entry.key, entry.value),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestChip(String label, String emoji) {
    final isSelected = _controller.selectedInterests.contains(label);

    return GestureDetector(
      onTap: () => _controller.toggleInterest(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? SynkColors.orange.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
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
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              valueLabel(label),
              style: TextStyle(
                fontSize: 13,
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
        Text(
          context.l10n.whereDoYouLikeToHave,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -1.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.tellUsWhatKindOfActivities,
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
          title: context.l10n.indoor,
          value: 'Indoor',
          selectedValue: _controller.activityType,
          onTap: () => _controller.setActivityType('Indoor'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🌳',
          title: context.l10n.outdoor,
          value: 'Outdoor',
          selectedValue: _controller.activityType,
          onTap: () => _controller.setActivityType('Outdoor'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🤙🏻',
          title: context.l10n.iDontMind,
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
        Text(
          context.l10n.howFarAreYouWillingTo,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: SynkColors.textPrimary,
            letterSpacing: -1.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.chooseHowCloseYouWantYour,
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
          title: context.l10n.inTheCity,
          value: 'In the city',
          selectedValue: _controller.locationPreference,
          onTap: () => _controller.setLocationPreference('In the city'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🛣️',
          title: context.l10n.awayFromTheCity,
          value: 'Away from the city',
          selectedValue: _controller.locationPreference,
          onTap: () => _controller.setLocationPreference('Away from the city'),
        ),
        const SizedBox(height: 10),
        _buildChoiceCard(
          emoji: '🤙🏻',
          title: context.l10n.iDontMind,
          value: 'I don’t mind',
          selectedValue: _controller.locationPreference,
          onTap: () => _controller.setLocationPreference('I don’t mind'),
        ),
      ],
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
    if (page == 4 && !_signupController.isPersonalDetailsValid) {
      _signupController.validatePersonalDetails();
      _pageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }

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
        // On the last page the submit button takes the place of Skip and the
        // next arrow.
        if (isLastStep)
          Row(
            children: [
              PressedCircleButton(
                icon: Icons.arrow_back_rounded,
                enabled: true,
                onTap: _goToPreviousPage,
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildRegisterButton()),
            ],
          )
        else
          SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PressedCircleButton(
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
                    child: PressedSkipButton(onTap: _skipQuestion),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Visibility(
                    visible: !isLastStep, // Hides the arrow on Slide 5 (Registration button submits instead)
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: PressedCircleButton(
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
  static const _stepCount = 5;

  Widget _buildProgress() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_stepCount, (index) {
        return Padding(
          padding: EdgeInsetsDirectional.only(
            end: index == _stepCount - 1 ? 0 : 7,
          ),
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
      // The first three pages are optional: with nothing picked, the arrow
      // just moves on like Skip.
      case 0:
      case 1:
      case 2:
        return true;

      case 3:
        return _signupController.isPersonalDetailsValid;

      case 4:
        return true;

      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // FINISH
  // ---------------------------------------------------------------------------

  // No-op: AccountSetupSlide (the last page) has its own "Create Account"
  // button that calls SignupController.registerUser directly, so tapping
  // Next/Skip while already on that page has nothing left to do.
  // Creates the account, then opens the app or the email check screen.
  Future<void> _finishOnboarding() async {
    final res = await _signupController.registerUser(
      onboardingPreferences: _controller.onboardingData,
      context: context,
    );
    final user = res?.user;
    if (user == null || !mounted) return;

    final isConfirmed =
        res!.session != null &&
        user.emailConfirmedAt != null &&
        user.emailConfirmedAt!.isNotEmpty;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => isConfirmed
            // Confirmation is off or the account was auto-confirmed.
            ? const MainShell()
            : EmailVerificationScreen(
                email: _signupController.emailController.text.trim(),
                password: _signupController.passwordController.text,
              ),
      ),
      (route) => false,
    );
  }

  // Submit button shown next to the back arrow on the last page.
  Widget _buildRegisterButton() {
    return ListenableBuilder(
      listenable: _signupController,
      builder: (context, _) {
        final loading = _signupController.isLoading;
        return SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6F43),
              disabledBackgroundColor: const Color(0xFFFF6F43)
                  .withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: loading ? null : _finishOnboarding,
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    context.l10n.completeRegistration,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
