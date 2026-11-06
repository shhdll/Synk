import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/notification_preferences_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/custom_widgets/synk_dialog.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';

// Username of the Synk bot made with @BotFather.
const _telegramBot = 'SynkNotifyBot';

// Gets a one-time code and opens the Synk bot with it. Shows an error and
// returns false if no code could be made.
Future<bool> openTelegramConnect(
  BuildContext context,
  NotificationPreferencesController controller,
) async {
  final language = Localizations.localeOf(context).languageCode;
  final code = await controller.telegramLinkCode(language);
  if (code == null) {
    if (context.mounted) {
      SynkFeedback.showError(
        context,
        context.l10n.somethingWentWrongPleaseTryAgain,
      );
    }
    return false;
  }

  await launchUrl(
    Uri.parse('https://t.me/$_telegramBot?start=$code'),
    mode: LaunchMode.externalApplication,
  );
  return true;
}

// The popup offered once per account on each iPhone. ntfy users are asked
// to switch, since connecting Telegram turns ntfy off.
Future<void> showTelegramPrompt(
  BuildContext context,
  NotificationPreferencesController controller,
) async {
  final l10n = context.l10n;
  final switching = controller.ntfyTopic != null;
  final choice = await SynkDialog(
    icon: Icons.notifications_active_rounded,
    iconColor: Colors.white,
    iconBackground: SynkColors.teal,
    title: switching ? l10n.telegramSwitchTitle : l10n.telegramPromptTitle,
    message: switching
        ? l10n.telegramSwitchMessage
        : l10n.telegramPromptMessage,
    primaryLabel: l10n.telegramConnect,
    secondaryLabel: l10n.notNow,
    showPrimaryArrow: false,
  ).show(context);
  if (choice == SynkDialogAction.primary && context.mounted) {
    await openTelegramConnect(context, controller);
  }
}
