import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
  final _db = DatabaseService();

  Future<void> _editMessage(GeoMessage message) {
    return Navigator.pushNamed(context, '/create', arguments: message);
  }

  Future<void> _deleteMessage(GeoMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: Text('"${message.text}" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteMessage(message.id);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Sent')),
      body: StreamBuilder<List<GeoMessage>>(
        stream: _db.getSentMessages(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snapshot.data!;
          if (messages.isEmpty) {
            return const Center(child: Text('No sent messages yet'));
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final canEdit = msg.status == 'pending';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      msg.recipientName.isNotEmpty
                          ? msg.recipientName[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text('To: ${msg.recipientName.isEmpty ? 'Unknown' : msg.recipientName}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.text),
                      const SizedBox(height: 2),
                      Text(
                        'Radius: ${msg.radiusMeters.toInt()}m · ${msg.status.toUpperCase()}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editMessage(msg);
                      if (value == 'delete') _deleteMessage(msg);
                    },
                    itemBuilder: (context) => [
                      if (canEdit)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
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