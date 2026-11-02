import 'package:flutter/cupertino.dart';
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
        child: Column(
          children: [
            SettingsHeader(title: l10n.contactSupport),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      l10n.supportIntro,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<SupportCategory>(
                        groupValue: _controller.category,
                        backgroundColor: SynkColors.textSecondary.withValues(
                          alpha: 0.10,
                        ),
                        thumbColor: Colors.white,
                        padding: const EdgeInsets.all(3),
                        onValueChanged: (value) {
                          if (value != null) _controller.setCategory(value);
                        },
                        children: {
                          SupportCategory.problem: _Segment(l10n.supportProblem),
                          SupportCategory.feedback: _Segment(
                            l10n.supportFeedback,
                          ),
                          SupportCategory.other: _Segment(l10n.supportOther),
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: SynkColors.textSecondary.withValues(
                            alpha: 0.10,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: TextField(
                        controller: _field,
                        onChanged: _controller.setMessage,
                        minLines: 7,
                        maxLines: 12,
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
                          hintText: _controller.category ==
                                  SupportCategory.feedback
                              ? l10n.supportFeedbackHint
                              : l10n.supportProblemHint,
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
                    if (_controller.email != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 16,
                            color: SynkColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.supportReplyTo(_controller.email!),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: SynkColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    SettingsButton(
                      label: l10n.send,
                      busy: _controller.isSending,
                      onPressed: _controller.canSend ? _send : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: SynkColors.textPrimary,
        ),
      ),
    );
  }
}
