import 'package:flutter/material.dart';

import 'step_basics.dart';
import 'step_details.dart';
import 'step_review.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import '../../utils/custom_widgets/synk_dialog.dart';

// What the wizard hands back to whoever pushed it.
//
// [activity] is the row that was created. [openDetails] is true only when the
// user chose "View activity" in the success popup, so the caller can decide
// whether to open Activity Details (File 13) or simply return to Home. The
// wizard pops null when the user leaves without publishing.
class CreateActivityOutcome {
  const CreateActivityOutcome({
    required this.activity,
    required this.openDetails,
  });

  final Activity activity;
  final bool openDetails;
}

// The Create Activity wizard shell.
//
// Owns the three-step PageView, the progress header, the footer action button
// and the two confirmation popups. It holds no draft state of its own: every
// value lives in [CreateActivityController], and every rule (what a step needs,
// whether a submit may run) is asked of that controller rather than re-checked
// here.
class CreateActivityView extends StatefulWidget {
  const CreateActivityView({super.key, this.store});

  // Optional in-memory cache. When supplied, a created activity is added to it
  // straight away so Home does not have to refetch. Creation does not depend
  // on it — Supabase is still the source of truth.
  final ActivityStore? store;

  @override
  State<CreateActivityView> createState() => _CreateActivityViewState();
}

class _CreateActivityViewState extends State<CreateActivityView> {
  static const int _stepCount = 3;

  static const List<String> _stepTitles = <String>[
    'What, where & when',
    'Details',
    'Review',
  ];

  final CreateActivityController _controller = CreateActivityController();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Keeps the PageView in sync with the controller's step and repaints the
  // chrome (progress bar, footer label, button state).
  void _onControllerChanged() {
    if (!mounted) return;
    final int step = _controller.currentStep;
    if (_pageController.hasClients &&
        (_pageController.page ?? 0).round() != step) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  // Single entry point for the back arrow, the close button and the system
  // back gesture. While a submit is in flight nothing may step back, open the
  // discard dialog, or pop the wizard: the insert has already been sent and
  // tearing the screen down here would strand the result.
  Future<void> _handleBack() async {
    if (_controller.isSubmitting) return;

    if (_controller.currentStep > 0) {
      _controller.goToStep(_controller.currentStep - 1);
      return;
    }
    await _handleClose();
  }

  // Leaves immediately when nothing has been entered, and asks for
  // confirmation only when there is something to lose.
  Future<void> _handleClose() async {
    if (_controller.isSubmitting) return;

    if (!_controller.isDirty) {
      Navigator.of(context).pop();
      return;
    }

    final SynkDialogAction? action = await SynkDialog.destructive(
      icon: Icons.delete_outline_rounded,
      title: 'Discard activity?',
      message: "Your changes haven't been saved. If you leave now, you'll lose them.",
      primaryLabel: 'Keep editing',
      secondaryLabel: 'Discard and leave',
    ).show(context, barrierDismissible: false);

    if (!mounted) return;
    // A submit could have started while the dialog was open; never pop over one.
    if (_controller.isSubmitting) return;
    if (action == SynkDialogAction.secondary) {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Footer action
  // ---------------------------------------------------------------------------

  Future<void> _handlePrimaryAction() async {
    final int step = _controller.currentStep;

    if (step < _stepCount - 1) {
      FocusScope.of(context).unfocus();
      _controller.touchStep(step);
      if (_controller.stepBlocker(step) != null) return;
      _controller.goToStep(step + 1);
      return;
    }

    await _submit();
  }

  Future<void> _submit() async {
    // e.g. the time passed while on the review page
    if (_controller.stepBlocker(0) != null) {
      _controller.touchStep(0);
      _controller.goToStep(0);
      return;
    }
    final String? blocker = _controller.submitBlocker;
    if (blocker != null) {
      _controller.goToStep(1);
      return;
    }

    final CreateActivityResult result = await _controller.submit();
    if (!mounted) return;

    if (!result.created) {
      _showMessage(
        _controller.errorMessage ??
            "We couldn't create your activity. Please try again.",
      );
      return;
    }

    final Activity activity = result.activity!;
    widget.store?.upsert(activity);

    // Anything that went wrong after the row was created is reported inside the
    // success popup rather than swallowed — the activity exists either way.
    final List<String> warnings = <String>[
      if (result.photoWarning != null) result.photoWarning!,
      if (result.orphanWarning != null) result.orphanWarning!,
    ];
    final String message = warnings.isEmpty
        ? 'Your activity is live and ready for people to join.'
        : 'Your activity is live and ready for people to join.\n\n'
              '${warnings.join('\n')}';

    final SynkDialogAction? choice = await SynkDialog.success(
      title: 'Activity created!',
      message: message,
      primaryLabel: 'View activity',
      secondaryLabel: 'Done',
    ).show(context, barrierDismissible: false);

    if (!mounted) return;
    // The popup is not dismissible, so [choice] is one of the two actions.
    // "View activity" is the primary button; "Done" is the secondary one.
    // Anything else (a null from a future change) is treated as "Done".
    Navigator.of(context).pop(
      CreateActivityOutcome(
        activity: activity,
        openDetails: choice == SynkDialogAction.primary,
      ),
    );
  }

  void _showMessage(String text) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final int step = _controller.currentStep;
    final bool isLastStep = step == _stepCount - 1;
    final bool busy = _controller.isSubmitting;

    return PopScope(
      // Never let the framework pop on its own: _handleBack() decides whether
      // back means "previous step", "ask before discarding", or "ignore,
      // a submit is running".
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: SynkColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(step, busy),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    StepBasics(controller: _controller),
                    StepDetails(controller: _controller),
                    StepReview(controller: _controller),
                  ],
                ),
              ),
              _buildFooter(isLastStep, busy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int step, bool busy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _CircleIconButton(
                icon: step == 0
                    ? Icons.close_rounded
                    : Icons.arrow_back_ios_new_rounded,
                onTap: busy ? null : _handleBack,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _stepTitles[step],
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List<Widget>.generate(_stepCount, (int index) {
              final bool filled = index <= step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _stepCount - 1 ? 0 : 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: filled ? null : const Color(0x1F1E1C24),
                      gradient: filled
                          ? const LinearGradient(
                              colors: <Color>[
                                SynkColors.orange,
                                SynkColors.orangeDark,
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isLastStep, bool busy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: <Color>[SynkColors.orange, SynkColors.orangeDark],
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33FF7A36),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: busy ? null : _handlePrimaryAction,
              child: Center(
                child: busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            isLastStep ? 'Create activity' : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastStep
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Round white button used for back / close in the header.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? SynkColors.textSecondary
                : SynkColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
