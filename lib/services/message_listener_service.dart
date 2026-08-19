import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

// Listens for newly arrived messages and fires a local notification.
// Works while the app is running (foreground or backgrounded).
class MessageListenerService {
  MessageListenerService._();
  static final MessageListenerService instance = MessageListenerService._();

  StreamSubscription<List<GeoMessage>>? _sub;
  final Set<String> _seenIds = {};
  bool _initialized = false;

  void start() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _sub != null) return;

    _seenIds.clear();
    _initialized = false;

    _sub = DatabaseService().getIncomingMessages(user.uid).listen((messages) {
      for (final message in messages) {
        if (message.status != 'pending') continue;
        final isNew = _seenIds.add(message.id);
        if (isNew && _initialized) {
          NotificationService().showIncomingMessageNotification(message);
        }
      }
      _initialized = true;
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}