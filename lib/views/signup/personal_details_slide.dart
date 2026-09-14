import 'package:flutter/material.dart';

import '../../controllers/signup_controller.dart';
import '../../core/constants/synk_colors.dart';

class PersonalDetailsSlide extends StatelessWidget {
  final SignupController controller;

  const PersonalDetailsSlide({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Tell us about\nyourself.',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -1.5,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This helps customize your community experience.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 32),

                // Name
                _buildField(
                  controller: controller.nameController,
                  label: 'Name',
                  hint: 'Sarah',
                  icon: Icons.person_outline,
                  errorText: controller.nameError,
                  onChanged: (_) => controller.clearNameError(),
                ),
                const SizedBox(height: 16),

                // Birthday
                _buildField(
                  controller: controller.birthdayController,
                  label: 'Birthday',
                  hint: 'DD/MM/YYYY',
                  icon: Icons.cake_outlined,
                  readOnly: true,
                  errorText: controller.birthdayError,
                  onTap: () async {
                    final today = DateTime.now();

                    // Oldest allowed: 90 years old
                    final firstDate = DateTime(
                      today.year - 90,
                      today.month,
                      today.day,
                    );

                    // Youngest allowed: 16 years old
                    final lastDate = DateTime(
                      today.year - 16,
                      today.month,
                      today.day,
                    );

                    // If there is already a birthday selected,
                    // use it as the initial date.
                    DateTime initialDate = DateTime(
                      today.year - 21,
                      today.month,
                      today.day,
                    );

                    if (controller.birthdayController.text.isNotEmpty) {
                      try {
                        final parts = controller.birthdayController.text.split(
                          '/',
                        );

                        if (parts.length == 3) {
                          final day = int.parse(parts[0]);
                          final month = int.parse(parts[1]);
                          final year = int.parse(parts[2]);

                          final existingDate = DateTime(year, month, day);

                          if (!existingDate.isBefore(firstDate) &&
                              !existingDate.isAfter(lastDate)) {
                            initialDate = existingDate;
                          }
                        }
                      } catch (_) {
                        // Keep the default initial date.
                      }
                    }

                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      helpText: 'Select birthday',
                    );

                    if (selectedDate != null) {
                      final day = selectedDate.day.toString().padLeft(2, '0');
                      final month = selectedDate.month.toString().padLeft(
                        2,
                        '0',
                      );
                      final year = selectedDate.year.toString();

                      controller.birthdayController.text = '$day/$month/$year';
                      controller.clearBirthdayError();
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Gender
                const Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Gender selector row
                Row(
                  children: ['Female', 'Male'].map((gender) {
                    final isSelected = controller.selectedGender == gender;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => controller.setGender(gender),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF6F43)
                                : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                            border: controller.genderError != null
                                ? Border.all(
                                    color: const Color(0xFFE53935),
                                    width: 1.2,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            gender,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.white
                                  : SynkColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (controller.genderError != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      controller.genderError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 120),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: errorText != null
                ? Border.all(color: const Color(0xFFE53935), width: 1.2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onTap: onTap,
            readOnly: readOnly,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              labelText: label,
              labelStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
