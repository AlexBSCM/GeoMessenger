import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _db = DatabaseService();

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
  }

  Future<void> _editNickname(Contact contact) async {
    final controller = TextEditingController(text: contact.nickname ?? '');
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact nickname'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nickname'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (nickname == null) return;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _db.setContactNickname(userId, contact.contactId, nickname);
  }

  Future<void> _removeContact(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${contact.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _db.removeContact(userId, contact.contactId);
  }

  void _openCreateMessage(Contact contact) {
    final recipient = AppUser(
      id: contact.contactId,
      name: contact.contactName,
      phone: contact.contactPhone,
    );
    Navigator.pushNamed(context, '/create', arguments: recipient);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Add contact',
            onPressed: () => Navigator.pushNamed(context, '/add-contact'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Contact>>(
        stream: _db.getContacts(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final contacts = snapshot.data!
            ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No contacts yet'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/add-contact'),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Add contact'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?'),
                ),
                title: Text(contact.displayName),
                subtitle: Text(contact.contactPhone),
                onTap: () => _openCreateMessage(contact),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'nickname') _editNickname(contact);
                    if (value == 'remove') _removeContact(contact);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'nickname', child: Text('Edit nickname')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}