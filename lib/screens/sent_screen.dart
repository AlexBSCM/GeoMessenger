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
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  Future<void> _editMessage(GeoMessage message) {
    return Navigator.pushNamed(context, '/create', arguments: message);
  }

  Future<void> _deleteMessage(GeoMessage message) async {
    final confirmed = await _showDeleteConfirm(count: 1, text: message.text);
    if (!confirmed) return;
    await _db.deleteMessage(message.id);
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    final confirmed = await _showDeleteConfirm(count: ids.length);
    if (!confirmed) return;
    for (final id in ids) {
      await _db.deleteMessage(id);
    }
    setState(() => _selectedIds.clear());
  }

  Future<bool> _showDeleteConfirm({required int count, String? text}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete message${count == 1 ? '' : 's'}?'),
            content: Text(count == 1
                ? '"$text" will be permanently deleted.'
                : '$count messages will be permanently deleted.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _toggleSelection(GeoMessage message) {
    setState(() {
      if (!_selectedIds.add(message.id)) {
        _selectedIds.remove(message.id);
      }
    });
  }

  void _toggleSelectAll(List<GeoMessage> messages) {
    setState(() {
      if (_selectedIds.length == messages.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(messages.map((m) => m.id));
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? 'Selected: ${_selectedIds.length}' : 'Sent'),
        actions: [
          if (!_selectMode)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Select messages',
              onPressed: () => setState(() => _selectMode = true),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Select all',
              onPressed: () => _toggleSelectAll(_currentMessages),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete selected',
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: _exitSelectMode,
            ),
          ],
        ],
      ),
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
          _currentMessages = messages;
          if (messages.isEmpty) {
            return const Center(child: Text('No sent messages yet'));
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final canEdit = msg.status == 'pending';
              final selected = _selectedIds.contains(msg.id);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: _selectMode
                      ? Checkbox(
                          value: selected,
                          onChanged: (_) => _toggleSelection(msg),
                        )
                      : CircleAvatar(
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
                  onTap: _selectMode ? () => _toggleSelection(msg) : null,
                  trailing: _selectMode
                      ? null
                      : PopupMenuButton<String>(
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

  List<GeoMessage> _currentMessages = [];
}