import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/create_message_screen.dart';
import 'screens/inbox_screen.dart';

const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  // Connect to local emulators (disable with --dart-define=USE_EMULATOR=false)
  if (useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }

  await NotificationService().init();

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) NotificationService().saveToken();
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
          final recipient = settings.arguments as AppUser;
          return MaterialPageRoute(
            builder: (_) => CreateMessageScreen(recipient: recipient),
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
        ],
      ),
    );
  }
}
