import 'dart:ui';

// Positions for the four decorative blobs on the onboarding background,
// interpolated between slides as the user swipes.
class BlobLayout {
  final double pinkTop;
  final double pinkLeft;
  final double orangeBottom;
  final double orangeRight;
  final double smallTop;
  final double smallRight;
  final double tealBottom;
  final double tealLeft;

  const BlobLayout({
    required this.pinkTop,
    required this.pinkLeft,
    required this.orangeBottom,
    required this.orangeRight,
    required this.smallTop,
    required this.smallRight,
    required this.tealBottom,
    required this.tealLeft,
  });

  static BlobLayout lerp(BlobLayout a, BlobLayout b, double t) {
    return BlobLayout(
      pinkTop: lerpDouble(a.pinkTop, b.pinkTop, t)!,
      pinkLeft: lerpDouble(a.pinkLeft, b.pinkLeft, t)!,
      orangeBottom: lerpDouble(a.orangeBottom, b.orangeBottom, t)!,
      orangeRight: lerpDouble(a.orangeRight, b.orangeRight, t)!,
      smallTop: lerpDouble(a.smallTop, b.smallTop, t)!,
      smallRight: lerpDouble(a.smallRight, b.smallRight, t)!,
      tealBottom: lerpDouble(a.tealBottom, b.tealBottom, t)!,
      tealLeft: lerpDouble(a.tealLeft, b.tealLeft, t)!,
    );
  }
}
