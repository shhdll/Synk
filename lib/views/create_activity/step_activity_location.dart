import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/create_activity_controller.dart';
import '../../core/constants/activity_constants.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/place_search_model.dart';
import 'location_search_sheet.dart';

// Step 1 of the Create Activity wizard: what the activity is, and where.
//
// Writes straight into [CreateActivityController]; the wizard shell decides
// when the step is complete by asking the controller, never by asking this
// widget.
class StepActivityLocation extends StatefulWidget {
  const StepActivityLocation({super.key, required this.controller});

  final CreateActivityController controller;

  @override
  State<StepActivityLocation> createState() => _StepActivityLocationState();
}

class _StepActivityLocationState extends State<StepActivityLocation> {
  CreateActivityController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // The title lives in a plain TextEditingController, so the counter and the
    // inline hint need their own rebuild as the user types.
    _c.titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _c.titleController.removeListener(_onTitleChanged);
    super.dispose();
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Location picking
  // ---------------------------------------------------------------------------

  Future<void> _openLocationPicker() async {
    final PlaceSuggestion? place = await showModalBottomSheet<PlaceSuggestion?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => const LocationSearchSheet(),
    );

    if (!mounted || place == null) return;
    _c.setPlace(
      name: place.name,
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    setState(() {});
  }

  void _clearLocation() {
    _c.clearPlace();
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final String title = _c.titleController.text;
    final bool hasLocation = _c.locationName.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        const _GroupLabel(text: 'ACTIVITY'),
        const SizedBox(height: 10),
        _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: SynkColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Activity title',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: _c.titleController,
                      maxLength: ActivityConstants.titleMaxLength,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Morning padel at Al Nakheel',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB6B3BD),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${title.characters.length}'
                        '/${ActivityConstants.titleMaxLength}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Short and specific works best — people decide from this line.',
            style: TextStyle(fontSize: 13, color: SynkColors.textSecondary),
          ),
        ),
        const SizedBox(height: 26),
        _GroupLabel(
          text: 'LOCATION',
          trailing: hasLocation ? const _SelectedBadge() : null,
        ),
        const SizedBox(height: 10),
        if (hasLocation)
          _SelectedLocationCard(
            name: _c.locationName,
            address: _c.locationAddress,
            latitude: _c.latitude,
            longitude: _c.longitude,
            onTap: _openLocationPicker,
            onClear: _clearLocation,
          )
        else
          _EmptyLocationCard(onTap: _openLocationPicker),
        const SizedBox(height: 12),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

// Small caps section header ("ACTIVITY" / "LOCATION"), matching Step 2's
// label style and the approved mockup.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: SynkColors.textSecondary,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// Small teal "Selected" tag shown beside LOCATION once a place is chosen.
class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.check_circle_rounded, size: 13, color: SynkColors.teal),
        SizedBox(width: 4),
        Text(
          'Selected',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SynkColors.teal,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F1E1C24),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Nothing chosen yet: a polished discovery prompt rather than a settings
// row — gradient search badge, strong hierarchy, and an explicit "Search"
// affordance instead of a bare chevron.
class _EmptyLocationCard extends StatelessWidget {
  const _EmptyLocationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: <Color>[SynkColors.orange, SynkColors.orangeDark],
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x40FF7A36),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  size: 23,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Choose a location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Search for the venue — café, park, gym…',
                      style: TextStyle(
                        fontSize: 13,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: SynkColors.orange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      size: 15,
                      color: SynkColors.orangeDark,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.orangeDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A place is chosen: preview panel + name + address, the whole card tappable.
class _SelectedLocationCard extends StatelessWidget {
  const _SelectedLocationCard({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.onTap,
    required this.onClear,
  });

  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final double? lat = latitude;
    final double? lng = longitude;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            (lat != null && lng != null)
                ? _LocationMapPreview(
                    latitude: lat,
                    longitude: lng,
                    onTap: onTap,
                    onClear: onClear,
                  )
                : _MapPreviewPlaceholder(onTap: onTap, onClear: onClear),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.place_rounded,
                    size: 20,
                    color: SynkColors.orangeDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        if (address != null && address!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: SynkColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: SynkColors.orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.orangeDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A compact, non-interactive Google Map preview centered on the selected
// place, with a single marker at that location.
//
// Keyed by the coordinates: GoogleMap only reads initialCameraPosition and
// markers the first time its underlying platform view is created, so
// changing them on an already-built GoogleMap does not move the camera or
// the pin. Giving it a ValueKey derived from lat/lng means a new selection
// (different key) makes Flutter tear down the old element and build a fresh
// GoogleMap — which re-reads initialCameraPosition/markers on creation and
// therefore recenters correctly. Same key (same coordinates) is left alone,
// so re-tapping the same place doesn't needlessly rebuild the native view.
//
// Wrapped in IgnorePointer so the map never intercepts gestures: this is a
// preview, not a real map screen, so taps fall through to the surrounding
// InkWell and still open the location picker — no pan/zoom/toolbar/
// navigation is introduced. liteModeEnabled renders it as a lightweight
// static image on Android (our configured/tested platform for this).
class _LocationMapPreview extends StatelessWidget {
  const _LocationMapPreview({
    required this.latitude,
    required this.longitude,
    required this.onTap,
    required this.onClear,
  });

  final double latitude;
  final double longitude;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final LatLng target = LatLng(latitude, longitude);

    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IgnorePointer(
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
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textSecondary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _MapClearButton(onTap: onClear),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.edit_location_alt_outlined,
                        size: 15,
                        color: SynkColors.orangeDark,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Tap to change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small round "clear" control shown at the top-right of both map preview
// states — a distinct action from "Change" (which reopens search): this one
// removes the selected location entirely, via the same onClear callback the
// card's own close button used to call.
class _MapClearButton extends StatelessWidget {
  const _MapClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCCFFFFFF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(
            Icons.close_rounded,
            size: 15,
            color: SynkColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// Fallback for the (unexpected) case where a location is selected but its
// coordinates are missing — keeps the UI safe without force-unwrapping.
class _MapPreviewPlaceholder extends StatelessWidget {
  const _MapPreviewPlaceholder({required this.onTap, required this.onClear});

  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  SynkColors.backgroundLight,
                  SynkColors.beige,
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1F1E1C24),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.place_rounded,
                color: SynkColors.orangeDark,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textSecondary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _MapClearButton(onTap: onClear),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.edit_location_alt_outlined,
                        size: 15,
                        color: SynkColors.orangeDark,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Tap to change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
