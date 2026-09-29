import 'package:flutter/material.dart';

import '../../controllers/edit_interests_controller.dart';
import '../../core/constants/interest_emojis.dart';
import '../../core/constants/synk_colors.dart';
import '../../utils/custom_widgets/synk_feedback.dart';

class EditInterestsView extends StatefulWidget {
  const EditInterestsView({super.key, required this.initialInterests});

  final List<String> initialInterests;

  @override
  State<EditInterestsView> createState() => _EditInterestsViewState();
}

class _EditInterestsViewState extends State<EditInterestsView> {
  late final EditInterestsController _controller = EditInterestsController(
    initialInterests: widget.initialInterests,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Back / exit
  // ---------------------------------------------------------------------------

  Future<void> _handleBack() async {
    if (_controller.isSaving) {
      return;
    }

    if (_controller.hasUnsavedChanges &&
        !await SynkFeedback.confirmDiscardChanges(context)) {
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    try {
      await _controller.save();
    } catch (_) {
      if (!mounted) return;
      SynkFeedback.showError(context, 'Unable to save. Please try again.');
      return;
    }

    if (!mounted) return;
    await SynkFeedback.showSaved(context);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final selected = _controller.selected;
        final available = kInterestEmojis.keys
            .where((interest) => !selected.contains(interest))
            .toList();

        final isSaving = _controller.isSaving;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }

            await _handleBack();
          },
          child: Scaffold(
            backgroundColor: SynkColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _handleBack,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Edit Interests',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        const Text(
                          'Your interests',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (selected.isEmpty)
                          const Text(
                            'Tap an interest below to add it.',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: SynkColors.textSecondary,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 12,
                            children: selected
                                .map(
                                  (interest) => _SelectedChip(
                                    interest: interest,
                                    emoji: kInterestEmojis[interest],
                                    onRemove: () =>
                                        _controller.toggle(interest),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 28),
                        const Text(
                          'Add more',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (available.isEmpty)
                          const Text(
                            "You've added every interest.",
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: SynkColors.textSecondary,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: available
                                .map(
                                  (interest) => _AvailableChip(
                                    interest: interest,
                                    emoji: kInterestEmojis[interest],
                                    onTap: () => _controller.toggle(interest),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  _buildSaveBar(isSaving),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveBar(bool isSaving) {
    final canSave = _controller.hasUnsavedChanges && !isSaving;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: SynkColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: SynkColors.orangeDark,
            foregroundColor: Colors.white,
            disabledBackgroundColor: SynkColors.orangeDark.withValues(
              alpha: 0.45,
            ),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Save',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.interest,
    required this.emoji,
    required this.onRemove,
  });

  final String interest;
  final String? emoji;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: SynkColors.orange.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: SynkColors.orange),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(
                interest,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: SynkColors.background, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: SynkColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailableChip extends StatelessWidget {
  const _AvailableChip({
    required this.interest,
    required this.emoji,
    required this.onTap,
  });

  final String interest;
  final String? emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: SynkColors.textSecondary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              interest,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.add_rounded,
              size: 14,
              color: SynkColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
