import 'package:flutter/material.dart';

import '../../controllers/delete_account_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../welcome_view.dart';
import 'widgets/settings_row.dart';

// What gets removed, with the delete button at the bottom. Tapping it asks
// for the password, then to confirm, then deletes.
class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({super.key});

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  final _controller = DeleteAccountController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SynkColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PasswordSheet(controller: _controller),
    );
    if (deleted != true || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (Icons.person_outline_rounded, l10n.deleteAccountItemProfile),
      (Icons.event_outlined, l10n.deleteAccountItemActivities),
      (Icons.chat_bubble_outline_rounded, l10n.deleteAccountItemChats),
      (Icons.people_outline_rounded, l10n.deleteAccountItemFriends),
    ];

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SettingsHeader(title: l10n.deleteAccount),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: SynkColors.badge.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 36,
                        color: SynkColors.badge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.deleteAccountConfirmTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.deleteAccountIntro,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SettingsGroup(
                    children: [
                      for (final (icon, label) in items)
                        SettingsRow(
                          icon: icon,
                          iconColor: SynkColors.badge,
                          title: label,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.deleteAccountCantUndo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SynkColors.badge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsButton(
                    label: l10n.deleteAccount,
                    color: SynkColors.badge,
                    onPressed: _delete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The password, then a red popup to confirm, then the account is deleted.
// Pops true once it's gone.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.controller});

  final DeleteAccountController controller;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _password = TextEditingController();
  bool _obscure = true;

  DeleteAccountController get _controller => widget.controller;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    if (!await _controller.checkPassword(_password.text)) {
      if (mounted && _controller.errorMessage != null) {
        SynkFeedback.showError(context, _controller.errorMessage!);
      }
      return;
    }
    if (!mounted) return;
    final l10n = context.l10n;
    final delete = await SynkDialog.confirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: l10n.deleteAccountConfirmTitle,
      message: l10n.deleteAccountConfirmMessage,
      action: l10n.deleteLabel,
      red: true,
    );
    if (!delete || !mounted) return;
    final ok = await _controller.deleteAccount();
    if (!mounted) return;
    if (!ok) {
      SynkFeedback.showError(context, _controller.errorMessage!);
      return;
    }
    Navigator.of(context).pop(true);
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
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.enterPasswordToContinue,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                autofocus: true,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                onChanged: (_) => _controller.clearPasswordError(),
                onSubmitted: (_) => _confirm(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: SynkColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.password,
                  hintStyle: const TextStyle(color: SynkColors.textSecondary),
                  errorText: _controller.passwordError,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(
                      color: SynkColors.badge,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder(
                valueListenable: _password,
                builder: (context, value, _) => SettingsButton(
                  label: l10n.deleteAccount,
                  color: SynkColors.badge,
                  busy: _controller.isDeleting,
                  onPressed: value.text.isEmpty ? null : _confirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
