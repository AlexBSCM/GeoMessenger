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
  bool _selectMode = false;
  final List<Contact> _selected = [];

  void _toggleSelect(Contact contact) {
    setState(() {
      if (!_selected.remove(contact)) {
        _selected.add(contact);
      }
      if (_selected.isEmpty) _selectMode = false;
    });
  }

  void _openGroupCreate() {
    final recipients = _selected
        .map((c) => AppUser(
              id: c.contactId,
              name: c.displayName,
              phone: c.contactPhone,
            ))
        .toList();
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    Navigator.pushNamed(context, '/create', arguments: recipients);
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
  }

  Future<void> _editNickname(Contact contact) async {
    final controller = TextEditingController(text: contact.nickname ?? '');
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Имя контакта'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Имя'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
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
        title: Text('Удалить ${contact.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
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
        title: Text(_selectMode ? 'Выбрано: ${_selected.length}' : 'Контакты'),
        actions: [
          if (!_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Выбрать несколько',
              onPressed: () => setState(() => _selectMode = true),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt),
              tooltip: 'Добавить контакт',
              onPressed: () => Navigator.pushNamed(context, '/add-contact'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Contact>>(
        stream: _db.getContacts(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
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
                  const Text('Пока нет контактов'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/add-contact'),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Добавить контакт'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final selected = _selected.contains(contact);
              return ListTile(
                leading: _selectMode
                    ? Checkbox(
                        value: selected,
                        onChanged: (_) => _toggleSelect(contact),
                      )
                    : CircleAvatar(
                        child: Text(contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?'),
                      ),
                title: Text(contact.displayName),
                subtitle: Text(contact.contactPhone),
                onTap: () {
                  if (_selectMode) {
                    _toggleSelect(contact);
                  } else {
                    _openCreateMessage(contact);
                  }
                },
                trailing: _selectMode
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'nickname') _editNickname(contact);
                          if (value == 'remove') _removeContact(contact);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'nickname', child: Text('Изменить имя')),
                          PopupMenuItem(value: 'remove', child: Text('Удалить')),
                        ],
                      ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _selectMode && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _openGroupCreate,
                  icon: const Icon(Icons.send),
                  label: Text('Написать (${_selected.length})'),
                ),
              ),
            )
          : null,
    );
  }
}