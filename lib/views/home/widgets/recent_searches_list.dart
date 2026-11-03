import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';

// "Recent" searches: tap one to run it again, or the cross to remove it.
class RecentSearchesList extends StatelessWidget {
  const RecentSearchesList({
    super.key,
    required this.recent,
    required this.onTap,
    required this.onRemove,
  });

  final List<String> recent;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.recentSearches,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SynkColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        for (final q in recent)
          InkWell(
            onTap: () => onTap(q),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: SynkColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      q,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.removeRecentSearch,
                    onPressed: () => onRemove(q),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
