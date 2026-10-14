import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/home_discovery_controller.dart';
import '../../controllers/map_controller.dart' as map_state;
import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_map_marker.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/app_header.dart';
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

  late final Listenable _changes = Listenable.merge([
    _location,
    _discovery,
    widget.activityStore,
  ]);

  @override
  void initState() {
    super.initState();
    _discovery.addListener(_scheduleMarkerRefresh);
    if (widget.isActive) _start();
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

  List<Activity> get _activities => _discovery.filteredActivities
      .where((a) => a.isPublic && a.hasCoordinates && a.spotsOpen > 0)
      .toList();

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
    await _googleMap?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(activity.latitude!, activity.longitude!),
        14.5,
      ),
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
    _discovery.removeListener(_scheduleMarkerRefresh);
    _googleMap?.dispose();
    _discovery.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppHeader(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Explore activities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    child: IconButton(
                      tooltip: 'Filter activities',
                      icon: const Icon(Icons.tune_rounded, color: SynkColors.textPrimary),
                      onPressed: () => showHomeFilterBottomSheet(
                        context: context,
                        controller: _discovery,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
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
                      ),
                      Positioned(
                        right: 16,
                        bottom: selected == null ? 110 : 220,
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
                          top: 12,
                          left: 16,
                          right: 16,
                          child: _messagePill(_location.locationMessage!),
                        ),
                      if (selected != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 96,
                          child: _activityPreview(selected),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
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
