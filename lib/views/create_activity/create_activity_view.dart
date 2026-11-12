import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'step_basics.dart';
import 'step_details.dart';
import 'step_review.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'activity_rejected_dialog.dart';
import 'pending_activity_save_prompt.dart';

class CreateActivityOutcome {
  const CreateActivityOutcome({required this.activity});

  final Activity activity;
}

// The Create Activity wizard shell.

class CreateActivityView extends StatefulWidget {
  const CreateActivityView({
    super.key,
    this.store,
    this.activity,
    this.initialTitle,
  });

  final ActivityStore? store;
  final Activity? activity;

  // New activities only, e.g. what the user searched for on Home.
  final String? initialTitle;

  @override
  State<CreateActivityView> createState() => _CreateActivityViewState();
}

class _CreateActivityViewState extends State<CreateActivityView> {
  static const int _stepCount = 3;

  List<String> get _stepTitles => <String>[
    context.l10n.whatWhereAndWhen,
    context.l10n.details,
    context.l10n.review,
  ];

  late final CreateActivityController _controller;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _controller = CreateActivityController(
      activity: widget.activity,
      store: widget.store,
    );
    final title = widget.initialTitle?.trim();
    if (widget.activity == null && title != null && title.isNotEmpty) {
      _controller.titleController.text = title;
    }
    _controller.addListener(_onControllerChanged);
    unawaited(_controller.refreshConfirmedParticipantCount());
    // A save that never got an answer (the app closed, or the connection
    // dropped) is offered before starting a new one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(offerPendingActivitySave(context, store: widget.store));
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

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

    final discard = await SynkDialog.confirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: context.l10n.discardActivity,
      action: context.l10n.discard,
    );

    if (!mounted) return;
    // A submit could have started while the dialog was open; never pop over one.
    if (_controller.isSubmitting) return;
    if (discard) {
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
      // Changed on another device: show the latest version, edit again.
      final Activity? latest = result.latestActivity;
      if (latest != null) {
        widget.store?.upsert(latest);
        await SynkFeedback.showErrorDialog(
          context,
          title: context.l10n.editActivity,
          message: context.l10n.activityChangedElsewhere,
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // Deleted, or no longer theirs: nothing left to edit.
      if (result.closeEditor) {
        await SynkFeedback.showErrorDialog(
          context,
          title: context.l10n.editActivity,
          message:
              _controller.errorMessage ?? context.l10n.activityNoLongerExists,
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // Back to the first step, where the error shows under Time.
      if (_controller.hasScheduleConflict) {
        _controller.goToStep(0);
        return;
      }
      if (_controller.hasCapacityConflict) {
        await _controller.refreshConfirmedParticipantCount();
        if (!mounted) return;
        await SynkFeedback.showErrorDialog(
          context,
          title: context.l10n.editActivity,
          message:
              _controller.errorMessage ??
              context.l10n.capacityBelowParticipants,
        );
        return;
      }
      // Inappropriate content: back to the step with the first flagged
      // field, which is highlighted there, and explain the guidelines.
      // Failed checks (moderation unavailable) keep the retry message below.
      final int? flaggedStep = _controller.firstFlaggedStep;
      if (flaggedStep != null) _controller.goToStep(flaggedStep);
      if (_controller.hasFlaggedContent) {
        await showActivityRejectedDialog(
          context,
          fields: _controller.flaggedFields,
        );
        return;
      }
      _showMessage(
        _controller.errorMessage ??
            (_controller.isEditing
                ? context.l10n.weCouldntSaveYourChanges
                : context.l10n.weCouldntCreateYourActivityPlease),
      );
      return;
    }

    final Activity activity = result.activity!;
    widget.store?.upsert(activity);

    // A short success banner, then the caller opens the activity itself.
    // It slides down from the top so the activity sheet doesn't cover it.
    // Editing gets its own message from My Activities.
    if (!_controller.isEditing) {
      SynkFeedback.showToast(context, title: context.l10n.activityCreated);
    }
    Navigator.of(context).pop(CreateActivityOutcome(activity: activity));
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
                  // Directional, so the gaps stay even in Arabic too.
                  padding: EdgeInsetsDirectional.only(
                    end: index == _stepCount - 1 ? 0 : 8,
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
                    // The content check and the save happen now.
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          if (isLastStep) ...<Widget>[
                            const SizedBox(width: 10),
                            Text(
                              context.l10n.checkingActivity,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            isLastStep
                                ? (_controller.isEditing
                                      ? context.l10n.saveChanges
                                      : context.l10n.createActivity)
                                : context.l10n.continueButton,
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
