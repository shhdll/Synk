import 'package:flutter/material.dart';

import '../../controllers/delete_account_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../welcome_view.dart';
import 'widgets/settings_row.dart';

class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({super.key});

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  final _controller = DeleteAccountController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;

    if (!await _controller.checkPassword(_password.text)) {
      if (mounted && _controller.errorMessage != null) {
        SynkFeedback.showError(context, _controller.errorMessage!);
      }
      return;
    }
    if (!mounted) return;

    // The safe choice is the primary button.
    final action = await SynkDialog.destructive(
      icon: Icons.delete_outline_rounded,
      title: l10n.deleteAccountConfirmTitle,
      message: l10n.deleteAccountConfirmMessage,
      primaryLabel: l10n.keepAccount,
      secondaryLabel: l10n.deleteAccount,
    ).show(context);
    if (action != SynkDialogAction.secondary || !mounted) return;

    final ok = await _controller.deleteAccount();
    if (!mounted) return;
    if (!ok) {
      SynkFeedback.showError(context, _controller.errorMessage!);
      return;
    }
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
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      l10n.deleteAccountIntro,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 12),
                    Text(
                      l10n.deleteAccountCantUndo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.badge,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.enterPasswordToContinue,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      enableSuggestions: false,
                      autocorrect: false,
                      onChanged: (_) => _controller.clearPasswordError(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: SynkColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.password,
                        hintStyle: const TextStyle(
                          color: SynkColors.textSecondary,
                        ),
                        errorText: _controller.passwordError,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.7),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: SynkColors.textSecondary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: SynkColors.textSecondary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: SynkColors.badge,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ValueListenableBuilder(
                      valueListenable: _password,
                      builder: (context, value, _) => SettingsButton(
                        label: l10n.deleteAccount,
                        color: SynkColors.badge,
                        busy: _controller.isDeleting,
                        onPressed: value.text.isEmpty ? null : _delete,
                      ),
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
