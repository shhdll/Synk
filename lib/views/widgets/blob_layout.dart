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

  // The first onboarding slide's layout, also used as the home background.
  // wave = sin(t * pi), reverseWave = cos(t * pi) for an animation t in 0..1.
  factory BlobLayout.intro(Size screenSize, double wave, double reverseWave) {
    final height = screenSize.height;
    return BlobLayout(
      pinkTop: -70 + (wave * 35),
      pinkLeft: -55 + (reverseWave * 30),
      orangeBottom: -90 - (wave * 30),
      orangeRight: -60 - (reverseWave * 25),
      smallTop: height * 0.45 + (wave * 25),
      smallRight: 35 - (reverseWave * 30),
      tealBottom: height * 0.20 - (wave * 25),
      tealLeft: 70 + (reverseWave * 35),
    );
  }

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
