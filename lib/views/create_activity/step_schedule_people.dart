import 'package:flutter/material.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/synk_colors.dart';

// Step 2 of the Create Activity wizard: date, start time, and how many people.
//
// Rebuilt by the wizard shell whenever the controller notifies, so it holds no
// state of its own.
class StepSchedulePeople extends StatelessWidget {
  const StepSchedulePeople({super.key, required this.controller});

  final CreateActivityController controller;

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool get _isToday {
    final DateTime? date = controller.date;
    if (date == null) return false;
    return _dateOnly(date) == _dateOnly(DateTime.now());
  }

  bool get _isTomorrow {
    final DateTime? date = controller.date;
    if (date == null) return false;
    final DateTime tomorrow =
        _dateOnly(DateTime.now()).add(const Duration(days: 1));
    return _dateOnly(date) == tomorrow;
  }

  String _formatDate(DateTime date) {
    final String weekday = _weekdays[date.weekday - 1];
    final String month = _months[date.month - 1];
    return '$weekday, ${date.day} $month';
  }

  String _formatTime(BuildContext context, TimeOfDay time) =>
      time.format(context);

  // Compact, on-brand replacements for the native Material date/time
  // pickers. Same validation as before (date can't be before today, date
  // range is capped at a year out) — only the picker UI itself changed.
  Future<void> _pickDate(BuildContext context) async {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _DatePickerSheet(
        initialDate: controller.date ?? today,
        firstDate: today,
        lastDate: today.add(const Duration(days: 365)),
      ),
    );
    if (picked != null) controller.setDate(picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _TimePickerSheet(
        initialTime: controller.time ?? const TimeOfDay(hour: 18, minute: 0),
      ),
    );
    if (picked != null) controller.setTime(picked);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final DateTime? date = controller.date;
    final TimeOfDay? time = controller.time;
    final DateTime? start = controller.startsAt;
    final bool inThePast = start != null && !start.isAfter(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        const _GroupLabel(text: 'WHEN'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _ChoiceChipCard(
              label: 'Today',
              selected: _isToday,
              onTap: () => controller.setDate(DateTime.now()),
            ),
            _ChoiceChipCard(
              label: 'Tomorrow',
              selected: _isTomorrow,
              onTap: () => controller.setDate(
                DateTime.now().add(const Duration(days: 1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 6,
              child: _FieldCard(
                icon: Icons.calendar_today_rounded,
                label: 'Date *',
                isRequired: true,
                value: date == null ? 'Choose a date' : _formatDate(date),
                onTap: () => _pickDate(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: _FieldCard(
                icon: Icons.access_time_rounded,
                label: 'Start *',
                isRequired: true,
                value: time == null
                    ? 'Choose a time'
                    : _formatTime(context, time),
                onTap: () => _pickTime(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _HintRow(
          icon: Icons.info_outline_rounded,
          text: 'Past dates and times are not allowed.',
        ),
        if (inThePast) ...<Widget>[
          const SizedBox(height: 8),
          const _ValueRow(
            icon: Icons.error_outline_rounded,
            iconColor: Color(0xFFE53935),
            text: 'That time has already passed — pick a later one.',
            textColor: Color(0xFFE53935),
          ),
        ],
        const SizedBox(height: 26),
        const _GroupLabel(text: 'PEOPLE'),
        const SizedBox(height: 10),
        _PeopleCard(
          participants: controller.participants,
          canDecrement: controller.canDecrement,
          canIncrement: controller.canIncrement,
          onDecrement: controller.decrementParticipants,
          onIncrement: controller.incrementParticipants,
        ),
        const SizedBox(height: 8),
        _HintRow(
          icon: Icons.groups_rounded,
          text: 'You + ${controller.spotsOpen} available '
              '${controller.spotsOpen == 1 ? 'spot' : 'spots'}',
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

// Small caps section header ("WHEN" / "PEOPLE"), matching the mockup's
// label style for these groups.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: SynkColors.textSecondary,
        ),
      ),
    );
  }
}

// Small gray caption row with a leading icon, used under the date/time
// fields and under the people field, matching the mockup's hint rows.
class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: SynkColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: SynkColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Today / Tomorrow shortcut chip — compact, content-sized, matching the
// approved mockup's pill style (tinted-orange fill when selected, rather
// than the previous full-width gradient chip).
class _ChoiceChipCard extends StatelessWidget {
  const _ChoiceChipCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? SynkColors.orange.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.80),
          border: Border.all(
            color: selected
                ? SynkColors.orangeDark
                : Colors.white.withValues(alpha: 0.7),
            width: 1.4,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Compact tappable field card (icon, small label, value, chevron) used for
// the side-by-side Date and Start cards, matching the mockup.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.icon,
    required this.label,
    this.isRequired = false,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isRequired;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child:
                      Icon(icon, size: 20, color: SynkColors.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(text: label.replaceAll(' *', '')),
                            if (isRequired)
                              const TextSpan(
                                text: ' *',
                                style: TextStyle(color: Color(0xFFE53935)),
                              ),
                          ],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: SynkColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Participants row card: icon + label on the left, a pill stepper on the
// right, matching the mockup's People section.
class _PeopleCard extends StatelessWidget {
  const _PeopleCard({
    required this.participants,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int participants;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
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
          const Icon(
            Icons.groups_rounded,
            size: 20,
            color: SynkColors.textSecondary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Participants',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Including you',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: SynkColors.background,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: <Widget>[
                _PillStepperButton(
                  icon: Icons.remove_rounded,
                  onTap: canDecrement ? onDecrement : null,
                  filled: false,
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$participants',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
                _PillStepperButton(
                  icon: Icons.add_rounded,
                  onTap: canIncrement ? onIncrement : null,
                  filled: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// The +/- circles inside the people stepper pill.
class _PillStepperButton extends StatelessWidget {
  const _PillStepperButton({
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final bool showGradient = filled && enabled;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: showGradient
              ? const LinearGradient(
                  colors: <Color>[SynkColors.orange, SynkColors.orangeDark],
                )
              : null,
          color: showGradient ? null : Colors.white,
          boxShadow: showGradient
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x59FF7A36),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            width: 40,
            child: Icon(
              icon,
              size: 20,
              color: showGradient
                  ? Colors.white
                  : enabled
                      ? SynkColors.textPrimary
                      : SynkColors.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor ?? SynkColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Custom in-app date & time pickers (replace the native Material dialogs)
// -----------------------------------------------------------------------------

// Shared bottom-sheet chrome (drag handle + rounded top + Synk background),
// matching the convention already used by LocationSearchSheet.
class _PickerSheetShell extends StatelessWidget {
  const _PickerSheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x331E1C24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// The gradient confirm button used at the bottom of both picker sheets.
class _SheetConfirmButton extends StatelessWidget {
  const _SheetConfirmButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: <Color>[SynkColors.orange, SynkColors.orangeDark],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x40FF7A36),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Compact month calendar. Same range rules as the previous showDatePicker
// call: firstDate..lastDate inclusive, Monday-first weeks.
class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  static const List<String> _weekdayLabels = <String>[
    'M', 'T', 'W', 'T', 'F', 'S', 'S',
  ];

  static const List<String> _monthNames = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  late DateTime _selected;
  late DateTime _visibleMonth;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void initState() {
    super.initState();
    _selected = _dateOnly(widget.initialDate);
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  bool get _canGoPrevious {
    final DateTime previousMonthEnd =
        DateTime(_visibleMonth.year, _visibleMonth.month, 0);
    return !previousMonthEnd.isBefore(widget.firstDate);
  }

  bool get _canGoNext {
    final DateTime nextMonthStart =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    return !nextMonthStart.isAfter(widget.lastDate);
  }

  void _goToPreviousMonth() {
    if (!_canGoPrevious) return;
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final int leadingBlanks = (_visibleMonth.weekday - 1) % 7;

    return _PickerSheetShell(
      title: 'Pick a date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              Row(
                children: <Widget>[
                  _MonthNavButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: _canGoPrevious ? _goToPreviousMonth : null,
                  ),
                  const SizedBox(width: 6),
                  _MonthNavButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: _canGoNext ? _goToNextMonth : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: _weekdayLabels
                .map(
                  (String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              for (int day = 1; day <= daysInMonth; day++) _buildDayCell(day),
            ],
          ),
          const SizedBox(height: 12),
          _SheetConfirmButton(
            label: 'Set date',
            onTap: () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(int day) {
    final DateTime cellDate =
        DateTime(_visibleMonth.year, _visibleMonth.month, day);
    final bool isDisabled = cellDate.isBefore(widget.firstDate) ||
        cellDate.isAfter(widget.lastDate);
    final bool isSelected = cellDate == _selected;
    final bool isToday = cellDate == _dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap:
              isDisabled ? null : () => setState(() => _selected = cellDate),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected
                  ? const LinearGradient(
                      colors: <Color>[
                        SynkColors.orange,
                        SynkColors.orangeDark,
                      ],
                    )
                  : null,
              border: (!isSelected && isToday)
                  ? Border.all(color: SynkColors.orangeDark, width: 1.4)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isDisabled
                        ? SynkColors.textSecondary.withValues(alpha: 0.35)
                        : SynkColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 32,
          width: 32,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? SynkColors.textPrimary
                : SynkColors.textSecondary.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

// Compact scroll-wheel time picker (hour / minute / AM-PM), same value
// range and precision as the previous showTimePicker call.
class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  static const List<String> _periods = <String>['AM', 'PM'];

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _periodController;

  late int _hourOfPeriod; // 1-12
  late int _minute; // 0-59
  late int _periodIndex; // 0 = AM, 1 = PM

  @override
  void initState() {
    super.initState();
    final int hour12 = widget.initialTime.hourOfPeriod == 0
        ? 12
        : widget.initialTime.hourOfPeriod;
    _hourOfPeriod = hour12;
    _minute = widget.initialTime.minute;
    _periodIndex = widget.initialTime.period == DayPeriod.am ? 0 : 1;
    _hourController = FixedExtentScrollController(initialItem: hour12 - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _periodController =
        FixedExtentScrollController(initialItem: _periodIndex);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _confirm() {
    final int hour24 = _periodIndex == 0
        ? _hourOfPeriod % 12
        : (_hourOfPeriod % 12) + 12;
    Navigator.of(context).pop(TimeOfDay(hour: hour24, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    return _PickerSheetShell(
      title: 'Pick a start time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: SynkColors.backgroundLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _wheel(
                        controller: _hourController,
                        itemCount: 12,
                        labelBuilder: (int index) => '${index + 1}',
                        onChanged: (int index) =>
                            setState(() => _hourOfPeriod = index + 1),
                      ),
                    ),
                    Expanded(
                      child: _wheel(
                        controller: _minuteController,
                        itemCount: 60,
                        labelBuilder: (int index) =>
                            index.toString().padLeft(2, '0'),
                        onChanged: (int index) =>
                            setState(() => _minute = index),
                      ),
                    ),
                    Expanded(
                      child: _wheel(
                        controller: _periodController,
                        itemCount: 2,
                        labelBuilder: (int index) => _periods[index],
                        onChanged: (int index) =>
                            setState(() => _periodIndex = index),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetConfirmButton(label: 'Set time', onTap: _confirm),
        ],
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 44,
      perspective: 0.003,
      diameterRatio: 1.4,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (BuildContext context, int index) {
          return Center(
            child: Text(
              labelBuilder(index),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
          );
        },
      ),
    );
  }
}
