import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/home_discovery_controller.dart';
import '../../controllers/map_controller.dart' as map_state;
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_filters.dart';
import '../../models/activity_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_map_marker.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/filter_button.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.activityStore,
    required this.discoveryController,
    required this.isActive,
  });

  final ActivityStore activityStore;
  final HomeDiscoveryController discoveryController;
  final bool isActive;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final map_state.MapController _location = map_state.MapController();
  late final HomeDiscoveryController _discovery = widget.discoveryController;
  final ActivitiesModel _activitiesModel = ActivitiesModel();
  final Map<String, BitmapDescriptor> _iconCache = {};
  final Map<String, BitmapDescriptor> _activityIcons = {};

  GoogleMapController? _googleMap;
  String? _selectedId;

  // The Map's own search and filters, separate from Home's.
  final TextEditingController _search = TextEditingController();
  ActivityFilters _filters = ActivityFilters.defaults;

  // Opened via "View on map"; shown even if the filters would hide it.
  Activity? _extra;
  Activity? _pendingFocus;

  // Activity ids in swipe order.
  List<String> _swipeOrder = const [];
  PageController? _pageController;
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
    widget.activityStore.addListener(_takeFocus);
    if (widget.isActive) _start();
    _takeFocus();
  }

  void _takeFocus() {
    final focus = widget.activityStore.takeMapFocus();
    if (focus == null || !focus.hasCoordinates) return;
    _extra = focus;
    if (_googleMap == null) {
      _pendingFocus = focus;
    } else {
      _onPinTap(focus);
    }
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _start();
  }

  Future<void> _start() async {
    _discovery.init();
    await _centerOnUser(unlessSelected: true);
  }

  Future<void> _centerOnUser({bool unlessSelected = false}) async {
    await _location.locateUser();
    if (!mounted) return;
    // Don't pull the camera away from an activity opened via "View on map".
    if (unlessSelected && _selectedId != null) return;
    final target = _location.userLocation;
    if (target != null) {
      await _googleMap?.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
    }
  }

  GeoPoint? get _userPoint {
    final here = _location.userLocation;
    if (here == null) return _discovery.userLocation;
    return (latitude: here.latitude, longitude: here.longitude);
  }

  // Activities that can be shown on the map. Full ones stay, so people can
  // still find them and join the waitlist.
  static bool _mappable(Activity a) => a.isPublic && a.hasCoordinates;

  // In the chosen sort order, which is also the swipe order of the cards.
  List<Activity> _filtered(ActivityFilters filters) => filters.apply(
    _discovery.allActivities.where(_mappable),
    userLocation: _userPoint,
    search: _search.text,
  );

  List<Activity> get _activities {
    final list = _filtered(_filters);
    final extra = _extra;
    if (extra != null && !list.any((a) => a.id == extra.id)) list.add(extra);
    return list;
  }

  List<String> get _categories {
    final labels = _discovery.categoriesInFeed(
      HomeDiscoveryController.knownCategories,
    );
    for (final selected in _filters.categories) {
      if (!labels.contains(selected)) labels.add(selected);
    }
    return labels;
  }

  void _setFilters(ActivityFilters filters) {
    setState(() => _filters = filters);
    _clearSelection();
  }

  // null = All
  void _setQuickCategory(String? category) {
    _setFilters(
      category == null
          ? _filters.copyWith(categories: const {})
          : _filters.toggleCategory(category),
    );
  }

  void _openFilters() {
    showMapFilterBottomSheet(
      context: context,
      controller: _discovery,
      filters: _filters,
      countFor: (draft) => _filtered(draft).length,
      onApply: _setFilters,
      onSortPicked: _showSorted,
      hasLocation: _userPoint != null,
    );
  }

  // Opens the cards on the first activity of the new order; swiping moves
  // through the rest in that order.
  void _showSorted(ActivityFilters filters) {
    setState(() {
      _filters = filters;
      _extra = null;
    });
    final sorted = _activities;
    if (sorted.isEmpty) {
      _clearSelection();
      SynkFeedback.showToast(
        context,
        title: context.l10n.noMatchesTryFewerFilters,
        success: false,
      );
      return;
    }
    _onPinTap(sorted.first);
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
    _preparingMarkers = true;
    // Can notify mid-build from another tab, so defer.
    scheduleMicrotask(_prepareMarkers);
  }

  Future<void> _prepareMarkers() async {
    _preparingMarkers = true;
    try {
      while (_needsMarkerRefresh && mounted) {
        _needsMarkerRefresh = false;
        final spots = _spots(_activities);
        final icons = <String, BitmapDescriptor>{};
        for (final MapEntry(key: spot, value: group) in spots.entries) {
          final visual = ActivityVisual.of(group.first);
          final selected = group.any((a) => a.id == _selectedId);
          final key =
              '${visual.icon.codePoint}:${visual.icon.fontFamily}:$selected:${group.length}';
          var bitmap = _iconCache[key];
          if (bitmap == null) {
            bitmap = await ActivityMapMarker.create(
              visual.icon,
              selected: selected,
              count: group.length,
            );
            _iconCache[key] = bitmap;
          }
          icons[spot] = bitmap;
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

  // Activities within about 10 m of each other share one pin.
  static String _spotKey(Activity a) =>
      '${a.latitude!.toStringAsFixed(4)},${a.longitude!.toStringAsFixed(4)}';

  // Keeps the activities' order inside each spot.
  static Map<String, List<Activity>> _spots(List<Activity> activities) {
    final spots = <String, List<Activity>>{};
    for (final activity in activities) {
      spots.putIfAbsent(_spotKey(activity), () => []).add(activity);
    }
    return spots;
  }

  Set<Marker> _markers(List<Activity> activities) {
    return _spots(activities).entries.map((entry) {
      final group = entry.value;
      final first = group.first;
      return Marker(
        markerId: MarkerId('spot:${entry.key}'),
        position: LatLng(first.latitude!, first.longitude!),
        icon:
            _activityIcons[entry.key] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: const Offset(0.5, 0.95),
        zIndexInt: group.any((a) => a.id == _selectedId) ? 1 : 0,
        onTap: () => _onPinTap(first, spot: group),
      );
    }).toSet();
  }

  // With [spot], the activities sharing that pin come first in the cards.
  void _onPinTap(Activity activity, {List<Activity>? spot}) {
    final first = [for (final a in spot ?? const <Activity>[]) a.id];
    _swipeOrder = [
      ...first,
      for (final a in _activities)
        if (!first.contains(a.id)) a.id,
    ];

    _pageController?.dispose();
    _pageController = PageController(
      initialPage: _swipeOrder.indexOf(activity.id),
      viewportFraction: 0.9,
    );
    _selectActivity(activity);
  }

  void _clearSelection() {
    setState(() {
      _selectedId = null;
      _swipeOrder = const [];
      _extra = null;
    });
    _scheduleMarkerRefresh();
  }

  Future<void> _selectActivity(Activity activity) async {
    setState(() => _selectedId = activity.id);
    _scheduleMarkerRefresh();

    // One camera move, a second one cancels it on Android.
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
    widget.activityStore.removeListener(_takeFocus);
    _googleMap?.dispose();
    _pageController?.dispose();
    _location.dispose();
    _search.dispose();
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
                  final focus = _pendingFocus;
                  _pendingFocus = null;
                  final current = _location.userLocation;
                  if (focus != null) {
                    _onPinTap(focus);
                  } else if (current != null) {
                    unawaited(
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(current, 14),
                      ),
                    );
                  }
                  _scheduleMarkerRefresh();
                },
                onTap: (_) => _clearSelection(),
                markers: _markers(activities),
                myLocationEnabled: _location.userLocation != null,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                padding: EdgeInsets.only(
                  top: topInset + 145,
                  bottom: selected == null ? bottomInset + 8 : 265,
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
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          4,
                          6,
                          4,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: SynkColors.orangeDark,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: _searchField()),
                            FilterButton(
                              count: _filters.changedSectionCount,
                              onTap: _openFilters,
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
                          _categoryChip(context.l10n.all, null),
                          for (final category in _categories)
                            _categoryChip(valueLabel(category), category),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: selected == null ? bottomInset + 16 : 265,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _zoomControls(),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.white,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: context.l10n.myLocation,
                        onPressed: _location.isLocating ? null : _centerOnUser,
                        icon: _location.isLocating
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: SynkColors.textPrimary,
                              ),
                      ),
                    ),
                  ],
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
                  left: 0,
                  right: 0,
                  bottom: 141,
                  child: _previewCarousel(activities),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryChip(String label, String? category) {
    final categories = _filters.categories;
    final selected = category == null
        ? categories.isEmpty
        : categories.contains(category);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
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

  void _onSearchChanged() {
    setState(() {});
    _clearSelection();
  }

  Widget _searchField() {
    final search = _search;
    return TextField(
      controller: search,
      onChanged: (_) => _onSearchChanged(),
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: SynkColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: context.l10n.searchActivitiesOrPlaces,
        hintStyle: const TextStyle(
          fontSize: 15,
          color: SynkColors.textSecondary,
        ),
        border: InputBorder.none,
        isDense: true,
        suffixIcon: search.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.clearSearch,
                onPressed: () {
                  _search.clear();
                  _onSearchChanged();
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: SynkColors.textSecondary,
                ),
              ),
      ),
    );
  }

  Widget _zoomControls() {
    Widget button(IconData icon, String tooltip, CameraUpdate update) {
      return IconButton(
        tooltip: tooltip,
        onPressed: () => _googleMap?.animateCamera(update),
        icon: Icon(icon, color: SynkColors.textPrimary),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.add_rounded, context.l10n.zoomIn, CameraUpdate.zoomIn()),
          Container(
            width: 24,
            height: 1,
            color: SynkColors.textSecondary.withValues(alpha: 0.2),
          ),
          button(
            Icons.remove_rounded,
            context.l10n.zoomOut,
            CameraUpdate.zoomOut(),
          ),
        ],
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

  Widget _previewCarousel(List<Activity> visible) {
    final byId = {for (final a in visible) a.id: a};
    final pages = [
      for (final id in _swipeOrder)
        if (byId[id] != null) byId[id]!,
    ];

    return SizedBox(
      height: 112,
      child: PageView.builder(
        key: ObjectKey(_pageController),
        controller: _pageController,
        itemCount: pages.length,
        onPageChanged: (index) => _selectActivity(pages[index]),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 8),
          child: _activityPreview(pages[index]),
        ),
      ),
    );
  }

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
                      activity.spotsOpen > 0
                          ? context.l10n.spotsLeft(activity.spotsOpen)
                          : context.l10n.full,
                      style: const TextStyle(
                        color: SynkColors.orangeDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: SynkColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
