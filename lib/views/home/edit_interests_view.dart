import 'dart:ui';

import 'package:flutter/material.dart';

import '../../controllers/edit_interests_controller.dart';
import '../../core/constants/interest_emojis.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../widgets/synk_blob_background.dart';

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
      SynkFeedback.showError(context, context.l10n.unableToSavePleaseTryAgain);
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
          child: SynkBlobPage(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        4,
                        8,
                        20,
                        8,
                      ),
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
                          Text(
                            context.l10n.editInterests,
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
                      // The list runs under the Save bar, blurred there.
                      child: Stack(
                        children: [
                          ListView(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              8,
                              24,
                              24 +
                                  _saveBarHeight +
                                  MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            children: [
                              Text(
                                context.l10n.yourInterests,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: SynkColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (selected.isEmpty)
                                Text(
                                  context.l10n.tapAnInterestBelowToAdd,
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
                              Text(
                                context.l10n.addMore,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: SynkColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (available.isEmpty)
                                Text(
                                  context.l10n.youveAddedEveryInterest,
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
                                          onTap: () =>
                                              _controller.toggle(interest),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _buildSaveBar(isSaving),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveBar(bool isSaving) {
    final canSave = _controller.hasUnsavedChanges && !isSaving;

    return _FadingBlur(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          _saveBarHeight - 54 - 16,
          24,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: canSave ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: SynkColors.orangeDark,
              foregroundColor: Colors.white,
              // The same light orange, but solid so the blur doesn't show
              // through.
              disabledBackgroundColor: Color.alphaBlend(
                SynkColors.orangeDark.withValues(alpha: 0.45),
                SynkColors.background,
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
                : Text(
                    context.l10n.save,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }
}

// Space the Save bar takes: the blur fading in above the button, the button,
// and the gap under it.
const double _saveBarHeight = 40 + 54 + 16;

// Blurs what's behind [child], from nothing at the top to fully blurred at
// the bottom. Stacked light blurs add up, so each band down is blurrier.
class _FadingBlur extends StatelessWidget {
  const _FadingBlur({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const bands = 8;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  for (var i = 0; i < bands; i++)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      top: constraints.maxHeight * 0.5 * i / bands,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
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
                valueLabel(interest),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          end: -6,
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
              valueLabel(interest),
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
