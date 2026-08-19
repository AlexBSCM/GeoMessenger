import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final _locationService = LocationService.instance;
  final _db = DatabaseService();
  final _mapController = MapController();

  LatLng? _selectedPoint;
  bool _isLoading = false;
  String _senderName = '';
  static const double _radiusMeters = 10;

  @override
  void initState() {
    super.initState();
    _loadSender();
    _getInitialPosition();
  }

  Future<void> _loadSender() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final appUser = await _db.getUser(user.uid);
    setState(() => _senderName = appUser?.name ?? user.email ?? 'Unknown');
  }

  Future<void> _getInitialPosition() async {
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) return;
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _selectedPoint = LatLng(position.latitude, position.longitude));
    _mapController.move(_selectedPoint!, 17);
  }

  Future<void> _locateMe() async {
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) return;
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    setState(() => _selectedPoint = point);
    _mapController.move(point, 17);
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _selectedPoint == null) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;

    await _db.createMessage(
      senderId: user.uid,
      senderName: _senderName,
      recipientId: widget.recipient.id,
      text: text,
      latitude: _selectedPoint!.latitude,
      longitude: _selectedPoint!.longitude,
      radiusMeters: _radiusMeters,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Message to ${widget.recipient.name}')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint ?? const LatLng(55.7558, 37.6173),
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 19,
                onTap: (tapPosition, point) => setState(() => _selectedPoint = point),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.geomessenger.geo_messenger',
                ),
                if (_selectedPoint != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _selectedPoint!,
                        radius: _radiusMeters,
                        useRadiusInMeter: true,
                        color: Colors.deepPurple.withValues(alpha: 0.2),
                        borderColor: Colors.deepPurple,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint!,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_pin, color: Colors.deepPurple, size: 44),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Your message',
                    hintText: 'Type something...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _selectedPoint == null
                          ? Icons.location_off
                          : Icons.location_on,
                      size: 18,
                      color: _selectedPoint == null ? Colors.grey : Colors.deepPurple,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedPoint == null
                            ? 'Tap the map to pin a point'
                            : 'Lat: ${_selectedPoint!.latitude.toStringAsFixed(5)}, '
                                'Lng: ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Radius: 10m — triggers when the recipient is close to the point',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _selectedPoint == null) ? null : _sendMessage,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? 'Sending...' : 'Send'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locateMe,
        tooltip: 'Use current location',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}