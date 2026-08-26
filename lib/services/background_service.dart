import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'geofence_monitor.dart';
import 'location_service.dart';
import 'message_store.dart';
import 'notification_service.dart';

const bgNotificationChannelId = 'geo_bg_service';
const bgNotificationId = 888;
const _activeUserKey = 'activeUserId';

/// Keeps the app process alive in the background and takes over geofence
/// monitoring whenever the app's own isolate is dead (app swiped away or
/// device rebooted).
///
/// Handover protocol: the app isolate sends a 'heartbeat' every 30 s while it
/// is alive (it monitors by itself). If no heartbeat arrives within 45 s, the
/// service starts its own monitoring loop; when heartbeats resume, it stands
/// down. This guarantees exactly one active monitor with no double
/// notifications in the steady state.
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
            'Гео Мессенджер',
            description: 'Мониторинг геозон в фоне',
            importance: Importance.low,
          ),
        );

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: bgNotificationChannelId,
        initialNotificationTitle: 'Гео Мессенджер',
        initialNotificationContent: 'Мониторинг геозон активен',
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

    // MIUI/HyperOS and stock Android kill background apps unless the battery
    // optimization exemption is granted. Shows a one-time system dialog.
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

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
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  await NotificationService().initLocalOnly();

  // Keep the service process alive.
  Timer.periodic(const Duration(seconds: 30), (timer) {});

  var lastHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);
  var monitoring = false;

  service.on('heartbeat').listen((_) {
    lastHeartbeat = DateTime.now();
  });
  service.on('stop').listen((_) => service.stopSelf());

  Future<void> standDown() async {
    if (!monitoring) return;
    monitoring = false;
    LocationService.instance.stop();
    await MessageStore.instance.clear();
  }

  Future<void> takeOver() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_activeUserKey);
    if (userId == null) return;
    monitoring = true;
    await MessageStore.instance.init(userId);
    LocationService.instance
        .startGeofenceMonitoring(
          () async => MessageStore.instance.pendingMessages,
          requestPermissionIfDenied: false,
        )
        .listen((message) => GeofenceMonitor.reveal(message));
  }

  Timer.periodic(const Duration(seconds: 15), (_) async {
    try {
      final mainAlive =
          DateTime.now().difference(lastHeartbeat).inSeconds < 45;
      if (mainAlive) {
        await standDown();
        return;
      }
      if (monitoring) return;
      await takeOver();
    } catch (_) {
      // Never let the watchdog timer die.
    }
  });
}
