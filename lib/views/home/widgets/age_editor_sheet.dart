import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../widgets/synk_date_picker.dart';

// Bottom-sheet editor for age. Mirrors the signup flow: age is derived
// from a birthday picked with the same 16-65 year restriction, in the
// same DD/MM/YYYY format, rather than being typed in directly.
class AgeEditorSheet extends StatefulWidget {
  const AgeEditorSheet({super.key, required this.currentAge});

  final int? currentAge;

  @override
  State<AgeEditorSheet> createState() => _AgeEditorSheetState();
}

class _AgeEditorSheetState extends State<AgeEditorSheet> {
  late final TextEditingController _birthdayController;
  int? _selectedAge;
  String? _error;

  @override
  void initState() {
    super.initState();
    _birthdayController = TextEditingController();
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final today = DateTime.now();

    // Oldest allowed: 65 years old.
    final firstDate = DateTime(today.year - 65, today.month, today.day);

    // Youngest allowed: 16 years old.
    final lastDate = DateTime(today.year - 16, today.month, today.day);

    final initialDate = DateTime(
      today.year - (widget.currentAge ?? 21),
      today.month,
      today.day,
    );

    final selectedDate = await showSynkDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : (initialDate.isAfter(lastDate) ? lastDate : initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
      title: 'Select birthday',
      confirmLabel: 'Set birthday',
    );

    if (selectedDate == null) return;

    var age = today.year - selectedDate.year;
    if (today.month < selectedDate.month ||
        (today.month == selectedDate.month && today.day < selectedDate.day)) {
      age--;
    }

    final day = selectedDate.day.toString().padLeft(2, '0');
    final month = selectedDate.month.toString().padLeft(2, '0');
    setState(() {
      _birthdayController.text = '$day/$month/${selectedDate.year}';
      _selectedAge = age;
      _error = null;
    });
  }

  void _save() {
    if (_selectedAge == null) {
      setState(() => _error = 'Select your birthday');
      return;
    }
    Navigator.of(context).pop(_selectedAge);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Text(
              'Edit age',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _birthdayController,
              readOnly: true,
              onTap: _pickBirthday,
              style: const TextStyle(
                fontSize: 14,
                color: SynkColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'DD/MM/YYYY',
                hintStyle: const TextStyle(color: SynkColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.cake_outlined,
                  color: SynkColors.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white,
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
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE53935),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SynkColors.orangeDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
