import 'package:flutter/material.dart';

import '../../controllers/add_activity_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';

class AddActivityView extends StatefulWidget {
  const AddActivityView({super.key, required this.activityStore});

  final ActivityStore activityStore;

  @override
  State<AddActivityView> createState() => _AddActivityViewState();
}

class _AddActivityViewState extends State<AddActivityView> {
  late final AddActivityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AddActivityController(activityStore: widget.activityStore);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) _controller.setDate(picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _controller.time ?? TimeOfDay.now(),
    );
    if (picked != null) _controller.setTime(picked);
  }

  void _submit() {
    if (_controller.submit()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'New Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    _field(
                      label: 'Title',
                      controller: _controller.titleController,
                      hint: 'e.g. Padel night at Boulevard',
                      error: _controller.titleError,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        AddActivityController.categories.length,
                        (index) {
                          final selected =
                              _controller.selectedCategory == index;
                          final category =
                              AddActivityController.categories[index];
                          return GestureDetector(
                            onTap: () => _controller.selectCategory(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? SynkColors.orangeDark
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${category['emoji']} ${category['label']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : SynkColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerField(
                            label: 'Date',
                            value: _controller.date == null
                                ? 'Select date'
                                : '${_controller.date!.year}-${_controller.date!.month.toString().padLeft(2, '0')}-${_controller.date!.day.toString().padLeft(2, '0')}',
                            icon: Icons.calendar_today_rounded,
                            onTap: _pickDate,
                            error: _controller.dateError,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _pickerField(
                            label: 'Time',
                            value: _controller.time == null
                                ? 'Select time'
                                : _controller.time!.format(context),
                            icon: Icons.access_time_rounded,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _field(
                      label: 'Location',
                      controller: _controller.locationController,
                      hint: 'e.g. Boulevard World, Riyadh',
                      error: _controller.locationError,
                    ),
                    const SizedBox(height: 20),
                    _field(
                      label: 'Description (optional)',
                      controller: _controller.descriptionController,
                      hint: 'Add any details your group should know',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SynkColors.orangeDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Create Activity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? error,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, color: SynkColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: SynkColors.textSecondary),
            filled: true,
            fillColor: Colors.white,
            errorText: error,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: error != null
                  ? Border.all(color: Colors.red.shade300)
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: SynkColors.orangeDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(fontSize: 12, color: Colors.red.shade400),
          ),
        ],
      ],
    );
  }
}
