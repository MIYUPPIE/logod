import 'package:geolocator/geolocator.dart';

class LocationFix {
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime capturedAt;

  const LocationFix({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.capturedAt,
  });
}

class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  Future<LocationFix> getCurrentFix() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
          'Location services are turned off on this device. Turn on GPS and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException('Location permission was denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
          'Location permission is permanently denied. Enable it in device settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LocationFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      capturedAt: DateTime.now(),
    );
  }
}
