
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapController extends ChangeNotifier {
  // Default location: Riyadh, Saudi Arabia.
  static const LatLng defaultCenter = LatLng(24.7136, 46.6753);

  LatLng? _userLocation;
  bool _isLocating = false;
  String? _locationMessage;

  // Getters used by map_view.dart.
  LatLng get initialCenter => _userLocation ?? defaultCenter;

  LatLng? get userLocation => _userLocation;

  bool get isLocating => _isLocating;

  String? get locationMessage => _locationMessage;

  // Retrieve the user's current location.
  Future<void> locateUser() async {
    if (_isLocating) return;

    _isLocating = true;
    _locationMessage = null;
    notifyListeners();

    try {
      // Check whether location services are enabled.
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _locationMessage =
            'Please enable location services to find nearby activities.';
        return;
      }

      // Check location permissions.
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _locationMessage =
            'Location permission was denied.';
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _locationMessage =
            'Location permission is permanently denied. '
            'Please enable it in your device settings.';
        return;
      }

      // Retrieve current coordinates.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _userLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      debugPrint(
        'Synk user location: '
        '${position.latitude}, ${position.longitude}',
      );
    } catch (error) {
      _locationMessage =
          'Unable to retrieve your location. Showing Riyadh instead.';

      debugPrint('Synk location error: $error');
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }
}
