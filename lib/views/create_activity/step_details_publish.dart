import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/activity_constants.dart';
import '../../core/constants/synk_colors.dart';

// Step 3 of the Create Activity wizard: description, optional photo,visibility.
class StepDetailsPublish extends StatefulWidget {
  const StepDetailsPublish({super.key, required this.controller});

  final CreateActivityController controller;

  @override
  State<StepDetailsPublish> createState() => _StepDetailsPublishState();
}

class _StepDetailsPublishState extends State<StepDetailsPublish> {
  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  CreateActivityController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.descriptionController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _c.descriptionController.removeListener(_onDescriptionChanged);
    super.dispose();
  }

  void _onDescriptionChanged() {
    if (mounted) setState(() {});
  }

  String _summaryWhen() {
    final DateTime? date = _c.date;
    final TimeOfDay? time = _c.time;
    if (date == null) return 'Not set';
    final String day =
        '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
    if (time == null) return day;
    return '$day · ${time.format(context)}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------


  @override
  Widget build(BuildContext context) {
    final String description = _c.descriptionController.text;
    final String title = _c.titleController.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        const _GroupLabel(text: 'DESCRIPTION', isRequired: true),
        const SizedBox(height: 10),
        _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.notes_rounded,
                  size: 20,
                  color: SynkColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _c.descriptionController,
                      maxLength: ActivityConstants.descriptionMaxLength,
                      maxLines: 5,
                      minLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: SynkColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Casual doubles, all levels welcome. Bring your own '
                            'racket if you have one — we have spares.',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: Color(0xFFB6B3BD),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${description.characters.length}'
                        '/${ActivityConstants.descriptionMaxLength}',
                        style: const TextStyle(
                          fontSize: 11,
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
        const SizedBox(height: 26),
        const _GroupLabel(
          text: 'ACTIVITY PHOTO',
          trailing: _OptionalChip(),
        ),
        const SizedBox(height: 10),
        _PhotoSection(
          photo: _c.photo,
          isPicking: _c.isPickingPhoto,
          onPick: _c.pickPhoto,
          onRemove: _c.removePhoto,
        ),
        if (_c.photoError != null) ...<Widget>[
          const SizedBox(height: 10),
          _NoteRow(
            icon: Icons.error_outline_rounded,
            color: const Color(0xFFE53935),
            text: _c.photoError!,
          ),
        ],
        const SizedBox(height: 26),
        const _GroupLabel(text: 'VISIBILITY'),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _VisibilityCard(
                icon: Icons.public_rounded,
                title: 'Public',
                subtitle: 'Anyone on Synk can find and join',
                selected: _c.isPublic,
                onTap: () => _c.setPublic(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VisibilityCard(
                icon: Icons.lock_outline_rounded,
                title: 'Private',
                subtitle: 'Only people you share it with',
                selected: !_c.isPublic,
                onTap: () => _c.setPublic(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const _GroupLabel(text: 'SUMMARY'),
        const SizedBox(height: 10),
        _Card(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(
            children: <Widget>[
              _SummaryRow(
                icon: Icons.bolt_rounded,
                label: 'Activity',
                value: title.isEmpty ? 'Not set' : title,
                missing: title.isEmpty,
              ),
              const _SummaryDivider(),
              _SummaryRow(
                icon: Icons.place_rounded,
                label: 'Where',
                value: _c.locationName.isEmpty ? 'Not set' : _c.locationName,
                missing: _c.locationName.isEmpty,
              ),
              const _SummaryDivider(),
              _SummaryRow(
                icon: Icons.event_rounded,
                label: 'When',
                value: _summaryWhen(),
                missing: _c.startsAt == null,
              ),
              const _SummaryDivider(),
              _SummaryRow(
                icon: Icons.groups_rounded,
                label: 'People',
                value: 'You + ${_c.spotsOpen} '
                    '${_c.spotsOpen == 1 ? 'spot' : 'spots'}',
                missing: false,
              ),
              const _SummaryDivider(),
              // Display-only: reads the same isPublic value the Visibility
              // cards above already use.
              _SummaryRow(
                icon: _c.isPublic
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                label: 'Visibility',
                value: _c.isPublic ? 'Public' : 'Private',
                missing: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Photo
// -----------------------------------------------------------------------------

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photo,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? photo;
  final bool isPicking;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final XFile? selected = photo;

    // Empty state: an intentional, clearly optional upload card.
    if (selected == null) {
      return CustomPaint(
        foregroundPainter: const _DashedBorderPainter(
          color: Color(0x8CFF7A36),
          radius: 20,
        ),
        child: Material(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isPicking ? null : onPick,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: <Widget>[
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: SynkColors.orange.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: isPicking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                SynkColors.orangeDark,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 22,
                            color: SynkColors.orangeDark,
                          ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Add a photo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'JPEG or PNG — helps people picture it',
                          style: TextStyle(
                            fontSize: 12,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ],
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
        ),
      );
    }

    // Selected state: real preview, filename, compact Change / Remove.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(selected.path),
                height: 80,
                width: 80,
                fit: BoxFit.cover,
                // A file can disappear or fail to decode between picking and
                // building; show a neutral tile rather than a red error box.
                errorBuilder: (BuildContext context, Object error,
                    StackTrace? stackTrace) {
                  return Container(
                    height: 80,
                    width: 80,
                    color: SynkColors.backgroundLight,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: SynkColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  selected.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Shown at the top of the activity page',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: SynkColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _PhotoAction(
                      icon: Icons.photo_camera_outlined,
                      label: 'Change',
                      color: SynkColors.orangeDark,
                      onTap: isPicking ? null : onPick,
                    ),
                    const SizedBox(width: 8),
                    _PhotoAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove',
                      color: SynkColors.textSecondary,
                      onTap: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Compact icon + label action used for Change / Remove under the photo.
class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Draws a dashed rounded-rectangle outline around the empty photo card.
// Flutter has no built-in dashed border; this is paint-only.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 6;
  static const double _gap = 4;
  static const double _stroke = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke;

    final Rect rect = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _stroke,
      size.height - _stroke,
    );
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + _dash;
        final double end = next < metric.length ? next : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

// Small caps section header, matching Steps 1 and 2.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text, this.trailing, this.isRequired = false});

  final String text;
  final Widget? trailing;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: text),
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
              ],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: SynkColors.textSecondary,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _OptionalChip extends StatelessWidget {
  const _OptionalChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1F6B7280),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Optional',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: SynkColors.textSecondary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F1E1C24),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Public / Private choice. Selected uses the same orange-tint + orange
// border language as Step 2's chips; unselected stays white and neutral.
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
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? SynkColors.orange.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? SynkColors.orangeDark : const Color(0x0F1E1C24),
            width: 1.4,
          ),
          boxShadow: selected
              ? null
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : SynkColors.backgroundLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 17,
                        color: selected
                            ? SynkColors.orangeDark
                            : SynkColors.textSecondary,
                      ),
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
                const SizedBox(height: 3),
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

// One review row: tinted icon badge, small label, clear value.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.missing,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: missing
                  ? const Color(0x1AE53935)
                  : SynkColors.orange.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: missing
                  ? const Color(0xFFE53935)
                  : SynkColors.orangeDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: missing
                        ? const Color(0xFFE53935)
                        : SynkColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 44),
      child: Divider(height: 1, thickness: 1, color: Color(0x146B7280)),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
