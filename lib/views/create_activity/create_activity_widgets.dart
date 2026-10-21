import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';

const Color kFieldErrorColor = Color(0xFFE53935);

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
              child: Text(
                context.l10n.optional,
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

class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key, this.content});

  final String? text;
  // Replaces the plain text, e.g. to add a link. Shown only when [text] is.
  final Widget? content;

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
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kFieldErrorColor,
              ),
              child: content ?? Text(message),
            ),
          ),
        ],
      ),
    );
  }
}

// Keyed by coordinates so a new place rebuilds the map.
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
