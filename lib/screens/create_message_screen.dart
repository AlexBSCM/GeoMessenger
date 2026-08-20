import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class CreateMessageScreen extends StatefulWidget {
  final AppUser? recipient;
  final GeoMessage? editMessage;

  const CreateMessageScreen({super.key, this.recipient, this.editMessage})
      : assert(recipient != null || editMessage != null,
            'Either recipient or editMessage must be provided');

  bool get isEditing => editMessage != null;

  @override
  State<CreateMessageScreen> createState() => _CreateMessageScreenState();
}

class _CreateMessageScreenState extends State<CreateMessageScreen> {
  static const List<double> _radiusOptions = [5, 10, 25, 50, 100];

  late final TextEditingController _textController;
  final _locationService = LocationService.instance;
  final _db = DatabaseService();
  final _mapController = MapController();

  LatLng? _selectedPoint;
  late double _radiusMeters;
  bool _isLoading = false;
  String _senderName = '';

  @override
  void initState() {
    super.initState();
    final edit = widget.editMessage;
    _textController = TextEditingController(text: edit?.text ?? '');
    _radiusMeters = edit?.radiusMeters ?? 10;
    if (edit != null) {
      _selectedPoint = LatLng(edit.latitude, edit.longitude);
    }
    _loadSender();
    if (edit == null) {
      _getInitialPosition();
    }
  }

  Future<void> _loadSender() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final appUser = await _db.getUser(user.uid);
    setState(() {
      _senderName = (appUser?.name.isNotEmpty == true)
          ? appUser!.name
          : (user.email?.split('@').first ?? 'Unknown');
    });
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

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _selectedPoint == null) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;

    try {
      final edit = widget.editMessage;
      if (edit != null) {
        await _db.updateMessage(
          edit.id,
          text: text,
          latitude: _selectedPoint!.latitude,
          longitude: _selectedPoint!.longitude,
          radiusMeters: _radiusMeters,
        );
      } else {
        await _db.createMessage(
          senderId: user.uid,
          senderName: _senderName,
          recipientId: widget.recipient!.id,
          recipientName: widget.recipient!.name,
          text: text,
          latitude: _selectedPoint!.latitude,
          longitude: _selectedPoint!.longitude,
          radiusMeters: _radiusMeters,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

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
    final edit = widget.editMessage;
    final title = edit != null
        ? 'Edit message to ${edit.recipientName.isEmpty ? 'recipient' : edit.recipientName}'
        : 'Message to ${widget.recipient!.name}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in _radiusOptions)
                      ChoiceChip(
                        label: Text('${r.toInt()}m'),
                        selected: _radiusMeters == r,
                        onSelected: (_) => setState(() => _radiusMeters = r),
                      ),
                  ],
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
                Text(
                  'Radius: ${_radiusMeters.toInt()}m — triggers when the recipient is close to the point',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _selectedPoint == null) ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(edit != null ? Icons.save : Icons.send),
                    label: Text(_isLoading
                        ? (edit != null ? 'Saving...' : 'Sending...')
                        : (edit != null ? 'Save changes' : 'Send')),
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