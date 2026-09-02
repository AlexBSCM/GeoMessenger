import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/message_model.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static StreamController<GeoMessage>? _controller;
  static bool _monitoring = false;
  static bool _stopped = false;
  static bool _requestIfDenied = true;

  static const _streamInterval = Duration(seconds: 2);
  static const _fixTimeout = Duration(seconds: 8);
  static const _retryDelay = Duration(seconds: 5);

  Future<bool> requestPermission({bool request = true}) async {
    // Note: Geolocator.isLocationServiceEnabled() is intentionally not used:
    // it hardcodes the GMS/FusedLocation path on Android and crashes on devices
    // with incompatible Google Play Services (e.g. some Huawei tablets).
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<Position> getCurrentPosition() async {
    return await _getPosition();
  }

  // Prefer the fused provider (Google Play Services) for fast, accurate fixes on
  // devices that support it. Devices without compatible Play Services (e.g. some
  // Huawei tablets) fall back to the Android LocationManager instead of crashing.
  static Future<Position> _getPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: false,
        ),
      ).timeout(_fixTimeout);
    } catch (_) {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
        ),
      ).timeout(_fixTimeout);
    }
  }

  Stream<GeoMessage> startGeofenceMonitoring(
    Future<List<GeoMessage>> Function() fetcher, {
    // The service isolate must not raise permission dialogs from the
    // background — it only monitors while permission is already granted.
    bool requestPermissionIfDenied = true,
  }) {
    if (_monitoring) {
      return _controller!.stream;
    }
    _monitoring = true;
    _stopped = false;
    _requestIfDenied = requestPermissionIfDenied;
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

  // Continuous position stream: reacts to movement immediately instead of
  // polling for fixes, so entering a zone fires as soon as the phone crosses it.
  // Prefer the fused provider (Google Play Services); devices without it (e.g.
  // some Huawei tablets) fall back to the Android LocationManager stream.
  Future<void> _runLoop(Future<List<GeoMessage>> Function() fetcher) async {
    while (!_stopped) {
      final hasPermission = await requestPermission(request: _requestIfDenied);
      if (!hasPermission) {
        await Future.delayed(_retryDelay);
        continue;
      }
      if (_stopped) return;

      try {
        await _monitorStream(fetcher);
      } catch (_) {
        // Stream failed (provider unavailable, GPS off) — restart in a moment.
      }
      if (_stopped) return;
      await Future.delayed(_retryDelay);
    }
  }

  Future<void> _monitorStream(Future<List<GeoMessage>> Function() fetcher) async {
    try {
      await _listenStream(forceLocationManager: false, fetcher: fetcher);
    } catch (_) {
      if (_stopped) return;
      // Fused provider unavailable — fall back to LocationManager.
      await _listenStream(forceLocationManager: true, fetcher: fetcher);
    }
  }

  Future<void> _listenStream({
    required bool forceLocationManager,
    required Future<List<GeoMessage>> Function() fetcher,
  }) async {
    // Watchdog: if no position arrives within the window (provider stalled,
    // background throttling), throw so the outer loop restarts the stream.
    final stream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: forceLocationManager,
        intervalDuration: _streamInterval,
      ),
    ).timeout(
      const Duration(seconds: 60),
      onTimeout: (sink) =>
          sink.addError(TimeoutException('position stream stalled')),
    );

    // Emit each pending message at most once per stream session: the monitor
    // is inside its zone, so firing on every 2 s position update would reveal,
    // notify and write to Firestore the same message over and over. Re-emitting
    // is only allowed after the stream is restarted (e.g. it stalled).
    final emitted = <String>{};

    await for (final position in stream) {
      if (_stopped) break;

      try {
        final messages = await fetcher();
        for (final message in messages) {
          if (message.status != 'pending') continue;

          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            message.latitude,
            message.longitude,
          );

          if (distance <= message.radiusMeters && emitted.add(message.id)) {
            _controller!.add(message);
          }
        }
      } catch (_) {
        // Transient errors (e.g. GPS temporarily unavailable) — keep listening.
      }
    }
  }

  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}