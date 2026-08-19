import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class CreateMessageScreen extends StatefulWidget {
  final AppUser recipient;
  const CreateMessageScreen({super.key, required this.recipient});

  @override
  State<CreateMessageScreen> createState() => _CreateMessageScreenState();
}

class _CreateMessageScreenState extends State<CreateMessageScreen> {
  final _textController = TextEditingController();
  final _locationService = LocationService();
  final _db = DatabaseService();
  Position? _currentPosition;
  bool _isLoading = false;
  String _senderName = '';

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadSender();
  }

  Future<void> _loadSender() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final appUser = await _db.getUser(user.uid);
    setState(() => _senderName = appUser?.name ?? user.email ?? 'Unknown');
  }

  Future<void> _getLocation() async {
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) return;

    final position = await _locationService.getCurrentPosition();
    setState(() => _currentPosition = position);
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _currentPosition == null) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;

    await _db.createMessage(
      senderId: user.uid,
      senderName: _senderName,
      recipientId: widget.recipient.id,
      text: _textController.text.trim(),
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Message to ${widget.recipient.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Your message',
                hintText: 'Type something...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(
                  _currentPosition == null
                      ? 'Getting location...'
                      : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                ),
                subtitle: const Text('Radius: 100m (fixed)'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_isLoading ? 'Sending...' : 'Pin at current location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
