import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../friends_view.dart';

// The friends button in the home header, next to the bell. Friend requests
// are counted on the bell, where they now live.
class FriendsButton extends StatelessWidget {
  const FriendsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black12,
      child: IconButton(
        tooltip: context.l10n.friends,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FriendsView()),
        ),
        icon: const Icon(
          Icons.people_alt_outlined,
          color: SynkColors.textPrimary,
        ),
      ),
    );
  }
}
