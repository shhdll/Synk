import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// Synk's date picker, used everywhere a date is chosen (activity date,
// date filter, birthdays). Monday-first month calendar in a bottom sheet;
// tap the month title to jump between years. Returns null if dismissed.
Future<DateTime?> showSynkDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Pick a date',
  String confirmLabel = 'Set date',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

// Synk's time picker: hour / minute / AM-PM wheels in the same sheet.
Future<TimeOfDay?> showSynkTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Pick a start time',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TimePickerSheet(initialTime: initialTime, title: title),
  );
}

// Bottom sheet frame shared by Synk's pickers: handle, title, content.
class SynkPickerSheet extends StatelessWidget {
  const SynkPickerSheet({super.key, required this.title, required this.child});

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

// Full-width orange gradient button that confirms a picker.
class SynkSheetConfirmButton extends StatelessWidget {
  const SynkSheetConfirmButton({
    super.key,
    required this.label,
    required this.onTap,
  });

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

// Compact month calendar: firstDate..lastDate inclusive, Monday-first
// weeks. The month title switches to a year grid for far-away dates.
class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.confirmLabel,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String confirmLabel;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  static const List<String> _weekdayLabels = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late final DateTime _first = _dateOnly(widget.firstDate);
  late final DateTime _last = _dateOnly(widget.lastDate);
  late DateTime _selected;
  late DateTime _visibleMonth;
  bool _choosingYear = false;
  ScrollController? _yearScroll;

  static const double _yearRowHeight = 52;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void initState() {
    super.initState();
    final initial = _dateOnly(widget.initialDate);
    _selected = initial.isBefore(_first)
        ? _first
        : (initial.isAfter(_last) ? _last : initial);
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  @override
  void dispose() {
    _yearScroll?.dispose();
    super.dispose();
  }

  void _toggleYears() {
    if (!_choosingYear) {
      // Open with the visible year a couple of rows from the top.
      final row = (_last.year - _visibleMonth.year) ~/ 3;
      _yearScroll?.dispose();
      _yearScroll = ScrollController(
        initialScrollOffset: ((row - 2).clamp(0, row) * _yearRowHeight)
            .toDouble(),
      );
    }
    setState(() => _choosingYear = !_choosingYear);
  }

  bool get _canGoPrevious {
    final DateTime previousMonthEnd = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      0,
    );
    return !previousMonthEnd.isBefore(_first);
  }

  bool get _canGoNext {
    final DateTime nextMonthStart = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
    );
    return !nextMonthStart.isAfter(_last);
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

  // Shows [year], keeping the month when it is in range.
  void _pickYear(int year) {
    var month = DateTime(year, _visibleMonth.month);
    final firstMonth = DateTime(_first.year, _first.month);
    final lastMonth = DateTime(_last.year, _last.month);
    if (month.isBefore(firstMonth)) month = firstMonth;
    if (month.isAfter(lastMonth)) month = lastMonth;
    setState(() {
      _visibleMonth = month;
      _choosingYear = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool spansYears = _first.year != _last.year;

    return SynkPickerSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              InkWell(
                onTap: spansYears ? _toggleYears : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${_monthNames[_visibleMonth.month - 1]} '
                        '${_visibleMonth.year}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                      if (spansYears)
                        Icon(
                          _choosingYear
                              ? Icons.arrow_drop_up_rounded
                              : Icons.arrow_drop_down_rounded,
                          color: SynkColors.textPrimary,
                        ),
                    ],
                  ),
                ),
              ),
              if (!_choosingYear)
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
          if (_choosingYear) _buildYearGrid() else ..._buildMonth(),
          const SizedBox(height: 12),
          SynkSheetConfirmButton(
            label: widget.confirmLabel,
            onTap: () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonth() {
    final int daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final int leadingBlanks = (_visibleMonth.weekday - 1) % 7;

    return <Widget>[
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
    ];
  }

  // Newest year first, opened scrolled to the visible year.
  Widget _buildYearGrid() {
    final years = <int>[for (int y = _last.year; y >= _first.year; y--) y];

    return SizedBox(
      height: 280,
      child: GridView.builder(
        controller: _yearScroll,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: _yearRowHeight,
        ),
        itemCount: years.length,
        itemBuilder: (BuildContext context, int index) {
          final int year = years[index];
          final bool isCurrent = year == _visibleMonth.year;
          return Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(21),
              child: InkWell(
                borderRadius: BorderRadius.circular(21),
                onTap: () => _pickYear(year),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    gradient: isCurrent
                        ? const LinearGradient(
                            colors: <Color>[
                              SynkColors.orange,
                              SynkColors.orangeDark,
                            ],
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$year',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isCurrent
                            ? Colors.white
                            : SynkColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(int day) {
    final DateTime cellDate = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      day,
    );
    final bool isDisabled =
        cellDate.isBefore(_first) || cellDate.isAfter(_last);
    final bool isSelected = cellDate == _selected;
    final bool isToday = cellDate == _dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isDisabled ? null : () => setState(() => _selected = cellDate),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected
                  ? const LinearGradient(
                      colors: <Color>[SynkColors.orange, SynkColors.orangeDark],
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

// Compact scroll-wheel time picker (hour / minute / AM-PM).
class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.initialTime, required this.title});

  final TimeOfDay initialTime;
  final String title;

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
    return SynkPickerSheet(
      title: widget.title,
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
          SynkSheetConfirmButton(label: 'Set time', onTap: _confirm),
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
