import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _db = DatabaseService();
  final _locationService = LocationService.instance;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _startGeofenceMonitoring();
  }

  Future<void> _startGeofenceMonitoring() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) return;

    _locationService
        .startGeofenceMonitoring(() => _db.getActiveGeofences(userId))
        .listen((message) async {
      await _db.markDelivered(message.id);
      await _notificationService.showGeoMessageNotification(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: StreamBuilder(
        stream: _db.getIncomingMessages(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snapshot.data as List<GeoMessage>;
          if (messages.isEmpty) {
            return const Center(child: Text('No messages yet'));
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isDelivered = msg.status == 'delivered';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    isDelivered ? Icons.check_circle : Icons.access_time,
                    color: isDelivered ? Colors.green : Colors.orange,
                  ),
                  title: Text(msg.senderName),
                  subtitle: Text(msg.text),
                  trailing: Text(
                    isDelivered ? 'Delivered' : 'Pending',
                    style: TextStyle(
                      color: isDelivered ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
