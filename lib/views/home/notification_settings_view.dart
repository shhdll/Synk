import 'package:flutter/material.dart';

import '../../controllers/notification_preferences_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/notification_preferences_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'ntfy_settings_view.dart';
import 'widgets/settings_row.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  final _controller = NotificationPreferencesController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle(NotificationKind kind, bool enabled) async {
    final ok = await _controller.toggle(kind, enabled);
    if (!ok && mounted) {
      SynkFeedback.showError(
        context,
        context.l10n.somethingWentWrongPleaseTryAgain,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget row(
      NotificationKind kind,
      IconData icon,
      Color color,
      String title,
      String subtitle,
    ) {
      return SettingsRow(
        icon: icon,
        iconColor: color,
        title: title,
        subtitle: subtitle,
        trailing: Switch.adaptive(
          value: _controller.isEnabled(kind),
          activeTrackColor: SynkColors.teal,
          onChanged: (value) => _toggle(kind, value),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SettingsHeader(title: l10n.notifications),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: SynkColors.orangeDark,
                      ),
                    );
                  }
                  if (_controller.loadFailed) {
                    return Center(
                      child: TextButton(
                        onPressed: _controller.load,
                        child: Text(l10n.tryAgain),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      SettingsGroup(
                        title: l10n.activities,
                        children: [
                          row(
                            NotificationKind.reminders,
                            Icons.alarm_rounded,
                            SynkColors.orangeDark,
                            l10n.notifPrefReminders,
                            l10n.notifPrefRemindersHint,
                          ),
                          row(
                            NotificationKind.activityUpdates,
                            Icons.event_note_rounded,
                            SynkColors.teal,
                            l10n.notifPrefActivityUpdates,
                            l10n.notifPrefActivityUpdatesHint,
                          ),
                          row(
                            NotificationKind.joinRequests,
                            Icons.how_to_reg_rounded,
                            SynkColors.beigeDark,
                            l10n.notifPrefJoinRequests,
                            l10n.notifPrefJoinRequestsHint,
                          ),
                          row(
                            NotificationKind.waitlist,
                            Icons.hourglass_bottom_rounded,
                            SynkColors.pink,
                            l10n.notifPrefWaitlist,
                            l10n.notifPrefWaitlistHint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SettingsGroup(
                        title: l10n.notifPrefPeople,
                        children: [
                          row(
                            NotificationKind.friendRequests,
                            Icons.person_add_alt_1_rounded,
                            SynkColors.teal,
                            l10n.notifPrefFriendRequests,
                            l10n.notifPrefFriendRequestsHint,
                          ),
                          row(
                            NotificationKind.chats,
                            Icons.chat_bubble_rounded,
                            SynkColors.orangeDark,
                            l10n.notifPrefChats,
                            l10n.notifPrefChatsHint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SettingsGroup(
                        title: l10n.notifPrefOther,
                        children: [
                          row(
                            NotificationKind.marketing,
                            Icons.campaign_rounded,
                            SynkColors.textSecondary,
                            l10n.notifPrefMarketing,
                            l10n.notifPrefMarketingHint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SettingsGroup(
                        title: l10n.notifPrefIphone,
                        children: [
                          SettingsRow(
                            icon: Icons.phone_iphone_rounded,
                            iconColor: SynkColors.orangeDark,
                            title: l10n.ntfyPageTitle,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    NtfySettingsView(controller: _controller),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
