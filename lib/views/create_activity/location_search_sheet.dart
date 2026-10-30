import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/map_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/place_search_model.dart';

// Search for a place, tap a place pin, or tap anywhere on the map. The chosen
// spot gets a marker, and "Use this location" pops it as a resolved
// [PlaceSuggestion].
class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({super.key, this.initialPlace, this.confirmLabel});

  /// The place already chosen, shown on the map when the sheet opens.
  final PlaceSuggestion? initialPlace;

  /// The button's label; "Use this location" by default.
  final String? confirmLabel;

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  static const Duration _debounce = Duration(milliseconds: 300);

  final PlaceSearchModel _model = PlaceSearchModel();
  final TextEditingController _query = TextEditingController();
  late final String _sessionToken = PlaceSearchModel.newSessionToken();

  Timer? _debounceTimer;
  List<PlaceSuggestion> _results = const <PlaceSuggestion>[];
  bool _isSearching = false;
  bool _isResolving = false; // true while a tapped suggestion's Details load
  // Hidden once a result is picked, until the search text changes again.
  bool _resultsHidden = false;
  String? _errorMessage;

  GoogleMapController? _map;
  bool _isLocating = false;
  int _tapVersion = 0;

  // The spot with the marker. Its name is null while the address loads.
  LatLng? _selectedPoint;
  PlaceSuggestion? _selected;

  @override
  void initState() {
    super.initState();
    final PlaceSuggestion? initial = widget.initialPlace;
    if (initial != null && initial.hasCoordinates) {
      _selectedPoint = LatLng(initial.latitude!, initial.longitude!);
      _selected = initial;
    }
    _query.addListener(_onQueryTextChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryTextChanged);
    _debounceTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryTextChanged() {
    if (mounted) setState(() {});
  }

  void _onQueryChanged(String value) {
    _resultsHidden = false;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _search(value));
  }

  void _clearQuery() {
    _debounceTimer?.cancel();
    _query.clear();
    _search('');
  }

  Future<void> _search(String value) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _results = const <PlaceSuggestion>[];
          _errorMessage = null;
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final List<PlaceSuggestion> results = await _model.search(
        trimmed,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;

      if (_query.text.trim() != trimmed) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } on PlaceSearchException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = error.message;
      });
    }
  }

  // A search result: load its coordinates and show it on the map.
  Future<void> _selectResult(PlaceSuggestion suggestion) async {
    if (_isResolving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final PlaceSuggestion resolved = await _model.getDetails(
        suggestion,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      _tapVersion++;
      final LatLng point = LatLng(resolved.latitude!, resolved.longitude!);
      setState(() {
        _isResolving = false;
        _resultsHidden = true;
        _selectedPoint = point;
        _selected = resolved;
      });
      unawaited(_map?.animateCamera(CameraUpdate.newLatLngZoom(point, 16)));
    } on PlaceSearchException catch (error) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _errorMessage = error.message;
      });
    }
  }

  // A tap on one of Google's place pins: use that place, name and all.
  // Not reported on iOS, where the tap lands in [_onMapTap] instead.
  Future<void> _onPointOfInterestTap(PointOfInterestId id) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final int version = ++_tapVersion;
    setState(() {
      _isResolving = true;
      _resultsHidden = true;
      _errorMessage = null;
    });

    PlaceSuggestion? place;
    String? problem;
    try {
      place = await _model.getPointOfInterest(id.value);
    } on PlaceSearchException catch (error) {
      problem = error.message;
    }

    if (!mounted) return;
    setState(() {
      _isResolving = false;
      // A later tap has already moved the marker.
      if (version != _tapVersion) return;
      _errorMessage = problem;
      if (place != null) {
        _selectedPoint = LatLng(place.latitude!, place.longitude!);
        _selected = place;
      }
    });
  }

  // A tap on the map: drop the marker there and look up its address with
  // the phone's own geocoder.
  Future<void> _onMapTap(LatLng point) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final int version = ++_tapVersion;
    final Locale locale = Localizations.localeOf(context);
    setState(() {
      _resultsHidden = true;
      _selectedPoint = point;
      _selected = null;
    });

    Placemark? placemark;
    try {
      final List<Placemark> results = await Geocoding()
          .placemarkFromCoordinates(
            point.latitude,
            point.longitude,
            locale: locale,
          );
      if (results.isNotEmpty) placemark = results.first;
    } catch (error) {
      debugPrint('SYNK: reverse geocoding failed: $error');
    }

    if (!mounted || version != _tapVersion) return;
    setState(() => _selected = _placeFor(placemark, point));
  }

  static PlaceSuggestion _placeFor(Placemark? placemark, LatLng point) {
    // Saudi results often carry short-address codes and building numbers
    // ("RAWA3091", "6747"); skip anything with digits.
    final List<String> parts = <String>[];
    for (final String? value in <String?>[
      placemark?.name,
      placemark?.thoroughfare,
      placemark?.subLocality,
      placemark?.locality,
    ]) {
      final String? trimmed = value?.trim();
      if (trimmed == null ||
          trimmed.isEmpty ||
          RegExp(r'[0-9٠-٩]').hasMatch(trimmed) ||
          parts.contains(trimmed)) {
        continue;
      }
      parts.add(trimmed);
    }

    return PlaceSuggestion(
      placeId: '',
      name: parts.isNotEmpty ? parts.first : appL10n.pinnedLocation,
      address: parts.length > 1 ? parts.skip(1).join(', ') : null,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  Future<void> _goToMyLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    String? problem;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = appL10n.pleaseEnableLocationServicesToFind;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          problem = appL10n.locationPermissionWasDenied;
        } else {
          final Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );
          await _map?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              16,
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('SYNK: locating for map picker failed: $error');
      problem = appL10n.unableToRetrieveYourLocationShowing;
    }

    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _errorMessage = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool showResults =
        _query.text.trim().isNotEmpty && !_resultsHidden && !_isResolving;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          // Opened with useSafeArea, so this stays below the status bar.
          height: math.min(
            MediaQuery.sizeOf(context).height * 0.85,
            constraints.maxHeight - keyboard - 12,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: SynkColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x331E1C24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.searchForAPlace,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _buildSearchField(),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Color(0xFFE53935),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: <Widget>[
                      _buildMap(),
                      if (showResults) Positioned.fill(child: _buildResults()),
                      if (_isResolving)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x66FFFFFF),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  SynkColors.orangeDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!showResults)
                        PositionedDirectional(
                          end: 12,
                          bottom: 12,
                          child: _buildMyLocationButton(),
                        ),
                    ],
                  ),
                ),
              ),
              // Steps aside for the keyboard so the map keeps some room.
              if (keyboard == 0 && _selectedPoint != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildSelectedPlace(),
                const SizedBox(height: 12),
                _buildConfirmButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _query,
        onChanged: _onQueryChanged,
        onTap: () {
          if (_resultsHidden) setState(() => _resultsHidden = false);
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: SynkColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: context.l10n.locationSearchHint,
          hintStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFFB6B3BD),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 21,
            color: SynkColors.textSecondary,
          ),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        SynkColors.orangeDark,
                      ),
                    ),
                  ),
                )
              : (_query.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearQuery,
                        tooltip: context.l10n.clearSearch,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: SynkColors.textSecondary,
                        ),
                      )
                    : null),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final LatLng? point = _selectedPoint;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: point ?? MapController.defaultCenter,
        zoom: point == null ? 12 : 16,
      ),
      onMapCreated: (GoogleMapController controller) => _map = controller,
      onTap: _onMapTap,
      onPointOfInterestTap: _onPointOfInterestTap,
      markers: <Marker>{
        if (point != null)
          Marker(markerId: const MarkerId('chosen-place'), position: point),
      },
      // Keeps map drags from dragging the sheet.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
    );
  }

  // Search results float over the map.
  Widget _buildResults() {
    return ColoredBox(
      color: SynkColors.background.withValues(alpha: 0.96),
      child: _results.isEmpty
          ? _EmptySearchState(
              text: _isSearching ? '' : context.l10n.noMatchesFound,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final PlaceSuggestion suggestion = _results[index];
                return _PlaceResultRow(
                  suggestion: suggestion,
                  onTap: () => _selectResult(suggestion),
                );
              },
            ),
    );
  }

  Widget _buildMyLocationButton() {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        onPressed: _isLocating ? null : _goToMyLocation,
        tooltip: context.l10n.myLocation,
        icon: _isLocating
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    SynkColors.orangeDark,
                  ),
                ),
              )
            : const Icon(
                Icons.my_location_rounded,
                size: 20,
                color: SynkColors.orangeDark,
              ),
      ),
    );
  }

  Widget _buildSelectedPlace() {
    final PlaceSuggestion? place = _selected;
    final String? address = place?.address;

    return Row(
      children: <Widget>[
        Container(
          height: 38,
          width: 38,
          decoration: const BoxDecoration(
            color: Color(0x1FFF7A36),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.place_rounded,
            size: 19,
            color: SynkColors.orangeDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                place?.name ?? context.l10n.findingAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: place == null
                      ? SynkColors.textSecondary
                      : SynkColors.textPrimary,
                ),
              ),
              if (address != null && address.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SynkColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    final PlaceSuggestion? place = _selected;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: place == null
            ? null
            : () => Navigator.of(context).pop(place),
        style: ElevatedButton.styleFrom(
          backgroundColor: SynkColors.orangeDark,
          disabledBackgroundColor: SynkColors.orangeDark.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          widget.confirmLabel ?? context.l10n.useThisLocation,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

class _PlaceResultRow extends StatelessWidget {
  const _PlaceResultRow({required this.suggestion, required this.onTap});

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? address = suggestion.address;
    final bool hasAddress = address != null && address.isNotEmpty;

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: hasAddress
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                height: 38,
                width: 38,
                decoration: const BoxDecoration(
                  color: Color(0x1FFF7A36),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  size: 19,
                  color: SynkColors.orangeDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      suggestion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    if (hasAddress) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ],
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

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 44,
              width: 44,
              decoration: const BoxDecoration(
                color: Color(0x1FFF7A36),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 21,
                color: SynkColors.orangeDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SynkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
