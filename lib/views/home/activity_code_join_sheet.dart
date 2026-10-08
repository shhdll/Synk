import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/activity_join_controller.dart';
import '../../core/constants/synk_colors.dart';

Future<void> showActivityCodeJoinSheet(
  BuildContext context,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return const ActivityCodeJoinSheet();
    },
  );
}

class ActivityCodeJoinSheet extends StatefulWidget {
  const ActivityCodeJoinSheet({super.key});

  @override
  State<ActivityCodeJoinSheet> createState() {
    return _ActivityCodeJoinSheetState();
  }
}

class _ActivityCodeJoinSheetState
    extends State<ActivityCodeJoinSheet> {
  late final ActivityJoinController _controller;

  @override
  void initState() {
    super.initState();

    _controller = ActivityJoinController();
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _controller.result;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          24,
          12,
          24,
          28,
        ),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(
                    alpha: 0.20,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          SynkColors.orangeDark.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: SynkColors.orangeDark,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join with a code',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color:
                                SynkColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Enter the 6-digit activity code.',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                SynkColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller.codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) {
                  _controller.clearFeedback();
                },
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  color: SynkColors.textPrimary,
                ),
                cursorColor: SynkColors.orangeDark,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color:
                        SynkColors.textSecondary.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  counterText: '',
                  errorText: _controller.errorMessage,
                  filled: true,
                  fillColor:
                      Colors.white.withValues(alpha: 0.78),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: SynkColors.textSecondary
                          .withValues(alpha: 0.14),
                    ),
                  ),
                  focusedBorder:
                      const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(18),
                    ),
                    borderSide: BorderSide(
                      color: SynkColors.orangeDark,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(18),
                    ),
                    borderSide: BorderSide(
                      color: Colors.redAccent,
                    ),
                  ),
                  focusedErrorBorder:
                      const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(18),
                    ),
                    borderSide: BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 14),
                _ResultMessage(
                  message: result.message,
                  result: result.result,
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _controller.isLoading
                      ? null
                      : _controller.joinByCode,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        SynkColors.orangeDark,
                    disabledBackgroundColor:
                        SynkColors.orangeDark.withValues(
                      alpha: 0.45,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                  child: _controller.isLoading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Join Activity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
}

class _ResultMessage extends StatelessWidget {
  const _ResultMessage({
    required this.message,
    required this.result,
  });

  final String message;
  final String result;

  @override
  Widget build(BuildContext context) {
    final isPending =
        result == 'pending' ||
        result == 'already_pending';

    final isWaitlisted =
        result == 'waitlisted' ||
        result == 'already_waitlisted';

    final color = isPending || isWaitlisted
        ? const Color(0xFFE89B26)
        : const Color(0xFF2E9B69);

    final icon = isPending
        ? Icons.schedule_rounded
        : isWaitlisted
            ? Icons.groups_rounded
            : Icons.check_circle_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}