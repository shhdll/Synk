import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/synk_colors.dart';

// Pieces shared by the three Create Activity steps.

const Color kFieldErrorColor = Color(0xFFE53935);

// Section title above each field ("Activity title", "Location", ...).
class CreateGroupLabel extends StatelessWidget {
  const CreateGroupLabel({
    super.key,
    required this.text,
    this.isRequired = false,
    this.optional = false,
  });

  final String text;
  final bool isRequired;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: text),
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: kFieldErrorColor),
                  ),
              ],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
          if (optional) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1F6B7280),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// White rounded card; outlined in red while its field has an error.
class CreateCard extends StatelessWidget {
  const CreateCard({
    super.key,
    required this.child,
    this.hasError = false,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 12),
  });

  final Widget child;
  final bool hasError;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? kFieldErrorColor : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0C1E1C24),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Red message right under a field; renders nothing when [text] is null.
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final message = text;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: kFieldErrorColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kFieldErrorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Non-interactive Google Map centered on a place, with one pin.
//
// Keyed by the coordinates: GoogleMap only reads its camera and markers when
// the platform view is created, so a new place needs a fresh map. Lite mode
// renders it as a static image on Android.
class LiteMapPreview extends StatelessWidget {
  const LiteMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 132,
  });

  final double latitude;
  final double longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    final LatLng target = LatLng(latitude, longitude);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: IgnorePointer(
        child: GoogleMap(
          key: ValueKey<String>('$latitude,$longitude'),
          initialCameraPosition: CameraPosition(target: target, zoom: 15),
          markers: <Marker>{
            Marker(
              markerId: const MarkerId('selected-location'),
              position: target,
            ),
          },
          liteModeEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }
}
