import 'package:geolocator/geolocator.dart';
import '../models/message_model.dart';

class LocationService {
  Future<bool> requestPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Stream<GeoMessage> startGeofenceMonitoring(List<GeoMessage> messages) async* {
    while (true) {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      for (final message in messages) {
        if (message.status != 'pending') continue;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          message.latitude,
          message.longitude,
        );

        if (distance <= message.radiusMeters) {
          yield message;
        }
      }

      await Future.delayed(const Duration(seconds: 30));
    }
  }

  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
