import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import 'my_activity_card.dart';

enum ActivityRoleFilter {
  all,
  hosting,
  joined,
  requested;

  String get label => switch (this) {
    all => appL10n.all,
    hosting => appL10n.hosting,
    joined => appL10n.joined,
    requested => appL10n.requested,
  };

  bool matches(MyActivityRole role) => switch (this) {
    all => true,
    hosting => role == MyActivityRole.hosting,
    joined => role == MyActivityRole.joined,
    requested =>
      role == MyActivityRole.pending || role == MyActivityRole.waitlisted,
  };
}

enum ActivityVisibility {
  all,
  public,
  private;

  String get label => switch (this) {
    all => appL10n.all,
    public => appL10n.public,
    private => appL10n.private,
  };

  bool matches(Activity activity) => switch (this) {
    all => true,
    public => activity.isPublic,
    private => !activity.isPublic,
  };
}

typedef ActivityFilterChoice = ({
  ActivityRoleFilter role,
  ActivityVisibility visibility,
});

// Edits a draft; only Show applies it.
Future<ActivityFilterChoice?> showActivitiesFilterSheet({
  required BuildContext context,
  required ActivityFilterChoice initial,
  required int Function(ActivityFilterChoice) countFor,
}) {
  return showModalBottomSheet<ActivityFilterChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: SynkColors.ink.withValues(alpha: 0.45),
    builder: (context) =>
        _ActivitiesFilterSheet(initial: initial, countFor: countFor),
  );
}

TextStyle _inter(double size, FontWeight weight, Color color) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

class _ActivitiesFilterSheet extends StatefulWidget {
  const _ActivitiesFilterSheet({required this.initial, required this.countFor});

  final ActivityFilterChoice initial;
  final int Function(ActivityFilterChoice) countFor;

  @override
  State<_ActivitiesFilterSheet> createState() => _ActivitiesFilterSheetState();
}

class _ActivitiesFilterSheetState extends State<_ActivitiesFilterSheet> {
  late ActivityFilterChoice _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final count = widget.countFor(_draft);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + media.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD8CDBB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.filter,
            textAlign: TextAlign.center,
            style: _inter(22, FontWeight.w800, SynkColors.ink),
          ),
          const SizedBox(height: 18),
          _Section(
            label: context.l10n.role,
            children: [
              // No All chip: tapping the picked one again shows them all.
              for (final role in ActivityRoleFilter.values)
                if (role != ActivityRoleFilter.all)
                  _chip(
                    label: '${role.label}  ${_countWith(role: role)}',
                    selected: _draft.role == role,
                    enabled: _countWith(role: role) > 0,
                    onTap: () => setState(
                      () => _draft = (
                        role: _draft.role == role
                            ? ActivityRoleFilter.all
                            : role,
                        visibility: _draft.visibility,
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            label: context.l10n.visibility,
            children: [
              for (final (visibility, icon) in [
                (ActivityVisibility.public, Icons.public_rounded),
                (ActivityVisibility.private, Icons.lock_rounded),
              ])
                _chip(
                  label: visibility.label,
                  icon: icon,
                  selected: _draft.visibility == visibility,
                  enabled: true,
                  onTap: () => setState(
                    () => _draft = (
                      role: _draft.role,
                      visibility: _draft.visibility == visibility
                          ? ActivityVisibility.all
                          : visibility,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: count == 0
                  ? null
                  : () => Navigator.of(context).pop(_draft),
              style: FilledButton.styleFrom(
                backgroundColor: SynkColors.orangeDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD8CDBB),
                disabledForegroundColor: SynkColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                textStyle: _inter(16, FontWeight.w700, Colors.white),
              ),
              child: Text(switch (count) {
                0 => context.l10n.noMatchesTryFewerFilters,
                1 => context.l10n.showOneActivity,
                _ => context.l10n.showActivities(count),
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Role counts follow the chosen visibility.
  int _countWith({required ActivityRoleFilter role}) =>
      widget.countFor((role: role, visibility: _draft.visibility));

  Widget _chip({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return _Chip(
      label: label,
      icon: icon,
      selected: selected,
      onTap: enabled || selected ? onTap : null,
    );
  }
}

// Picked chips are light orange with an outline, so they don't look like
// the solid Show button.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? SynkColors.orangeDeep : SynkColors.ink;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? SynkColors.orangeDark : Colors.white,
        width: 1.5,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Material(
          color: selected ? SynkColors.orangeLight : Colors.white,
          shape: shape,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              // Shrinks a long label so the row never wraps.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Text(label, style: _inter(14, FontWeight.w600, foreground)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _inter(13, FontWeight.w700, SynkColors.labelGrey)),
        const SizedBox(height: 8),
        // One row, each chip the same width.
        Row(
          children: [
            for (final (i, chip) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: chip),
            ],
          ],
        ),
      ],
    );
  }
}
