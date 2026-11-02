import 'package:flutter/material.dart';

import '../../controllers/support_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/support_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/settings_row.dart';

class SupportView extends StatefulWidget {
  const SupportView({super.key});

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  final _controller = SupportController();
  final _field = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _field.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final result = await _controller.send();
    if (!mounted) return;
    final l10n = context.l10n;

    switch (result) {
      case SupportResult.sent:
        SynkFeedback.showToast(
          context,
          title: l10n.supportSentTitle,
          message: l10n.supportSentMessage,
        );
        Navigator.of(context).pop();
      case SupportResult.rateLimited:
        SynkFeedback.showError(context, l10n.supportRateLimited);
      case SupportResult.failed:
        SynkFeedback.showError(context, l10n.somethingWentWrongPleaseTryAgain);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            children: [
              SettingsHeader(title: l10n.contactSupport),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      l10n.supportTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        for (final (category, icon, label) in [
                          (
                            SupportCategory.problem,
                            Icons.bug_report_outlined,
                            l10n.supportProblem,
                          ),
                          (
                            SupportCategory.feedback,
                            Icons.lightbulb_outline_rounded,
                            l10n.supportFeedback,
                          ),
                          (
                            SupportCategory.other,
                            Icons.waving_hand_outlined,
                            l10n.supportOther,
                          ),
                        ]) ...[
                          if (category != SupportCategory.problem)
                            const SizedBox(width: 10),
                          Expanded(
                            child: _CategoryCard(
                              icon: icon,
                              label: label,
                              selected: _controller.category == category,
                              onTap: () => _controller.setCategory(category),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: SynkColors.textSecondary.withValues(
                            alpha: 0.10,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _field,
                        onChanged: _controller.setMessage,
                        minLines: 6,
                        maxLines: null,
                        maxLength: SupportModel.maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: SynkColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l10n.supportIntro,
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9CA3AF),
                          ),
                          counterStyle: const TextStyle(
                            fontSize: 12,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Pinned to the bottom, and lifted above the keyboard.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.email != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 15,
                            color: SynkColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.supportReplyTo(_controller.email!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: SynkColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    SettingsButton(
                      label: l10n.send,
                      busy: _controller.isSending,
                      onPressed: _controller.hasText ? _send : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SynkColors.orangeDark : SynkColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? SynkColors.orange.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? SynkColors.orangeDark
                    : SynkColors.textSecondary.withValues(alpha: 0.10),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? SynkColors.orangeDark
                        : SynkColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
