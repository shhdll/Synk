import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../controllers/friends_controller.dart';
import '../../controllers/language_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../services/push_notification_service.dart';
import 'about_view.dart';
import 'blocked_users_view.dart';
import 'delete_account_view.dart';
import 'notification_settings_view.dart';
import 'support_view.dart';
import 'widgets/settings_row.dart';

// Opened from the gear on Profile.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final language = LanguageController.instance;
    final friends = FriendsController.instance;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SettingsHeader(title: context.l10n.settings),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  SettingsGroup(
                    title: context.l10n.preferences,
                    children: [
                      SettingsRow(
                        icon: Icons.translate_rounded,
                        iconColor: SynkColors.orangeDark,
                        title: context.l10n.language,
                        // The choice takes effect on tap; there is nothing to save.
                        trailing: ListenableBuilder(
                          listenable: language,
                          builder: (context, _) =>
                              CupertinoSlidingSegmentedControl<bool>(
                                groupValue: language.isArabic,
                                backgroundColor: SynkColors.textSecondary
                                    .withValues(alpha: 0.10),
                                thumbColor: Colors.white,
                                padding: const EdgeInsets.all(2),
                                onValueChanged: (arabic) async {
                                  if (arabic == null ||
                                      arabic == language.isArabic) {
                                    return;
                                  }
                                  await language.setLocale(
                                    Locale(arabic ? 'ar' : 'en'),
                                  );
                                  await PushNotificationService.instance
                                      .registerForCurrentUser();
                                },
                                // Each language is shown in its own name.
                                children: {
                                  false: _LanguageLabel(
                                    context.l10n.languageEnglish,
                                  ),
                                  true: _LanguageLabel(
                                    context.l10n.languageArabic,
                                  ),
                                },
                              ),
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.notifications_none_rounded,
                        iconColor: SynkColors.pink,
                        title: context.l10n.notifications,
                        onTap: () =>
                            _open(context, const NotificationSettingsView()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SettingsGroup(
                    title: context.l10n.privacy,
                    children: [
                      ListenableBuilder(
                        listenable: friends,
                        builder: (context, _) => SettingsRow(
                          icon: Icons.block_rounded,
                          iconColor: SynkColors.textSecondary,
                          title: context.l10n.blockedUsers,
                          value: friends.hasLoaded && friends.blocked.isNotEmpty
                              ? '${friends.blocked.length}'
                              : null,
                          onTap: () => _open(context, const BlockedUsersView()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SettingsGroup(
                    title: context.l10n.support,
                    children: [
                      SettingsRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        iconColor: SynkColors.teal,
                        title: context.l10n.contactSupport,
                        onTap: () => _open(context, const SupportView()),
                      ),
                      SettingsRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: SynkColors.orangeDark,
                        title: context.l10n.aboutSynk,
                        onTap: () => _open(context, const AboutView()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SettingsGroup(
                    title: context.l10n.account,
                    children: [
                      SettingsRow(
                        icon: Icons.delete_outline_rounded,
                        iconColor: SynkColors.badge,
                        title: context.l10n.deleteAccount,
                        destructive: true,
                        onTap: () => _open(context, const DeleteAccountView()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Pinned to the bottom of the screen.
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 12),
              child: AppVersionText(),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: SynkColors.textPrimary,
        ),
      ),
    );
  }
}
