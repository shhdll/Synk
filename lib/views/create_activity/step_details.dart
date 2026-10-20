import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/activity_constants.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import 'create_activity_widgets.dart';

class StepDetails extends StatefulWidget {
  const StepDetails({super.key, required this.controller});

  final CreateActivityController controller;

  @override
  State<StepDetails> createState() => _StepDetailsState();
}

class _StepDetailsState extends State<StepDetails> {
  CreateActivityController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.descriptionController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _c.descriptionController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final String description = _c.descriptionController.text;
    final String? descriptionError = _c.validateDescription(description);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        CreateGroupLabel(text: context.l10n.numberOfPeople),
        const SizedBox(height: 10),
        _PeopleCard(controller: _c),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.groups_rounded,
                size: 14,
                color: SynkColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.youPlusAvailable(_c.spotsOpen),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: SynkColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CreateGroupLabel(text: context.l10n.description, optional: true),
        const SizedBox(height: 10),
        CreateCard(
          hasError: descriptionError != null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              TextField(
                controller: _c.descriptionController,
                maxLength: ActivityConstants.descriptionMaxLength,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: SynkColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.activityDescriptionHint,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFFB6B3BD),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Text(
                '${description.characters.length}'
                '/${ActivityConstants.descriptionMaxLength}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        FieldError(descriptionError),
        const SizedBox(height: 24),
        CreateGroupLabel(text: context.l10n.photo, optional: true),
        const SizedBox(height: 10),
        _PhotoSection(
          photo: _c.photo,
          isPicking: _c.isPickingPhoto,
          hasError: _c.photoError != null,
          onPick: _c.pickPhoto,
          onRemove: _c.removePhoto,
        ),
        FieldError(_c.photoError),
        const SizedBox(height: 24),
        CreateGroupLabel(text: context.l10n.visibility),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _VisibilityCard(
                  icon: Icons.public_rounded,
                  title: context.l10n.public,
                  subtitle: context.l10n.anyoneCanFindAndJoin,
                  selected: _c.isPublic,
                  onTap: () => _c.setPublic(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VisibilityCard(
                  icon: Icons.lock_outline_rounded,
                  title: context.l10n.private,
                  subtitle: context.l10n.joinByCodeYouApprove,
                  selected: !_c.isPublic,
                  onTap: () => _c.setPublic(false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.controller});

  final CreateActivityController controller;

  @override
  Widget build(BuildContext context) {
    return CreateCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.groups_rounded,
            size: 22,
            color: SynkColors.orangeDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.includingYou,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            filled: false,
            onTap: controller.canDecrement
                ? controller.decrementParticipants
                : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${controller.participants}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            filled: true,
            onTap: controller.canIncrement
                ? controller.incrementParticipants
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color background = filled
        ? (enabled
              ? SynkColors.orangeDark
              : SynkColors.orangeDark.withValues(alpha: 0.35))
        : SynkColors.background;
    final Color foreground = filled
        ? Colors.white
        : enabled
        ? SynkColors.textPrimary
        : SynkColors.textSecondary.withValues(alpha: 0.4);

    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 38,
          child: Icon(icon, size: 20, color: foreground),
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photo,
    required this.isPicking,
    required this.hasError,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? photo;
  final bool isPicking;
  final bool hasError;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final XFile? selected = photo;

    if (selected == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isPicking ? null : onPick,
          child: CreateCard(
            hasError: hasError,
            child: Row(
              children: <Widget>[
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: SynkColors.orange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isPicking
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: SynkColors.orangeDark,
                          ),
                        )
                      : const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 21,
                          color: SynkColors.orangeDark,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.addAPhoto,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: SynkColors.orangeDark,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CreateCard(
      hasError: hasError,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(selected.path),
              height: 64,
              width: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 64,
                width: 64,
                color: SynkColors.backgroundLight,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: SynkColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.photoAdded,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.changePhoto,
            onPressed: isPicking ? null : onPick,
            icon: const Icon(
              Icons.photo_camera_outlined,
              size: 20,
              color: SynkColors.orangeDark,
            ),
          ),
          IconButton(
            tooltip: context.l10n.removePhoto,
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? SynkColors.orange.withValues(alpha: 0.14)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? SynkColors.orangeDark : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? SynkColors.orangeDark
                          : SynkColors.textSecondary,
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: selected
                          ? SynkColors.orangeDark
                          : const Color(0x4D6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: SynkColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
