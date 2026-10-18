import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/home_discovery_controller.dart';
import '../../controllers/map_controller.dart' as map_state;
import '../../core/constants/synk_colors.dart';
import '../../core/constants/interest_emojis.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_map_marker.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/filter_bottom_sheet.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.activityStore,
    required this.isActive,
  });

  final ActivityStore activityStore;
  final bool isActive;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final map_state.MapController _location = map_state.MapController();
  final HomeDiscoveryController _discovery = HomeDiscoveryController();
  final ActivitiesModel _activitiesModel = ActivitiesModel();
  final Map<String, BitmapDescriptor> _iconCache = {};
  final Map<String, BitmapDescriptor> _activityIcons = {};

  GoogleMapController? _googleMap;
  String? _selectedId;
  bool _started = false;
  bool _preparingMarkers = false;
  bool _needsMarkerRefresh = false;

  // Tracks leave and host-transfer changes so markers reload once each.
  late int _seenParticipationVersion;
  bool _isSyncingParticipation = false;
  bool _participationSyncQueued = false;

  late final Listenable _changes = Listenable.merge([
    _location,
    _discovery,
    widget.activityStore,
  ]);

  @override
  void initState() {
    super.initState();
    _discovery.addListener(_scheduleMarkerRefresh);
    _seenParticipationVersion = widget.activityStore.participationVersion;
    widget.activityStore.addListener(_onActivityStoreChanged);
    if (widget.isActive) _start();
  }

  void _onActivityStoreChanged() {
    final version = widget.activityStore.participationVersion;
    if (version == _seenParticipationVersion) return;

    _seenParticipationVersion = version;
    _syncAfterParticipationChange();
  }

  // Reloads markers and spots after leaving; at most one request at a time.
  // Before the map is first opened there is nothing to refresh.
  Future<void> _syncAfterParticipationChange() async {
    if (!_started) return;

    if (_isSyncingParticipation) {
      _participationSyncQueued = true;
      return;
    }

    _isSyncingParticipation = true;
    try {
      do {
        _participationSyncQueued = false;
        if (!mounted) return;
        await _refreshActivities();
      } while (_participationSyncQueued);
    } finally {
      _isSyncingParticipation = false;
    }
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _start();
  }

  Future<void> _start() async {
    if (!_started) {
      _started = true;
      _discovery.init();
    }
    await _centerOnUser();
  }

  Future<void> _centerOnUser() async {
    await _location.locateUser();
    if (!mounted) return;
    final target = _location.userLocation;
    if (target != null) {
      await _googleMap?.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
    }
  }

  // Match Home's category chips and filtering logic.
  static final List<String> _presetCategories = kInterestEmojis.keys.toList();

  List<Activity> get _activities => _discovery.filteredActivities
      .where((a) => a.isPublic && a.hasCoordinates && a.spotsOpen > 0)
      .toList();

  List<String> get _categories =>
      _discovery.categoriesInFeed(_presetCategories);

  void _setQuickCategory(String? category) {
    final current = _discovery.selectedCategory;
    if (category == null) {
      if (current != null) _discovery.setCategoryFilter(null);
    } else if (category != current) {
      _discovery.setCategoryFilter(category);
    }
    setState(() => _selectedId = null);
    _scheduleMarkerRefresh();
  }

  Activity? _selectedActivity(List<Activity> activities) {
    for (final activity in activities) {
      if (activity.id == _selectedId) return activity;
    }
    return null;
  }

  void _scheduleMarkerRefresh() {
    if (!mounted) return;
    _needsMarkerRefresh = true;
    if (_preparingMarkers) return;
    unawaited(_prepareMarkers());
  }

  Future<void> _prepareMarkers() async {
    _preparingMarkers = true;
    try {
      while (_needsMarkerRefresh && mounted) {
        _needsMarkerRefresh = false;
        final activities = _activities;
        final icons = <String, BitmapDescriptor>{};
        for (final activity in activities) {
          final visual = ActivityVisual.of(activity);
          final selected = activity.id == _selectedId;
          final key = '${visual.icon.codePoint}:${visual.icon.fontFamily}:$selected';
          var bitmap = _iconCache[key];
          if (bitmap == null) {
            bitmap = await ActivityMapMarker.create(visual.icon, selected: selected);
            _iconCache[key] = bitmap;
          }
          icons[activity.id] = bitmap;
        }
        if (!mounted) return;
        setState(() {
          _activityIcons
            ..clear()
            ..addAll(icons);
        });
      }
    } catch (error) {
      debugPrint('SYNK: Could not create map markers: $error');
    } finally {
      _preparingMarkers = false;
    }
  }

  Set<Marker> _markers(List<Activity> activities) {
    return activities.map((activity) {
      return Marker(
        markerId: MarkerId(activity.id),
        position: LatLng(activity.latitude!, activity.longitude!),
        icon: _activityIcons[activity.id] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: const Offset(0.5, 0.95),
        zIndexInt: activity.id == _selectedId ? 1 : 0,
        onTap: () => _selectActivity(activity),
      );
    }).toSet();
  }

  Future<void> _selectActivity(Activity activity) async {
    setState(() => _selectedId = activity.id);
    _scheduleMarkerRefresh();

    final controller = _googleMap;
    if (controller == null) return;

    // Center on the activity first, then shift the map so the enlarged pin
    // sits comfortably above the activity preview and bottom navigation.
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(activity.latitude!, activity.longitude!),
        14.5,
      ),
    );
    if (!mounted || _selectedId != activity.id) return;

    // Google Maps scrollBy uses map-view pixel offsets. A positive vertical
    // offset moves the map contents up, leaving the selected pin higher.
    final height = MediaQuery.sizeOf(context).height;
    final upwardOffset = (height * 0.17).clamp(100.0, 190.0);
    await controller.animateCamera(
      CameraUpdate.scrollBy(0, upwardOffset),
    );
  }

  Future<void> _refreshActivities() async {
    try {
      widget.activityStore.setFeed(await _activitiesModel.fetchPublicFeed());
    } catch (_) {
      // Retain the current feed if refreshing fails.
    }
    await _discovery.loadFeed(isSilent: true);
  }

  void _openDetails(Activity activity) {
    showActivityDetailsSheet(
      context: context,
      activity: activity,
      activityStore: widget.activityStore,
      onParticipationChanged: _refreshActivities,
    );
  }

  @override
  void dispose() {
    widget.activityStore.removeListener(_onActivityStoreChanged);
    _discovery.removeListener(_scheduleMarkerRefresh);
    _googleMap?.dispose();
    _discovery.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Reserve room for the floating MainShell navigation bar and Create button.
    return Scaffold(
      backgroundColor: SynkColors.background,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _changes,
        builder: (context, _) {
          final activities = _activities;
          final selected = _selectedActivity(activities);
          return Stack(
            fit: StackFit.expand,
            children: [
              GoogleMap(
                key: const ValueKey('synk-google-map'),
                initialCameraPosition: CameraPosition(
                  target: _location.initialCenter,
                  zoom: 12.5,
                ),
                onMapCreated: (controller) {
                  _googleMap = controller;
                  final current = _location.userLocation;
                  if (current != null) {
                    unawaited(controller.animateCamera(
                      CameraUpdate.newLatLngZoom(current, 14),
                    ));
                  }
                  _scheduleMarkerRefresh();
                },
                onTap: (_) {
                  setState(() => _selectedId = null);
                  _scheduleMarkerRefresh();
                },
                markers: _markers(activities),
                myLocationEnabled: _location.userLocation != null,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                padding: EdgeInsets.only(
                  top: topInset + 145,
                  bottom: selected == null ? bottomInset + 115 : bottomInset + 225,
                ),
              ),
              Positioned(
                top: topInset + 12,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 5,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(30),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
                        child: Row(
                          children: [
                            const Icon(Icons.map_outlined,
                                color: SynkColors.orangeDark),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('Explore activities',
                                style: TextStyle(fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: SynkColors.textPrimary)),
                            ),
                            IconButton(
                              tooltip: 'More filters',
                              icon: const Icon(Icons.tune_rounded,
                                  color: SynkColors.textPrimary),
                              onPressed: () => showHomeFilterBottomSheet(
                                context: context,
                                controller: _discovery,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _categoryChip('All', null),
                          for (final category in _categories)
                            _categoryChip(category, category),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: selected == null
                    ? bottomInset + 110
                    : bottomInset + 235,
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'My location',
                    onPressed: _location.isLocating ? null : _centerOnUser,
                    icon: _location.isLocating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded,
                            color: SynkColors.textPrimary),
                  ),
                ),
              ),
              if (_location.locationMessage != null)
                Positioned(
                  top: topInset + 132,
                  left: 16,
                  right: 16,
                  child: _messagePill(_location.locationMessage!),
                ),
              if (selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 145,
                  child: _activityPreview(selected),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryChip(String label, String? category) {
    final selected = _discovery.selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? SynkColors.textPrimary
            : Colors.white.withValues(alpha: 0.7),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? SynkColors.textPrimary
                : SynkColors.textSecondary.withValues(alpha: 0.22),
          ),
        ),
        child: InkWell(
          onTap: () => _setQuickCategory(category),
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : SynkColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messagePill(String message) => Material(
        elevation: 2,
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: SynkColors.textPrimary),
          ),
        ),
      );

  Widget _activityPreview(Activity activity) {
    return Material(
      color: Colors.white,
      elevation: 5,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openDetails(activity),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ActivityThumbnail(activity: activity, size: 74, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activity.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SynkColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${activity.spotsOpen} ${activity.spotsOpen == 1 ? 'spot' : 'spots'} available',
                      style: const TextStyle(
                        color: SynkColors.orangeDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: SynkColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
