import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import 'widgets/settings_row.dart';

const _team = [
  'Joud Alhugbani',
  'Shahad Alhedari',
  'Muneerah Alhaqbani',
  'Joud Alwabel',
  'Laila Aljassar',
  'Shaden Aljammaz',
];

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SettingsHeader(title: l10n.aboutSynk),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/synk_logo.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'Synk',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(child: AppVersionText()),
                  const SizedBox(height: 28),
                  _Section(
                    title: l10n.ourStory,
                    initiallyExpanded: true,
                    child: _Body(l10n.ourStoryBody),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: l10n.ourMission,
                    child: _Body(l10n.ourMissionBody),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: l10n.theTeam,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Body(l10n.theTeamBody),
                        const SizedBox(height: 10),
                        for (final (i, member) in _team.indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: SynkColors.textSecondary
                                  .withValues(alpha: 0.12),
                            ),
                          _TeamMember(member),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      l10n.madeInRiyadh,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
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

// "Version 1.0.0 (1)", read from the installed app.
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Text(
          info == null
              ? ''
              : context.l10n.appVersion(info.version, info.buildNumber),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SynkColors.textSecondary,
          ),
        );
      },
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: SynkColors.textPrimary,
      ),
    );
  }
}

class _TeamMember extends StatelessWidget {
  const _TeamMember(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: SynkColors.orangeLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial.isEmpty ? '?' : initial[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SynkColors.orangeDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
