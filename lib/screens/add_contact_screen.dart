import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<AppUser> _results = [];
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_query != query.trim()) {
        _query = query.trim();
        _search();
      }
    });
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final contactIds = await _db.getContactIds(userId);
    final users = await _db.searchUsers(_query);
    if (!mounted) return;
    setState(() {
      _results = users.where((u) => u.id != userId && !contactIds.contains(u.id)).toList();
      _loading = false;
    });
  }

  Future<void> _add(AppUser user) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _db.addContact(userId, user);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.name} added to contacts')),
    );
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add contact')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'Search by login or phone',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(user.name.isNotEmpty ? user.name : user.phone),
                            subtitle: Text(user.phone),
                            trailing: const Icon(Icons.person_add),
                            onTap: () => _add(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}