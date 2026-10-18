import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/synk_colors.dart';

class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  static const double size = 46;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;

    return Semantics(
      button: true,
      label: active ? 'Filters, $count active' : 'Filters',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: active ? SynkColors.selected : Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: active ? SynkColors.onSelected : SynkColors.ink,
                  ),
                ),
              ),
            ),
            if (active)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SynkColors.ink,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: SynkColors.background, width: 2),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
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
