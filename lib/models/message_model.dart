import 'package:cloud_firestore/cloud_firestore.dart';

class GeoMessage {
  final String id;
  final String senderId;
  final String senderName;
  final List<String> recipientIds;
  final String recipientName;
  final String text;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String status;

  GeoMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientIds,
    this.recipientName = '',
    required this.text,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 10,
    DateTime? createdAt,
    this.deliveredAt,
    this.status = 'pending',
  }) : createdAt = createdAt ?? DateTime.now();

GeoMessage copyWith({
    String? status,
    DateTime? createdAt,
    DateTime? deliveredAt,
    double? radiusMeters,
  }) =>
      GeoMessage(
        id: id,
        senderId: senderId,
        senderName: senderName,
        recipientIds: recipientIds,
        recipientName: recipientName,
        text: text,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        createdAt: createdAt ?? this.createdAt,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'recipientIds': recipientIds,
        'recipientName': recipientName,
        'text': text,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'createdAt': createdAt.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
        'status': status,
      };

  factory GeoMessage.fromMap(Map<String, dynamic> map) {
    // Old documents store a single recipientId string; new ones a list.
    final ids = (map['recipientIds'] as List?)?.cast<String>() ??
        [map['recipientId'] as String];
    return GeoMessage(
        id: map['id'] as String,
        senderId: map['senderId'] as String,
        senderName: map['senderName'] as String? ?? '',
        recipientIds: ids,
        recipientName: map['recipientName'] as String? ?? '',
        text: map['text'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 10,
        createdAt: _parseDate(map['createdAt']),
        deliveredAt: map['deliveredAt'] == null ? null : _parseDate(map['deliveredAt']),
        status: map['status'] as String? ?? 'pending',
      );
  }

  /// Accepts Firestore Timestamps, ISO strings and null (pending server
  /// timestamps) so one inconsistent document cannot crash a whole stream.
  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
