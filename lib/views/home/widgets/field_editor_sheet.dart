import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// Shared bottom-sheet editor for a single text field (name, bio, email, ...)
// on the Edit Profile screen.
class FieldEditorSheet extends StatelessWidget {
  const FieldEditorSheet({
    super.key,
    required this.title,
    required this.controller,
    required this.hint,
    required this.formKey,
    this.validator,
    this.helperText,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
  });

  final String title;
  final TextEditingController controller;
  final String hint;
  final GlobalKey<FormState> formKey;
  final String? Function(String value)? validator;
  final String? helperText;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;

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
        child: Form(
          key: formKey,
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: maxLines,
                maxLength: maxLength,
                keyboardType: keyboardType,
                validator: validator == null
                    ? null
                    : (value) => validator!(value ?? ''),
                style: const TextStyle(
                  fontSize: 14,
                  color: SynkColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: SynkColors.textSecondary),
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
              if (helperText != null) ...[
                const SizedBox(height: 6),
                Text(
                  helperText!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SynkColors.textSecondary.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? true) {
                      Navigator.of(context).pop(true);
                    }
                  },
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
      ),
    );
  }
}
