class GeoMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String text;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime createdAt;
  final String status;

  GeoMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.text,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100,
    DateTime? createdAt,
    this.status = 'pending',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'recipientId': recipientId,
        'text': text,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
      };

  factory GeoMessage.fromMap(Map<String, dynamic> map) => GeoMessage(
        id: map['id'] as String,
        senderId: map['senderId'] as String,
        senderName: map['senderName'] as String,
        recipientId: map['recipientId'] as String,
        text: map['text'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 100,
        createdAt: DateTime.parse(map['createdAt'] as String),
        status: map['status'] as String? ?? 'pending',
      );
}
