import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/notification_preferences_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/settings_row.dart';

final _ntfyAppStoreUrl = Uri.parse(
  'https://apps.apple.com/app/ntfy/id1625396347',
);

// iPhone notifications through the ntfy app, for builds without native push.
class NtfySettingsView extends StatelessWidget {
  const NtfySettingsView({super.key, required this.controller});

  final NotificationPreferencesController controller;

  Future<void> _setEnabled(BuildContext context, bool enabled) async {
    final ok = await controller.setNtfyEnabled(enabled);
    if (!ok && context.mounted) {
      SynkFeedback.showError(
        context,
        context.l10n.somethingWentWrongPleaseTryAgain,
      );
    }
  }

  Future<void> _copyTopic(BuildContext context, String topic) async {
    await Clipboard.setData(ClipboardData(text: topic));
    if (!context.mounted) return;
    SynkFeedback.showToast(context, title: context.l10n.notifPrefNtfyCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [l10n.ntfyStep1, l10n.ntfyStep2, l10n.ntfyStep3, l10n.ntfyStep4];

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SettingsHeader(title: l10n.ntfyPageTitle),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final topic = controller.ntfyTopic;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: SynkColors.orangeLight,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.phone_iphone_rounded,
                              size: 22,
                              color: SynkColors.orangeDeep,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.ntfyIntro,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                  color: SynkColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SettingsGroup(
                        title: l10n.ntfyStepsTitle,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            _Step(number: i + 1, text: steps[i]),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SettingsGroup(
                        children: [
                          SettingsRow(
                            icon: Icons.download_rounded,
                            iconColor: SynkColors.teal,
                            title: l10n.ntfyGetApp,
                            subtitle: l10n.ntfyGetAppHint,
                            onTap: () => launchUrl(
                              _ntfyAppStoreUrl,
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                          SettingsRow(
                            icon: Icons.phone_iphone_rounded,
                            iconColor: SynkColors.orangeDark,
                            title: l10n.notifPrefNtfy,
                            subtitle: l10n.notifPrefNtfyHint,
                            trailing: Switch.adaptive(
                              value: topic != null,
                              activeTrackColor: SynkColors.teal,
                              onChanged: (value) => _setEnabled(context, value),
                            ),
                          ),
                          if (topic != null)
                            SettingsRow(
                              icon: Icons.tag_rounded,
                              iconColor: SynkColors.pink,
                              title: l10n.notifPrefNtfyTopic,
                              subtitle: topic,
                              trailing: const Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: SynkColors.textSecondary,
                              ),
                              onTap: () => _copyTopic(context, topic),
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

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: SynkColors.orangeLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: SynkColors.orangeDeep,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
