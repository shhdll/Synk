import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/friends_model.dart';
import 'user_avatar.dart';

// Pieces shared by the friends, find people and blocked users screens.

class FriendsSearchField extends StatelessWidget {
  const FriendsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(
      color: SynkColors.textSecondary.withValues(alpha: 0.14),
    );

    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: SynkColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: SynkColors.textSecondary.withValues(alpha: 0.8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: SynkColors.textSecondary,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.clearSearch,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: SynkColors.textSecondary,
                  ),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: border,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: SynkColors.orange),
          ),
        ),
      ),
    );
  }
}

// White rounded card, matching the join request cards.
class FriendsCardBox extends StatelessWidget {
  const FriendsCardBox({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// A card of rows split by thin dividers.
class FriendsListCard extends StatelessWidget {
  const FriendsListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FriendsCardBox(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                  color: SynkColors.textSecondary.withValues(alpha: 0.10),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

// Avatar, name and @username, with an action at the end.
class FriendsPersonRow extends StatelessWidget {
  const FriendsPersonRow({
    super.key,
    required this.user,
    required this.trailing,
    this.onTap,
    this.subtitle,
  });

  final FriendUser user;
  final Widget trailing;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final username = user.username;
    final line =
        subtitle ??
        (username != null && username.isNotEmpty ? '@$username' : null);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
        child: Row(
          children: [
            UserAvatar(avatarUrl: user.avatarUrl, gender: user.gender),
            const SizedBox(width: 12),
            Expanded(
              child: FriendsNameAndSubtitle(name: user.name, subtitle: line),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class FriendsNameAndSubtitle extends StatelessWidget {
  const FriendsNameAndSubtitle({
    super.key,
    required this.name,
    required this.subtitle,
    this.nameSize = 14,
  });

  final String name;
  final String? subtitle;
  final double nameSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: nameSize,
            fontWeight: FontWeight.w700,
            color: SynkColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
