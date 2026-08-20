import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'location_service.dart';

const bgNotificationChannelId = 'geo_bg_service';
const bgNotificationId = 888;

/// Keeps the app process alive in the background so the geofence monitor (which
/// runs in the main isolate) keeps checking positions and revealing messages,
/// even with the screen off and without internet.
///
/// The service itself does nothing: its only job is to make Android keep the
/// process running (foreground service) and to allow background location access.
class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  bool _configured = false;

  Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            bgNotificationChannelId,
            'Geo Messenger',
            description: 'Monitoring geozones while the app is in the background',
            importance: Importance.low,
          ),
        );

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: bgNotificationChannelId,
        initialNotificationTitle: 'Geo Messenger',
        initialNotificationContent: 'Monitoring geozones is active',
        foregroundServiceNotificationId: bgNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Starts the foreground service once location permission is granted.
  Future<void> ensureStarted() async {
    await configure();
    final granted = await LocationService.instance.requestPermission();
    if (!granted) return;
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  Future<void> stop() async {
    await configure();
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stop');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Keep the service alive; the geofence work itself runs in the main isolate.
  Timer.periodic(const Duration(seconds: 30), (timer) {});

  service.on('stop').listen((event) {
    service.stopSelf();
  });
}