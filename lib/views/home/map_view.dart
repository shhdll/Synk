import 'package:flutter/material.dart';

import '../../controllers/map_controller.dart';
import '../../core/constants/synk_colors.dart';
import 'widgets/app_header.dart';
import 'widgets/section_label.dart';

// Styled placeholder — no google_maps_flutter package or API key configured
// yet. Swap the body for a real GoogleMap widget once those are in place.
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: AppHeader(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: SectionLabel('Nearby activities'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              SynkColors.backgroundLight,
                              Color(0xFFEFE3D3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -40,
                        left: -30,
                        child: _blob(SynkColors.teal, 180),
                      ),
                      Positioned(
                        bottom: -50,
                        right: -40,
                        child: _blob(SynkColors.orange, 220),
                      ),
                      for (final pin in MapController.pins)
                        _pin(top: pin.top, left: pin.left, color: pin.color),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.map_rounded,
                                size: 32,
                                color: SynkColors.orangeDark,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Map view coming soon',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: SynkColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                "We're working on showing nearby activities on a live map.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: SynkColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color color, double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.20),
      ),
    );
  }

  Widget _pin({
    required double top,
    required double left,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Icon(Icons.location_on_rounded, size: 30, color: color),
    );
  }
}
