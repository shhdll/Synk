import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../controllers/home_discovery_controller.dart';

Future<void> showHomeFilterBottomSheet({
  required BuildContext context,
  required HomeDiscoveryController controller,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FilterBottomSheet(controller: controller),
  );
}

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key, required this.controller});

  final HomeDiscoveryController controller;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late TimeFilterOption _timeOption;
  DateTime? _customDate;
  String? _selectedLocation;
  late final TextEditingController _customLocationController;

  @override
  void initState() {
    super.initState();
    _timeOption = widget.controller.selectedTimeFilter;
    _customDate = widget.controller.customSelectedDate;
    _selectedLocation = widget.controller.selectedLocation;
    _customLocationController = TextEditingController(
      text: _selectedLocation ?? '',
    );
  }

  @override
  void dispose() {
    _customLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: SynkColors.orangeDark,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: SynkColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeOption = TimeFilterOption.customDate;
        _customDate = picked;
      });
    }
  }

  void _apply() {
    final customLoc = _customLocationController.text.trim();
    final locationToApply = customLoc.isNotEmpty ? customLoc : _selectedLocation;

    widget.controller.setTimeFilter(_timeOption, customDate: _customDate);
    widget.controller.setLocationFilter(locationToApply);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _timeOption = TimeFilterOption.all;
      _customDate = null;
      _selectedLocation = null;
      _customLocationController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableLocs = widget.controller.availableLocations;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: SynkColors.orangeDark,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Filter Activities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Time Filter Section
            const Text(
              'Date & Time',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimeChip(TimeFilterOption.all, 'Any Time'),
                _buildTimeChip(TimeFilterOption.today, 'Today'),
                _buildTimeChip(TimeFilterOption.thisWeek, 'This Week'),
                _buildCustomDateChip(),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Location Filter Section
            const Text(
              'Location & Neighborhood',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Location Search Input
            TextField(
              controller: _customLocationController,
              onChanged: (text) {
                setState(() {
                  _selectedLocation = text.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search city or neighborhood...',
                prefixIcon: const Icon(
                  Icons.place_rounded,
                  color: SynkColors.orangeDark,
                  size: 20,
                ),
                suffixIcon: _customLocationController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _customLocationController.clear();
                          setState(() {
                            _selectedLocation = null;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: SynkColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            if (availableLocs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableLocs.map((loc) {
                  final isSelected =
                      _selectedLocation?.toLowerCase() == loc.toLowerCase() ||
                      _customLocationController.text.toLowerCase() ==
                          loc.toLowerCase();

                  return ChoiceChip(
                    label: Text(loc),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLocation = loc;
                          _customLocationController.text = loc;
                        } else {
                          _selectedLocation = null;
                          _customLocationController.clear();
                        }
                      });
                    },
                    selectedColor: SynkColors.orange.withValues(alpha: 0.25),
                    backgroundColor: SynkColors.backgroundLight,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? SynkColors.orangeDark
                          : SynkColors.textPrimary,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? SynkColors.orangeDark
                          : Colors.transparent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 28),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SynkColors.orangeDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(TimeFilterOption option, String label) {
    final isSelected = _timeOption == option;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _timeOption = option;
          _customDate = null;
        });
      },
      selectedColor: SynkColors.orange.withValues(alpha: 0.25),
      backgroundColor: SynkColors.backgroundLight,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? SynkColors.orangeDark : SynkColors.textPrimary,
      ),
      side: BorderSide(
        color: isSelected ? SynkColors.orangeDark : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildCustomDateChip() {
    final isSelected = _timeOption == TimeFilterOption.customDate;
    final dateStr = _customDate != null
        ? '${_customDate!.month}/${_customDate!.day}'
        : 'Pick Date';

    return ActionChip(
      avatar: const Icon(
        Icons.calendar_month_rounded,
        size: 16,
        color: SynkColors.orangeDark,
      ),
      label: Text(isSelected && _customDate != null ? dateStr : 'Custom Date'),
      onPressed: _pickDate,
      backgroundColor: isSelected
          ? SynkColors.orange.withValues(alpha: 0.25)
          : SynkColors.backgroundLight,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? SynkColors.orangeDark : SynkColors.textPrimary,
      ),
      side: BorderSide(
        color: isSelected ? SynkColors.orangeDark : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
