import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/activity_constants.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activity_filters.dart';
import '../../models/place_search_model.dart';
import '../home/widgets/activity_thumbnail.dart';
import '../home/widgets/synk_filter_chip.dart';
import '../widgets/synk_date_picker.dart';
import 'create_activity_widgets.dart';
import 'location_search_sheet.dart';

class StepBasics extends StatefulWidget {
  const StepBasics({super.key, required this.controller});

  final CreateActivityController controller;

  @override
  State<StepBasics> createState() => _StepBasicsState();
}

class _StepBasicsState extends State<StepBasics> {
  final FocusNode _titleFocus = FocusNode();

  CreateActivityController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.titleController.addListener(_rebuild);
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _c.touch(CreateField.title);
    });
  }

  @override
  void dispose() {
    _c.titleController.removeListener(_rebuild);
    _titleFocus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _openLocationPicker() async {
    _titleFocus.unfocus();
    final PlaceSuggestion? place = await showModalBottomSheet<PlaceSuggestion?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => const LocationSearchSheet(),
    );

    if (!mounted) return;
    if (place == null) {
      _c.touch(CreateField.location);
      return;
    }
    _c.setPlace(
      name: place.name,
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime get _today => _dateOnly(DateTime.now());
  DateTime get _tomorrow => _today.add(const Duration(days: 1));

  Future<void> _pickDate() async {
    _titleFocus.unfocus();
    final lastDate = ActivityConstants.latestAllowedDate(DateTime.now());
    final currentDate = _c.date ?? _today;
    final DateTime? picked = await showSynkDatePicker(
      context: context,
      initialDate: currentDate.isAfter(lastDate) ? lastDate : currentDate,
      firstDate: _today,
      lastDate: lastDate,
    );
    if (picked != null) {
      _c.setDate(picked);
    } else {
      _c.touch(CreateField.date);
    }
  }

  Future<void> _pickTime() async {
    _titleFocus.unfocus();
    final TimeOfDay? picked = await showSynkTimePicker(
      context: context,
      initialTime: _c.time ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      _c.setTime(picked);
    } else {
      _c.touch(CreateField.time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        const CreateGroupLabel(text: 'Activity title', isRequired: true),
        const SizedBox(height: 10),
        _buildTitle(),
        FieldError(_c.errorFor(CreateField.title)),
        const SizedBox(height: 24),
        const CreateGroupLabel(text: 'Location', isRequired: true),
        const SizedBox(height: 10),
        _buildLocation(),
        FieldError(_c.errorFor(CreateField.location)),
        const SizedBox(height: 24),
        const CreateGroupLabel(text: 'Date', isRequired: true),
        const SizedBox(height: 10),
        _buildDate(),
        FieldError(_c.errorFor(CreateField.date)),
        const SizedBox(height: 24),
        const CreateGroupLabel(text: 'Time', isRequired: true),
        const SizedBox(height: 10),
        _buildTime(),
        FieldError(_c.errorFor(CreateField.time)),
      ],
    );
  }

  Widget _buildTitle() {
    final String title = _c.titleController.text;
    // Icon follows the title, like on Home.
    final ActivityVisual visual = ActivityVisual.forText(title);
    final bool matched = title.trim().isNotEmpty;

    return CreateCard(
      hasError: _c.errorFor(CreateField.title) != null,
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: matched
                  ? visual.tint.withValues(alpha: 0.16)
                  : SynkColors.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              visual.icon,
              size: 20,
              color: matched
                  ? Color.lerp(visual.tint, SynkColors.textPrimary, 0.25)
                  : SynkColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _c.titleController,
              focusNode: _titleFocus,
              maxLength: ActivityConstants.titleMaxLength,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  CreateActivityController.titleAllowed,
                ),
              ],
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _c.touch(CreateField.title),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: SynkColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Morning padel',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB6B3BD),
                ),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${title.characters.length}/${ActivityConstants.titleMaxLength}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    final bool hasError = _c.errorFor(CreateField.location) != null;
    final double? lat = _c.latitude;
    final double? lng = _c.longitude;

    if (_c.locationName.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openLocationPicker,
          child: CreateCard(
            hasError: hasError,
            child: Row(
              children: <Widget>[
                Container(
                  height: 40,
                  width: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SynkColors.orangeDark,
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    size: 21,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Choose a location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: SynkColors.orangeDark,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final String? address = _c.locationAddress;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openLocationPicker,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (lat != null && lng != null)
                    LiteMapPreview(latitude: lat, longitude: lng)
                  else
                    const ColoredBox(
                      color: SynkColors.backgroundLight,
                      child: Icon(
                        Icons.place_rounded,
                        size: 32,
                        color: SynkColors.orangeDark,
                      ),
                    ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _c.clearPlace,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: SynkColors.orangeDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: SynkColors.orangeDark,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _openLocationPicker,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.edit_location_alt_outlined,
                                size: 15,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Tap to change',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.place_rounded,
                    size: 20,
                    color: SynkColors.orangeDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _c.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        if (address != null && address.isNotEmpty)
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: SynkColors.textSecondary,
                            ),
                          ),
                      ],
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

  Widget _buildDate() {
    final DateTime? date = _c.date;
    final bool isToday = date != null && _dateOnly(date) == _today;
    final bool isTomorrow = date != null && _dateOnly(date) == _tomorrow;
    final bool isOther = date != null && !isToday && !isTomorrow;

    return Row(
      children: <Widget>[
        Expanded(
          child: SynkFilterChip(
            label: 'Today',
            selected: isToday,
            onTap: () => _c.setDate(_today),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SynkFilterChip(
            label: 'Tomorrow',
            selected: isTomorrow,
            onTap: () => _c.setDate(_tomorrow),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SynkFilterChip(
            label: isOther ? formatShortDate(date) : 'Pick a date',
            icon: Icons.calendar_month_rounded,
            selected: isOther,
            onTap: _pickDate,
          ),
        ),
      ],
    );
  }

  Widget _buildTime() {
    final TimeOfDay? time = _c.time;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _pickTime,
        child: CreateCard(
          hasError: _c.errorFor(CreateField.time) != null,
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                size: 20,
                color: SynkColors.orangeDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  time == null ? 'Choose a time' : time.format(context),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: time == null
                        ? const Color(0xFFB6B3BD)
                        : SynkColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: SynkColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
