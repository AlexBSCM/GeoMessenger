import 'package:firebase_core/firebase_core.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'local-emulator',
  appId: 'local-emulator',
  messagingSenderId: 'local-emulator',
  projectId: 'geo-messenger-local',
  authDomain: 'localhost',
  databaseURL: 'http://localhost:8080',
  storageBucket: 'localhost',
);
