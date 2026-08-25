import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/map_state_service.dart';
import '../services/message_store.dart';

/// Map with the recipient's pending geo-zones: helps to see where the hidden
/// messages are waiting and how far they are.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  LatLng? _center;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _initCenter();
  }

  Future<void> _initCenter() async {
    final saved = await MapStateService.loadCenter();
    if (saved != null) {
      if (!mounted) return;
      setState(() => _center = saved);
      _mapController.move(saved, 17);
      return;
    }
    await _locateMe();
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final hasPermission = await LocationService.instance.requestPermission();
      if (!hasPermission || !mounted) return;
      final position = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _center = point);
      MapStateService.saveCenter(point);
      _mapController.move(point, 17);
    } catch (_) {
      // Location unavailable — keep the current map center.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Карта зон')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center ?? const LatLng(55.7558, 37.6173),
          initialZoom: 17,
          minZoom: 3,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onPositionChanged: (camera, hasGesture) {
            if (hasGesture) MapStateService.saveCenter(camera.center);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.geomessenger.geo_messenger',
          ),
          ListenableBuilder(
            listenable: MessageStore.instance,
            builder: (context, _) {
              final pending = MessageStore.instance.pendingMessages;
              return CircleLayer(
                circles: [
                  for (final m in pending)
                    CircleMarker(
                      point: LatLng(m.latitude, m.longitude),
                      radius: m.radiusMeters,
                      useRadiusInMeter: true,
                      color: Colors.deepPurple.withValues(alpha: 0.2),
                      borderColor: Colors.deepPurple,
                      borderStrokeWidth: 2,
                    ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locateMe,
        tooltip: 'Моё местоположение',
        child: _locating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}
