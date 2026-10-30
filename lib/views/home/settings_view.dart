import 'package:flutter/material.dart';

import '../../controllers/language_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../services/push_notification_service.dart';
import 'widgets/section_label.dart';

// Opened from the gear on Profile.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final language = LanguageController.instance;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.settings,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
