import 'package:flutter/material.dart';

import '../../../models/avatar_uploader.dart';

// A round profile photo, falling back to the default avatar for the gender.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.gender,
    this.size = 44,
  });

  final String? avatarUrl;
  final String? gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final fallback = AvatarUploader.defaultImageForGender(gender);

    return ClipOval(
      child: Image(
        image: url != null && url.startsWith('http')
            ? NetworkImage(url)
            : fallback,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image(
          image: fallback,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
