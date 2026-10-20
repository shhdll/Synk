import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';

class AddActivityView extends StatelessWidget {
  const AddActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 20, 8),
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
                  Text(
                    context.l10n.newActivity,
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
          ],
        ),
      ),
    );
  }
}
