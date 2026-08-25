import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/message_store.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Входящие'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      // Reads from the local store so revealed messages show up immediately,
      // including when there is no internet connection.
      body: ListenableBuilder(
        listenable: MessageStore.instance,
        builder: (context, _) {
          final messages = MessageStore.instance.visibleMessages;
          if (messages.isEmpty) {
            return const Center(child: Text('Пока нет сообщений'));
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(msg.senderName),
                  subtitle: Text(msg.text),
                  trailing: const Text(
                    'Доставлено',
                    style: TextStyle(color: Colors.green, fontSize: 12),
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
