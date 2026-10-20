import 'package:flutter/material.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../home/widgets/activity_thumbnail.dart';
import '../home/widgets/discovery_activity_card.dart';
import 'create_activity_widgets.dart';

class StepReview extends StatelessWidget {
  const StepReview({super.key, required this.controller});

  final CreateActivityController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final String title = c.titleController.text.trim();
    final String description = c.descriptionController.text.trim();
    final DateTime? start = c.startsAt;
    final double? lat = c.latitude;
    final double? lng = c.longitude;
    final int spots = c.spotsOpen;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 170,
            child: c.photoFile != null
                ? Image.file(
                    c.photoFile!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _IconHero(title: title),
                  )
                : c.existingPhotoUrl != null
                ? Image.network(
                    c.existingPhotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _IconHero(title: title),
                  )
                : _IconHero(title: title),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: SynkColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        CreateCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              _Row(
                icon: Icons.schedule_rounded,
                label: 'When',
                value: start == null
                    ? 'Not set'
                    : DiscoveryActivityCard.formatWhen(start),
                onTap: () => c.goToStep(0),
              ),
              const _Divider(),
              _Row(
                icon: Icons.place_rounded,
                label: 'Where',
                value: c.locationName,
                detail: c.locationAddress,
                onTap: () => c.goToStep(0),
              ),
              if (lat != null && lng != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LiteMapPreview(
                      latitude: lat,
                      longitude: lng,
                      height: 140,
                    ),
                  ),
                ),
              const _Divider(),
              _Row(
                icon: Icons.groups_rounded,
                label: 'People',
                value:
                    '${c.participants} including you · '
                    '$spots ${spots == 1 ? 'spot' : 'spots'} open',
                onTap: () => c.goToStep(1),
              ),
              const _Divider(),
              _Row(
                icon: c.isPublic
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                label: 'Visibility',
                value: c.isPublic ? 'Public' : 'Private',
                onTap: () => c.goToStep(1),
              ),
              if (description.isNotEmpty) ...<Widget>[
                const _Divider(),
                _Row(
                  icon: Icons.notes_rounded,
                  label: 'Description',
                  value: description,
                  multiline: true,
                  onTap: () => c.goToStep(1),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IconHero extends StatelessWidget {
  const _IconHero({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ActivityVisual visual = ActivityVisual.forText(title);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            visual.tint.withValues(alpha: 0.16),
            visual.tint.withValues(alpha: 0.32),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          visual.icon,
          size: 64,
          color: Color.lerp(visual.tint, SynkColors.textPrimary, 0.35),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.detail,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool multiline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? extra = detail;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: SynkColors.orange.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: SynkColors.orangeDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: multiline ? null : 1,
                    overflow: multiline ? null : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  if (extra != null && extra.isNotEmpty)
                    Text(
                      extra,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: SynkColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 58,
      color: Color(0x146B7280),
    );
  }
}
