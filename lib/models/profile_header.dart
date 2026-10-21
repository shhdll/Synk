import 'package:flutter/painting.dart';

// A preset profile header. Saved by [id] in public.users.header_style.
class ProfileHeaderStyle {
  const ProfileHeaderStyle(this.id, this.colors, {this.stops});

  final String id;
  final List<Color> colors;
  final List<double>? stops;

  Gradient get gradient => LinearGradient(
    colors: colors,
    stops: stops,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ProfileHeaders {
  ProfileHeaders._();

  static const String defaultId = 'lava';

  // Matches the app's own colors. 'lava' is the original header.
  static const List<ProfileHeaderStyle> synk = <ProfileHeaderStyle>[
    ProfileHeaderStyle(
      'lava',
      <Color>[
        Color(0xFFB6350F),
        Color(0xFFFF8A1E),
        Color(0xFFFFE3B0),
        Color(0xFFFF7A1A),
        Color(0xFFB6350F),
      ],
      stops: <double>[0.0, 0.3, 0.55, 0.78, 1.0],
    ),
    ProfileHeaderStyle('sunset', <Color>[Color(0xFFFF7A36), Color(0xFFFF9EC0)]),
    ProfileHeaderStyle('peach', <Color>[Color(0xFFFF9F5C), Color(0xFFFFE3B0)]),
    ProfileHeaderStyle('sand', <Color>[Color(0xFFC7A06B), Color(0xFFF6E6CC)]),
    ProfileHeaderStyle('teal', <Color>[Color(0xFF2A6F65), Color(0xFF7CCBBE)]),
  ];

  static const List<ProfileHeaderStyle> general = <ProfileHeaderStyle>[
    ProfileHeaderStyle('ocean', <Color>[Color(0xFF1E3A8A), Color(0xFF60A5FA)]),
    ProfileHeaderStyle('lavender', <Color>[
      Color(0xFF6D28D9),
      Color(0xFFC4B5FD),
    ]),
    ProfileHeaderStyle('rose', <Color>[Color(0xFFBE185D), Color(0xFFF9A8D4)]),
    ProfileHeaderStyle('forest', <Color>[Color(0xFF166534), Color(0xFF86EFAC)]),
    ProfileHeaderStyle('sky', <Color>[Color(0xFF0E7490), Color(0xFFA5F3FC)]),
    ProfileHeaderStyle('slate', <Color>[Color(0xFF334155), Color(0xFF94A3B8)]),
    ProfileHeaderStyle('night', <Color>[Color(0xFF111827), Color(0xFF4B5563)]),
  ];

  static ProfileHeaderStyle styleFor(String? id) {
    for (final ProfileHeaderStyle style in <ProfileHeaderStyle>[
      ...synk,
      ...general,
    ]) {
      if (style.id == id) return style;
    }
    return synk.first;
  }
}
