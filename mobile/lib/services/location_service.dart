import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../api/location_api.dart';

class LocationService {
  final LocationApi _api = LocationApi();
  StreamSubscription<Position>? _subscription;
  Timer? _uploadTimer;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void startTracking({int intervalSeconds = 5, Function(Position)? onLocation}) {
    _subscription?.cancel();
    _uploadTimer?.cancel();

    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen((position) {
      onLocation?.call(position);
    });

    _uploadTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await _api.uploadLocation(
          longitude: pos.longitude, latitude: pos.latitude,
          altitude: pos.altitude, speed: pos.speed,
          bearing: pos.heading, accuracy: pos.accuracy,
          source: 'gps',
        );
      } catch (e) {
        print('Upload location error: \');
      }
    });
  }

  void stopTracking() {
    _subscription?.cancel();
    _uploadTimer?.cancel();
    _subscription = null;
    _uploadTimer = null;
  }
}
