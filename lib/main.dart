import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'models/message_model.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/geofence_monitor.dart';
import 'services/location_service.dart';
import 'services/message_store.dart';
import 'services/background_service.dart';
import 'screens/login_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/add_contact_screen.dart';
import 'screens/create_message_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/sent_screen.dart';
import 'screens/map_screen.dart';
import 'widgets/offline_banner.dart';

const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');
const _activeUserKey = 'activeUserId';
const _persistenceClearedKey = 'persistenceClearedV2';

Timer? _heartbeatTimer;

void _sendHeartbeat() {
  FlutterBackgroundService().invoke('heartbeat');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  // One-time purge of the Firestore SDK local write queue. Older app versions
  // could leave a doomed write (e.g. to a document the sender deleted) in the
  // queue; the SDK then replays it on every reconnect, producing an endless
  // PERMISSION_DENIED loop that also starves all other writes.
  final bootPrefs = await SharedPreferences.getInstance();
  if (!(bootPrefs.getBool(_persistenceClearedKey) ?? false)) {
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {
      // Not supported / already in use — nothing to purge.
    }
    await bootPrefs.setBool(_persistenceClearedKey, true);
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Connect to local emulators (disable with --dart-define=USE_EMULATOR=false)
  if (useEmulator) {
    // automaticHostMapping=false: keep the exact host. On a real device the
    // Firebase emulators are reached via `adb reverse` through localhost.
    await FirebaseAuth.instance.useAuthEmulator(
      emulatorHost,
      9099,
      automaticHostMapping: false,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      emulatorHost,
      8080,
      automaticHostMapping: false,
    );
  }

  await NotificationService().init();

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      NotificationService().saveToken();
      // Local cache backs the geofence monitor: pending messages downloaded
      // while online are revealed as soon as the recipient enters the point,
      // even without internet. Deliveries are synced to Firestore when online.
      MessageStore.instance.init(user.uid);
      // Foreground service keeps the process (and the geofence loop) alive
      // when the app is backgrounded or the screen is locked, and takes over
      // monitoring entirely if the app isolate dies (swipe away / reboot).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeUserKey, user.uid);
      await BackgroundService.instance.ensureStarted();
      _heartbeatTimer?.cancel();
      _sendHeartbeat();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
      LocationService.instance.stop();
      LocationService.instance
          .startGeofenceMonitoring(() async => MessageStore.instance.pendingMessages)
          .listen(GeofenceMonitor.reveal);
    } else {
      _heartbeatTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeUserKey);
      LocationService.instance.stop();
      MessageStore.instance.clear();
      BackgroundService.instance.stop();
    }
  });

  runApp(const GeoMessengerApp());
}

class GeoMessengerApp extends StatelessWidget {
  const GeoMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        if (settings.name == '/create') {
          final arg = settings.arguments;
          if (arg is GeoMessage) {
            return MaterialPageRoute(
              builder: (_) => CreateMessageScreen(editMessage: arg),
            );
          }
          final recipients = arg is AppUser ? [arg] : arg as List<AppUser>;
          return MaterialPageRoute(
            builder: (_) => CreateMessageScreen(recipients: recipients),
          );
        }
        if (settings.name == '/add-contact') {
          return MaterialPageRoute(
            builder: (_) => const AddContactScreen(),
          );
        }
        return null;
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MainShell();
        }
        return const LoginScreen();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    ContactsScreen(),
    InboxScreen(),
    SentScreen(),
    MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Offline banner: deliveries keep working via the local cache and
          // sync to Firestore once a connection is back.
          const OfflineBanner(
            text: 'Нет сети — сообщения раскроются офлайн, отправка после подключения',
          ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Контакты'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Входящие'),
          NavigationDestination(icon: Icon(Icons.outbox), label: 'Отправл.'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Карта'),
        ],
      ),
    );
  }
}
