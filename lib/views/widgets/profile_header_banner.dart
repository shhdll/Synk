import 'package:flutter/material.dart';

import '../../models/profile_header.dart';

// The colored or photo header at the top of a profile.
class ProfileHeaderBanner extends StatelessWidget {
  const ProfileHeaderBanner({
    super.key,
    this.styleId,
    this.image,
    this.height = 120,
    this.radius = 20,
  });

  final String? styleId;
  // A header photo; the preset color is shown when null or it fails to load.
  final ImageProvider? image;
  final double height;
  final double radius;

  // The header saved on a public.users row.
  static ProfileHeaderBanner forProfile(
    Map<String, dynamic>? profile, {
    double height = 120,
    double radius = 20,
  }) {
    final url = (profile?['header_url'] as String?)?.trim();
    return ProfileHeaderBanner(
      styleId: profile?['header_style'] as String?,
      image: url != null && url.startsWith('http') ? NetworkImage(url) : null,
      height: height,
      radius: radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: ProfileHeaders.styleFor(styleId).gradient,
      ),
    );
    final photo = image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: photo == null
            ? gradient
            : Image(
                image: photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => gradient,
              ),
      ),
    );
  }
}
