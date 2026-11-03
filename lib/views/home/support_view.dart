import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/support_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/support_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/settings_row.dart';

class SupportView extends StatefulWidget {
  const SupportView({super.key, this.controller});

  // Overridable for tests.
  final SupportController? controller;

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  late final SupportController _controller =
      widget.controller ?? SupportController();
  final _field = TextEditingController();

  static const double _padding = 16;
  static const double _gap = 12;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
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
        // The screen switches to the thank-you state.
        break;
      case SupportResult.rateLimited:
        SynkFeedback.showError(context, l10n.supportRateLimited);
      case SupportResult.failed:
        SynkFeedback.showError(context, l10n.somethingWentWrongPleaseTryAgain);
    }
  }

  Future<void> _changeEmail() async {
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SynkColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EmailSheet(initial: _controller.email ?? ''),
    );
    if (email != null) _controller.setReplyTo(email);
  }

  String? _hint(SupportCategory category) => switch (category) {
    SupportCategory.problem => context.l10n.supportBugHint,
    SupportCategory.feedback => context.l10n.supportIdeaHint,
    SupportCategory.other => context.l10n.supportOtherHint,
  };

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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _controller.sent
                      ? const _SentState(key: ValueKey('sent'))
                      : KeyedSubtree(
                          key: const ValueKey('form'),
                          child: _buildForm(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final l10n = context.l10n;
    final category = _controller.category;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_padding, 4, _padding, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 2),
                      Text(
                        l10n.supportSubtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: _gap + 4),
                      Row(
                        children: [
                          for (final (value, icon, label) in [
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
                            if (value != SupportCategory.problem)
                              const SizedBox(width: 10),
                            Expanded(
                              child: _CategoryCard(
                                icon: icon,
                                label: label,
                                selected: category == value,
                                onTap: () => _controller.setCategory(value),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // The message field takes whatever room is left.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_padding, _gap, _padding, 0),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 180),
                          child: _buildMessageField(_hint(category)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: _gap),
                        child: _Screenshots(controller: _controller),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Pinned to the bottom, and lifted above the keyboard.
        Padding(
          padding: const EdgeInsets.fromLTRB(_padding, _gap, _padding, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.email != null) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: SynkColors.textSecondary.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 4),
                _ReplyToCard(email: _controller.email!, onChange: _changeEmail),
                const SizedBox(height: 8),
              ],
              _SendButton(
                label: l10n.send,
                enabled: _controller.canSend,
                busy: _controller.isSending,
                onPressed: _send,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageField(String? hint) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: TextField(
        controller: _field,
        onChanged: _controller.setMessage,
        expands: true,
        minLines: null,
        maxLines: null,
        maxLength: SupportModel.maxLength,
        textAlignVertical: TextAlignVertical.top,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: SynkColors.textPrimary,
        ),
        // Only shows near the limit, and turns orange close to it.
        buildCounter:
            (context, {required currentLength, required isFocused, maxLength}) {
              if (currentLength <= 1500) return null;
              return Text(
                '$currentLength/$maxLength',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: currentLength > 1800
                      ? SynkColors.orangeDark
                      : SynkColors.textSecondary,
                ),
              );
            },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintMaxLines: 3,
          hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
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

  static const _duration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final color = selected ? SynkColors.orangeDark : SynkColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedScale(
        scale: selected ? 1 : 0.97,
        duration: _duration,
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: _duration,
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
              decoration: BoxDecoration(
                color: selected
                    ? SynkColors.orange.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? SynkColors.orangeDark
                      : SynkColors.textSecondary.withValues(alpha: 0.10),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    top: -8,
                    end: -2,
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: _duration,
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: SynkColors.orangeDark,
                      ),
                    ),
                  ),
                  Center(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Up to three screenshot thumbnails, then a dashed tile to add one.
class _Screenshots extends StatelessWidget {
  const _Screenshots({required this.controller});

  final SupportController controller;

  static const double _size = 88;

  @override
  Widget build(BuildContext context) {
    final shots = controller.screenshots;

    return SizedBox(
      height: _size,
      child: Row(
        children: [
          for (final shot in shots) ...[
            _Thumbnail(
              file: shot,
              onRemove: () => controller.removeScreenshot(shot),
            ),
            const SizedBox(width: 10),
          ],
          if (controller.canAddScreenshot)
            Expanded(
              child: GestureDetector(
                onTap: controller.isSending ? null : controller.addScreenshot,
                child: CustomPaint(
                  painter: _DashedBorder(
                    color: SynkColors.textSecondary.withValues(alpha: 0.45),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 28,
                          color: SynkColors.textSecondary,
                          semanticLabel: context.l10n.supportAddScreenshot,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _Screenshots._size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(file.path), fit: BoxFit.cover),
            ),
          ),
          PositionedDirectional(
            top: -6,
            end: -6,
            child: Semantics(
              button: true,
              label: context.l10n.remove,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: SynkColors.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}

class _ReplyToCard extends StatelessWidget {
  const _ReplyToCard({required this.email, required this.onChange});

  final String email;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChange,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
        // Softer than the form, since it rarely needs changing.
        child: Opacity(
          opacity: 0.75,
          child: Row(
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 20,
                color: SynkColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textSecondary,
                  ),
                ),
              ),
              Tooltip(
                message: context.l10n.supportChange,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: SynkColors.orangeDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Grey while disabled, orange with a send icon once there's enough to send.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = enabled || busy;
    final foreground = active ? Colors.white : SynkColors.textSecondary;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: active
            ? SynkColors.orangeDark
            : SynkColors.textSecondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled && !busy ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (enabled) ...[
                        Icon(Icons.send_rounded, size: 18, color: foreground),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: foreground,
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

// Shown in place of the form once the message is sent.
class _SentState extends StatelessWidget {
  const _SentState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: SynkColors.teal.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 44,
              color: SynkColors.tealText,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.supportThanksTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.supportThanksMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: SynkColors.textSecondary,
            ),
          ),
          const Spacer(),
          SettingsButton(
            label: l10n.backToHome,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }
}

class _EmailSheet extends StatefulWidget {
  const _EmailSheet({required this.initial});

  final String initial;

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  late final _field = TextEditingController(text: widget.initial);
  String? _error;

  static final _pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final value = _field.text.trim();
    if (!_pattern.hasMatch(value)) {
      setState(() => _error = context.l10n.supportInvalidEmail);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: SynkColors.textSecondary.withValues(alpha: 0.15),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportChangeEmailTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _field,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: l10n.emailAddress,
                errorText: _error,
                filled: true,
                fillColor: Colors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: const BorderSide(color: SynkColors.orange),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SettingsButton(label: l10n.save, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
