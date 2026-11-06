import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/notification_preferences_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/settings_row.dart';
import 'widgets/telegram_connect.dart';

final _telegramAppStoreUrl = Uri.parse(
  'https://apps.apple.com/app/telegram-messenger/id686449807',
);
final _ntfyAppStoreUrl = Uri.parse(
  'https://apps.apple.com/app/ntfy/id1625396347',
);

// iPhone notifications through Telegram or the ntfy app, for builds without
// native push.
class IphoneNotificationsView extends StatefulWidget {
  const IphoneNotificationsView({super.key, required this.controller});

  final NotificationPreferencesController controller;

  @override
  State<IphoneNotificationsView> createState() =>
      _IphoneNotificationsViewState();
}

class _IphoneNotificationsViewState extends State<IphoneNotificationsView> {
  late final AppLifecycleListener _lifecycle;
  bool _connecting = false;

  NotificationPreferencesController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // The bot saves the link, so check when the user comes back from Telegram.
    _lifecycle = AppLifecycleListener(onResume: _controller.refreshTelegram);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _showError() {
    if (!mounted) return;
    SynkFeedback.showError(
      context,
      context.l10n.somethingWentWrongPleaseTryAgain,
    );
  }

  Future<void> _connectTelegram() async {
    setState(() => _connecting = true);
    await openTelegramConnect(context, _controller);
    if (mounted) setState(() => _connecting = false);
  }

  Future<void> _disconnectTelegram() async {
    final ok = await _controller.disconnectTelegram();
    if (!ok) _showError();
  }

  Future<void> _setNtfyEnabled(bool enabled) async {
    final ok = await _controller.setNtfyEnabled(enabled);
    if (!ok) _showError();
  }

  Future<void> _copyTopic(String topic) async {
    await Clipboard.setData(ClipboardData(text: topic));
    if (!mounted) return;
    SynkFeedback.showToast(context, title: context.l10n.notifPrefNtfyCopied);
  }

  void _open(Uri url) {
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SettingsHeader(title: l10n.ntfyPageTitle),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final linked = _controller.telegramLinked;
                  final topic = _controller.ntfyTopic;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      const _IphoneOnlyBanner(),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          0,
                          16,
                          10,
                        ),
                        child: Text(
                          l10n.iphoneNotifPickOne,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ),
                      _FoldableSection(
                        icon: Icons.send_rounded,
                        iconColor: SynkColors.teal,
                        title: l10n.telegramTitle,
                        status: linked
                            ? l10n.telegramConnected
                            : l10n.telegramRecommended,
                        initiallyOpen: true,
                        children: [
                          SettingsRow(
                            icon: Icons.download_rounded,
                            iconColor: SynkColors.teal,
                            title: l10n.telegramGetApp,
                            subtitle: l10n.ntfyGetAppHint,
                            onTap: () => _open(_telegramAppStoreUrl),
                          ),
                          if (linked) ...[
                            SettingsRow(
                              icon: Icons.check_circle_rounded,
                              iconColor: SynkColors.teal,
                              title: l10n.telegramConnected,
                              subtitle: l10n.telegramConnectedHint,
                            ),
                            SettingsRow(
                              icon: Icons.link_off_rounded,
                              iconColor: SynkColors.badge,
                              title: l10n.telegramDisconnect,
                              destructive: true,
                              onTap: _disconnectTelegram,
                            ),
                          ] else
                            SettingsRow(
                              icon: Icons.link_rounded,
                              iconColor: SynkColors.orangeDark,
                              title: l10n.telegramConnect,
                              subtitle: l10n.telegramConnectHint,
                              trailing: _connecting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SynkColors.orangeDark,
                                      ),
                                    )
                                  : null,
                              onTap: _connecting ? null : _connectTelegram,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FoldableSection(
                        icon: Icons.notifications_rounded,
                        iconColor: SynkColors.orangeDark,
                        title: l10n.ntfyTitle,
                        status: topic != null ? l10n.ntfyOn : null,
                        initiallyOpen: topic != null,
                        children: [
                          SettingsRow(
                            icon: Icons.download_rounded,
                            iconColor: SynkColors.teal,
                            title: l10n.ntfyGetApp,
                            subtitle: l10n.ntfyGetAppHint,
                            onTap: () => _open(_ntfyAppStoreUrl),
                          ),
                          SettingsRow(
                            icon: Icons.phone_iphone_rounded,
                            iconColor: SynkColors.orangeDark,
                            title: l10n.notifPrefNtfy,
                            subtitle: l10n.notifPrefNtfyHint,
                            trailing: Switch.adaptive(
                              value: topic != null,
                              activeTrackColor: SynkColors.teal,
                              onChanged: _setNtfyEnabled,
                            ),
                          ),
                          if (topic != null)
                            SettingsRow(
                              icon: Icons.tag_rounded,
                              iconColor: SynkColors.pink,
                              title: topic,
                              subtitle: l10n.ntfyTopicHint,
                              trailing: const Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: SynkColors.textSecondary,
                              ),
                              onTap: () => _copyTopic(topic),
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

// A settings group that opens and closes from its title row.
class _FoldableSection extends StatefulWidget {
  const _FoldableSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.status,
    this.initiallyOpen = false,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? status;
  final bool initiallyOpen;
  final List<Widget> children;

  @override
  State<_FoldableSection> createState() => _FoldableSectionState();
}

class _FoldableSectionState extends State<_FoldableSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: SynkColors.textSecondary.withValues(alpha: 0.10),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SettingsRow(
            icon: widget.icon,
            iconColor: widget.iconColor,
            title: widget.title,
            value: widget.status,
            trailing: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                color: SynkColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    children: [
                      for (final child in widget.children) ...[divider, child],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// One line saying this page is only for iPhone users.
class _IphoneOnlyBanner extends StatelessWidget {
  const _IphoneOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apple, size: 22, color: Colors.black),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.l10n.ntfyIphoneOnly,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Divider(
          height: 1,
          thickness: 1,
          color: SynkColors.textSecondary.withValues(alpha: 0.18),
        ),
      ],
    );
  }
}
