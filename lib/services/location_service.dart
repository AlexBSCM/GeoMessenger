import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/message_model.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static StreamController<GeoMessage>? _controller;
  static bool _monitoring = false;

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

  Stream<GeoMessage> startGeofenceMonitoring(Future<List<GeoMessage>> Function() fetcher) {
    if (_monitoring) {
      return _controller!.stream;
    }
    _monitoring = true;
    _controller = StreamController<GeoMessage>();
    _runLoop(fetcher);
    return _controller!.stream;
  }

  Future<void> _runLoop(Future<List<GeoMessage>> Function() fetcher) async {
    while (true) {
      try {
        final hasPermission = await requestPermission();
        if (!hasPermission) {
          await Future.delayed(const Duration(seconds: 30));
          continue;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
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