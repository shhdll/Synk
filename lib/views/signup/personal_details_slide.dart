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
                  onChanged: (_) {
                    if (controller.nameError != null) {
                      controller.nameError = null;
                      controller.notifyListeners();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Age
                _buildField(
                  controller: controller.ageController,
                  label: 'Age',
                  hint: '21',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  errorText: controller.ageError,
                  onChanged: (_) {
                    if (controller.ageError != null) {
                      controller.ageError = null;
                      controller.notifyListeners();
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
