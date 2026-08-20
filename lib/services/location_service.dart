import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/message_model.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static StreamController<GeoMessage>? _controller;
  static bool _monitoring = false;
  static bool _stopped = false;

  Future<bool> requestPermission() async {
    // Note: Geolocator.isLocationServiceEnabled() is intentionally not used:
    // it hardcodes the GMS/FusedLocation path on Android and crashes on devices
    // with incompatible Google Play Services (e.g. some Huawei tablets).
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: true,
      ),
    );
  }

  Stream<GeoMessage> startGeofenceMonitoring(Future<List<GeoMessage>> Function() fetcher) {
    if (_monitoring) {
      return _controller!.stream;
    }
    _monitoring = true;
    _stopped = false;
    _controller = StreamController<GeoMessage>.broadcast();
    _runLoop(fetcher);
    return _controller!.stream;
  }

  void stop() {
    _stopped = true;
    _monitoring = false;
    _controller?.close();
    _controller = null;
  }

  Future<void> _runLoop(Future<List<GeoMessage>> Function() fetcher) async {
    while (!_stopped) {
      try {
        final hasPermission = await requestPermission();
        if (!hasPermission) {
          await Future.delayed(const Duration(seconds: 30));
          continue;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
          ),
        );

        final messages = await fetcher();
        for (final message in messages) {
          if (message.status != 'pending') continue;

          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            message.latitude,
            message.longitude,
          );

          if (distance <= message.radiusMeters) {
            _controller!.add(message);
          }
        }
      } catch (_) {
        // Transient errors (e.g. GPS temporarily unavailable) — retry next cycle
      }

      await Future.delayed(const Duration(seconds: 30));
    }
  }

  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}