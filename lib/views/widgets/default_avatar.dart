import 'package:flutter/material.dart';

import '../../models/avatar_uploader.dart';
import 'anonymous_avatar.dart';

// The default avatar for a gender, never a real photo. Shown for anyone in
// a block with the viewer, in either direction: Synk's female or male
// default, or the general one when the gender is missing or unknown.
class DefaultAvatar extends StatelessWidget {
  const DefaultAvatar({super.key, required this.gender, required this.size});

  final String? gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clean = gender?.trim().toLowerCase();
    if (clean != 'female' && clean != 'male') {
      return AnonymousAvatar(size: size);
    }
    return ClipOval(
      child: Image(
        image: AvatarUploader.defaultImageForGender(clean),
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
