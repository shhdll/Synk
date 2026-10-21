import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/activity_constants.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/place_search_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../home/widgets/activity_thumbnail.dart';
import '../home/widgets/synk_filter_chip.dart';
import '../widgets/synk_date_picker.dart';
import 'create_activity_widgets.dart';
import 'location_search_sheet.dart';
import '../../utils/text_direction.dart';

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
      await _selectDate(picked);
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
      await _showScheduleConflictIfNeeded();
    } else {
      _c.touch(CreateField.time);
    }
  }

  Future<void> _selectDate(DateTime date) async {
    _c.setDate(date);
    await _showScheduleConflictIfNeeded();
  }

  Future<void> _showScheduleConflictIfNeeded() async {
    final message = await _c.checkSelectedScheduleConflict();
    if (!mounted || message == null) return;
    await SynkFeedback.showErrorDialog(
      context,
      title: _c.isEditing ? context.l10n.editActivity : context.l10n.createActivity,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        CreateGroupLabel(text: context.l10n.activityTitle, isRequired: true),
        const SizedBox(height: 10),
        _buildTitle(),
        FieldError(_c.errorFor(CreateField.title)),
        const SizedBox(height: 24),
        CreateGroupLabel(text: context.l10n.location, isRequired: true),
        const SizedBox(height: 10),
        _buildLocation(),
        FieldError(_c.errorFor(CreateField.location)),
        const SizedBox(height: 24),
        CreateGroupLabel(text: context.l10n.date, isRequired: true),
        const SizedBox(height: 10),
        _buildDate(),
        FieldError(_c.errorFor(CreateField.date)),
        const SizedBox(height: 24),
        CreateGroupLabel(text: context.l10n.time, isRequired: true),
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
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
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
                _ActivityNameInputFormatter(
                  onRejected: _c.markInvalidTitleAttempt,
                ),
                noArabicFormatter,
              ],
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                _c.clearInvalidTitleAttempt();
                _c.touch(CreateField.title);
              },
              onSubmitted: (_) => _c.touch(CreateField.title),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: SynkColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.activityTitleHint,
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
                Expanded(
                  child: Text(
                    context.l10n.chooseALocation,
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
                  PositionedDirectional(
                    end: 10,
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
                  PositionedDirectional(
                    end: 10,
                    bottom: 10,
                    child: Material(
                      color: SynkColors.orangeDark,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _openLocationPicker,
                        child: Padding(
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
                                context.l10n.tapToChange,
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
            label: context.l10n.today,
            selected: isToday,
            onTap: () => _selectDate(_today),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SynkFilterChip(
            label: context.l10n.tomorrow,
            selected: isTomorrow,
            onTap: () => _selectDate(_tomorrow),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SynkFilterChip(
            label: isOther ? formatShortDate(date) : context.l10n.pickADate,
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
                  time == null
                      ? context.l10n.chooseATime
                      : formatTime(time.hour, time.minute),
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

class _ActivityNameInputFormatter extends TextInputFormatter {
  _ActivityNameInputFormatter({required this.onRejected});

  final VoidCallback onRejected;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var rejectedInput = false;
    final filteredText = StringBuffer();
    for (final rune in newValue.text.runes) {
      final character = String.fromCharCode(rune);
      if (CreateActivityController.isAllowedTitleRune(rune)) {
        filteredText.write(character);
      } else {
        rejectedInput = true;
      }
    }
    final text = filteredText.toString();
    if (!rejectedInput) {
      return newValue;
    }
    scheduleMicrotask(onRejected);
    if (text == oldValue.text) return oldValue;

    int mappedOffset(int offset) {
      final safeOffset = offset.clamp(0, newValue.text.length).toInt();
      final prefix = newValue.text.substring(0, safeOffset);
      return prefix.runes
          .where(CreateActivityController.isAllowedTitleRune)
          .fold<int>(0, (length, rune) => length + String.fromCharCode(rune).length);
    }

    return newValue.copyWith(
      text: text,
      selection: TextSelection(
        baseOffset: mappedOffset(newValue.selection.baseOffset),
        extentOffset: mappedOffset(newValue.selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }
}
