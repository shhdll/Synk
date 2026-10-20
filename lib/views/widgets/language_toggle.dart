import 'package:flutter/material.dart';

import '../../controllers/language_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';

// EN | ع switch. The highlight slides to the language in use, and one tap
// changes the app's language right away.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  static const double _segmentWidth = 38;
  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    final language = LanguageController.instance;

    return ListenableBuilder(
      listenable: language,
      builder: (context, _) {
        final isArabic = language.isArabic;

        Widget segment(String text, bool active) => SizedBox(
          width: _segmentWidth,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : SynkColors.textSecondary,
              ),
              child: Text(text),
            ),
          ),
        );

        return Semantics(
          button: true,
          label: context.l10n.language,
          value: isArabic
              ? context.l10n.languageArabic
              : context.l10n.languageEnglish,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => language.setLocale(Locale(isArabic ? 'en' : 'ar')),
            child: Container(
              height: _height,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_height / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              // Same order in both languages, so the highlight visibly moves.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SizedBox(
                  width: _segmentWidth * 2,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: isArabic
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: _segmentWidth,
                            decoration: BoxDecoration(
                              color: SynkColors.orangeDark,
                              borderRadius: BorderRadius.circular(_height / 2),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          segment('EN', !isArabic),
                          segment('ع', isArabic),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
