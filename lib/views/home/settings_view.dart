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
import 'widgets/section_label.dart';
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
                  _Card(
                    title: context.l10n.language,
                    // The choice takes effect on tap; there is nothing to save.
                    child: ListenableBuilder(
                      listenable: language,
                      builder: (context, _) => Column(
                        children: [
                          _LanguageOption(
                            badge: 'A',
                            // Each language is shown in its own name.
                            label: context.l10n.languageEnglish,
                            selected: !language.isArabic,
                            onTap: () async {
                              await language.setLocale(const Locale('en'));
                              await PushNotificationService.instance
                                  .registerForCurrentUser();
                            },
                          ),
                          const SizedBox(height: 10),
                          _LanguageOption(
                            badge: 'ع',
                            label: context.l10n.languageArabic,
                            selected: language.isArabic,
                            onTap: () async {
                              await language.setLocale(const Locale('ar'));
                              await PushNotificationService.instance
                                  .registerForCurrentUser();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SettingsGroup(
                    title: context.l10n.preferences,
                    children: [
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
                  const SizedBox(height: 28),
                  const Center(child: AppVersionText()),
                ],
              ),
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

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel(title), const SizedBox(height: 14), child],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.badge,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String badge;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? SynkColors.orange.withValues(alpha: 0.14)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? SynkColors.orangeDark : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SynkColors.textSecondary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: SynkColors.orangeDark,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
