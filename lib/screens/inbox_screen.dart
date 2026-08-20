import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _db.getIncomingMessages(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Only messages that reached the recipient (geofence triggered) are
          // shown; pending ones stay hidden until the recipient enters the zone.
          final messages = (snapshot.data as List<GeoMessage>)
              .where((m) => m.status == 'delivered')
              .toList();
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
