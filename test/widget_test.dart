import 'package:flutter_test/flutter_test.dart';
import 'package:geo_messenger/models/message_model.dart';
import 'package:geo_messenger/services/location_service.dart';

void main() {
  group('GeoMessage', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      final message = GeoMessage(
        id: 'm1',
        senderId: 's1',
        senderName: 'Alice',
        recipientId: 'r1',
        text: 'Meet me here',
        latitude: 55.7558,
        longitude: 37.6173,
        radiusMeters: 150,
        createdAt: DateTime.utc(2026, 1, 1, 12),
        status: 'pending',
      );

      final restored = GeoMessage.fromMap(message.toMap());

      expect(restored.id, message.id);
      expect(restored.senderId, message.senderId);
      expect(restored.senderName, message.senderName);
      expect(restored.recipientId, message.recipientId);
      expect(restored.text, message.text);
      expect(restored.latitude, message.latitude);
      expect(restored.longitude, message.longitude);
      expect(restored.radiusMeters, 150);
      expect(restored.createdAt, message.createdAt);
      expect(restored.status, 'pending');
    });

    test('defaults: radius 5m and pending status', () {
      final message = GeoMessage(
        id: 'm2',
        senderId: 's1',
        senderName: 'Bob',
        recipientId: 'r1',
        text: 'Hello',
        latitude: 1,
        longitude: 2,
      );

      expect(message.radiusMeters, 5);
      expect(message.status, 'pending');
    });
  });

  group('LocationService', () {
    test('calculateDistance returns 0 for identical points', () {
      expect(LocationService.calculateDistance(55.75, 37.6, 55.75, 37.6), 0);
    });

    test('calculateDistance returns roughly 111km for 1 degree latitude', () {
      final distance = LocationService.calculateDistance(55.0, 0.0, 56.0, 0.0);
      expect(distance, closeTo(111194, 500));
    });
  });
}