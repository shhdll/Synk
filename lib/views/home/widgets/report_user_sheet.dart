import 'package:flutter/material.dart';

import '../../../controllers/friends_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/friends_model.dart';
import '../../../models/reports_model.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';

// Reports someone in two steps, laid out like the report flows in the big
// social apps: a plain list of reasons, then details and send, optionally
// blocking them in the same step.
Future<void> showReportUserSheet({
  required BuildContext context,
  required FriendUser user,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReportUserSheet(user: user),
  );
}

// Same flow for an activity, without the block option.
Future<void> showReportActivitySheet({
  required BuildContext context,
  required String activityId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReportUserSheet(activityId: activityId),
  );
}

class ReportUserSheet extends StatefulWidget {
  const ReportUserSheet({super.key, this.user, this.activityId})
    : assert((user == null) != (activityId == null));

  final FriendUser? user;
  final String? activityId;

  @override
  State<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<ReportUserSheet> {
  static const _maxDetailsLength = 1000;

  final ReportsModel _reports = ReportsModel();
  final TextEditingController _details = TextEditingController();

  // Null on the first step, where the reason is picked.
  ReportReason? _reason;
  bool _isSubmitting = false;
  // Which button is busy, so only that one shows the spinner.
  bool _submittingWithBlock = false;

  bool get _isActivity => widget.activityId != null;

  String get _firstName => widget.user?.name.split(' ').first ?? '';

  // "Something else" needs an explanation.
  bool get _detailsRequired => _reason == ReportReason.other;

  bool get _canSubmit =>
      _reason != null &&
      !_isSubmitting &&
      (!_detailsRequired || _details.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _details.addListener(_onDetailsChanged);
  }

  void _onDetailsChanged() {
    if (_detailsRequired) setState(() {});
  }

  void _backToReasons() {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _reason = null);
  }

  Future<void> _submit({required bool block}) async {
    final reason = _reason;
    if (reason == null || !_canSubmit) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submittingWithBlock = block;
    });

    String result;
    try {
      final details = _details.text.trim();
      result = _isActivity
          ? await _reports.reportActivity(
              activityId: widget.activityId!,
              reason: reason,
              details: details.isEmpty ? null : details,
            )
          : await _reports.reportUser(
              userId: widget.user!.id,
              reason: reason,
              details: details.isEmpty ? null : details,
            );
    } catch (_) {
      result = '';
    }

    if (!mounted) return;

    if (result != 'reported' && result != 'already_reported') {
      setState(() => _isSubmitting = false);
      SynkFeedback.showError(
        context,
        context.l10n.somethingWentWrongPleaseTryAgain,
      );
      return;
    }

    // An earlier open report still counts, so blocking goes ahead either way.
    final blocked =
        block && await FriendsController.instance.block(widget.user!);

    if (!mounted) return;

    // The toast sits on the root overlay, so it outlives this sheet.
    final l10n = context.l10n;
    if (block && !blocked) {
      SynkFeedback.showError(context, l10n.somethingWentWrongPleaseTryAgain);
    } else {
      SynkFeedback.showToast(
        context,
        title: blocked
            ? l10n.reportedAndBlockedName(_firstName)
            : result == 'already_reported'
            ? (_isActivity
                  ? l10n.alreadyReportedActivity
                  : l10n.alreadyReportedName(_firstName))
            : l10n.reportSent,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _details.removeListener(_onDetailsChanged);
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // A fixed height, as in the big apps, that shrinks for the keyboard.
    final height = (media.size.height * 0.88).clamp(
      0.0,
      media.size.height - keyboard - media.padding.top - 8,
    );

    // System back on the details step returns to the reasons.
    return PopScope(
      canPop: reason == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToReasons();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: SynkColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _Header(onBack: reason == null ? null : _backToReasons),
              const Divider(height: 1, thickness: 0.5, color: _hairline),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: reason == null
                      ? _ReasonStep(
                          key: const ValueKey('reasons'),
                          firstName: _firstName,
                          isActivity: _isActivity,
                          onPick: (picked) => setState(() => _reason = picked),
                        )
                      : _buildDetailsStep(reason, media.padding.bottom),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep(ReportReason reason, double bottomInset) {
    final l10n = context.l10n;

    return Column(
      key: const ValueKey('details'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              Text(
                _reasonLabel(context, reason, isActivity: _isActivity),
                style: _headingStyle,
              ),
              const SizedBox(height: 6),
              Text(
                _detailsRequired
                    ? l10n.reportDetailsRequiredHint
                    : l10n.reportDetailsHint,
                style: _noteStyle,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _details,
                enabled: !_isSubmitting,
                autofocus: _detailsRequired,
                minLines: 6,
                maxLines: null,
                maxLength: _maxDetailsLength,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: SynkColors.textPrimary,
                ),
                cursorColor: SynkColors.orangeDark,
                decoration: InputDecoration(
                  counterStyle: _noteStyle,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.78),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: SynkColors.orangeDark,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Pinned to the bottom, above the keyboard.
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetButton(
                label: l10n.submitReport,
                background: SynkColors.orangeDark,
                foreground: Colors.white,
                busy: _isSubmitting && !_submittingWithBlock,
                onPressed: _canSubmit ? () => _submit(block: false) : null,
              ),
              if (!_isActivity) ...[
                const SizedBox(height: 8),
                _SheetButton(
                  label: l10n.reportAndBlockName(_firstName),
                  background: SynkColors.badge.withValues(alpha: 0.10),
                  foreground: SynkColors.badge,
                  busy: _isSubmitting && _submittingWithBlock,
                  onPressed: _canSubmit ? () => _submit(block: true) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// textSecondary at 18%, as a constant.
const _hairline = Color(0x2E6B7280);

const _headingStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  height: 1.3,
  color: SynkColors.textPrimary,
);

const _noteStyle = TextStyle(
  fontSize: 13,
  height: 1.4,
  color: SynkColors.textSecondary,
);

String _reasonLabel(
  BuildContext context,
  ReportReason reason, {
  bool isActivity = false,
}) {
  final l = context.l10n;
  return switch (reason) {
    ReportReason.harassment => l.reportReasonHarassment,
    ReportReason.spam => l.reportReasonSpam,
    ReportReason.fakeProfile =>
      isActivity ? l.reportReasonMisleading : l.reportReasonFakeProfile,
    ReportReason.inappropriateContent => l.reportReasonInappropriateContent,
    ReportReason.other => l.reportReasonOther,
  };
}

// The first step: a question, a short note and a plain list of reasons.
class _ReasonStep extends StatelessWidget {
  const _ReasonStep({
    super.key,
    required this.firstName,
    required this.isActivity,
    required this.onPick,
  });

  final String firstName;
  final bool isActivity;
  final ValueChanged<ReportReason> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isActivity
                    ? context.l10n.reportActivityWhy
                    : context.l10n.reportWhyName(firstName),
                style: _headingStyle,
              ),
              const SizedBox(height: 6),
              Text(
                isActivity
                    ? context.l10n.reportActivityMessage
                    : context.l10n.reportUserMessage(firstName),
                style: _noteStyle,
              ),
            ],
          ),
        ),
        for (final reason in ReportReason.values) ...[
          InkWell(
            onTap: () => onPick(reason),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 12, 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _reasonLabel(context, reason, isActivity: isActivity),
                      style: const TextStyle(
                        fontSize: 15,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: Color(0xFFB0B0B0),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: _hairline),
        ],
      ],
    );
  }
}

// "Report" centered, with a back chevron on the details step.
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            context.l10n.reportTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SynkColors.textPrimary,
            ),
          ),
          if (onBack != null)
            PositionedDirectional(
              start: 4,
              child: IconButton(
                tooltip: context.l10n.back,
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: SynkColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(
            alpha: background.a * 0.45,
          ),
          disabledForegroundColor: foreground.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foreground,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
