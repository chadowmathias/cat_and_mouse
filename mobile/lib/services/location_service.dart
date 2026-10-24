import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSub;
  bool _isServiceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;

  Position? get currentPosition => _currentPosition;
  bool get isReady => _currentPosition != null;
  bool get isMocked => _currentPosition?.isMocked ?? false;

  Future<bool> initLocationService() async {
    _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_isServiceEnabled) {
      debugPrint('[GPS] Localisation désactivée.');
      return false;
    }

    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
      if (_permission == LocationPermission.denied) {
        debugPrint('[GPS] Permissions refusées.');
        return false;
      }
    }

    if (_permission == LocationPermission.deniedForever) {
      debugPrint('[GPS] Permissions refusées de manière permanente.');
      return false;
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    notifyListeners();

    _startTracking();
    return true;
  }

  void _startTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      _currentPosition = pos;
      notifyListeners();
    });
  }

  bool isInsideZone(LatLng center, double radiusMeters) {
    if (_currentPosition == null) return true;

    const distance = Distance();
    final playerCoord = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final dist = distance.as(LengthUnit.Meter, playerCoord, center);

    return dist <= radiusMeters;
  }

  double distanceToZoneBoundary(LatLng center, double radiusMeters) {
    if (_currentPosition == null) return 0.0;

    const distance = Distance();
    final playerCoord = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final dist = distance.as(LengthUnit.Meter, playerCoord, center);

    return radiusMeters - dist;
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }
}
