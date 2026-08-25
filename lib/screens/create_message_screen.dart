import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/map_state_service.dart';

class CreateMessageScreen extends StatefulWidget {
  final List<AppUser> recipients;
  final GeoMessage? editMessage;

  CreateMessageScreen({
    super.key,
    this.recipients = const [],
    this.editMessage,
  })  : assert(recipients.isNotEmpty || editMessage != null,
            'Either recipients or editMessage must be provided');

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
      _restoreOrInitPosition();
    }
  }

  Future<void> _restoreOrInitPosition() async {
    final saved = await MapStateService.loadCenter();
    if (saved != null) {
      if (!mounted) return;
      setState(() => _selectedPoint = saved);
      _mapController.move(saved, 17);
      return;
    }
    await _getInitialPosition();
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
    MapStateService.saveCenter(point);
    _mapController.move(point, 17);
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _selectedPoint == null) return;

    // Fast pre-check: with the radio off the Firestore write would hang
    // forever waiting for a server acknowledgement.
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет сети. Включите интернет и попробуйте ещё раз')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;

    try {
      final edit = widget.editMessage;
      if (edit != null) {
        await _db
            .updateMessage(
              edit.id,
              text: text,
              latitude: _selectedPoint!.latitude,
              longitude: _selectedPoint!.longitude,
              radiusMeters: _radiusMeters,
            )
            .timeout(const Duration(seconds: 15));
      } else {
        await _db
            .createMessage(
              senderId: user.uid,
              senderName: _senderName,
              recipientIds: widget.recipients.map((r) => r.id).toList(),
              recipientName: widget.recipients.map((r) => r.name).join(', '),
              text: text,
              latitude: _selectedPoint!.latitude,
              longitude: _selectedPoint!.longitude,
              radiusMeters: _radiusMeters,
            )
            .timeout(const Duration(seconds: 15));
      }
      MapStateService.saveCenter(_selectedPoint!);
    } on TimeoutException {
      // Firestore keeps the write in its on-disk outbox and sends it when
      // the connection is back, so the screen can be closed safely.
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Слабая сеть. Сообщение отправится автоматически при подключении'),
          ),
        );
      }
      return;
    } catch (e) {
      // Do not close the screen on failure: the message was NOT sent, and the
      // user must know (before this, failures silently looked like "sent").
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось отправить. Проверьте сеть и попробуйте ещё раз'),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _isLoading = false);

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
        ? 'Изменить сообщение для ${edit.recipientName.isEmpty ? 'получателя' : edit.recipientName}'
        : widget.recipients.length == 1
            ? 'Сообщение для ${widget.recipients.first.name}'
            : 'Сообщение для ${widget.recipients.length} получателей';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              final results = snapshot.data;
              final offline = results != null &&
                  !results.any((r) => r != ConnectivityResult.none);
              if (!offline) return const SizedBox.shrink();
              return const Material(
                color: Colors.deepOrange,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Нет сети — отправка невозможна',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint ?? const LatLng(55.7558, 37.6173),
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 19,
                onTap: (tapPosition, point) {
                  setState(() => _selectedPoint = point);
                  MapStateService.saveCenter(point);
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) MapStateService.saveCenter(camera.center);
                },
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
                    labelText: 'Ваше сообщение',
                    hintText: 'Введите текст...',
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
                            ? 'Коснитесь карты, чтобы выбрать точку'
                            : 'Шир: ${_selectedPoint!.latitude.toStringAsFixed(5)}, '
                                'Долг: ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Радиус: ${_radiusMeters.toInt()}м — сработает, когда получатель подойдёт к точке',
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
                        ? (edit != null ? 'Сохранение...' : 'Отправка...')
                        : (edit != null ? 'Сохранить' : 'Отправить')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locateMe,
        tooltip: 'Моё местоположение',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}