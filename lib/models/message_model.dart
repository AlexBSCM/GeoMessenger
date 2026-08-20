class GeoMessage {
  final String id;
final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
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
    this.recipientName = '',
    required this.text,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 10,
    DateTime? createdAt,
    this.status = 'pending',
  }) : createdAt = createdAt ?? DateTime.now();

  GeoMessage copyWith({
    String? status,
    DateTime? createdAt,
    double? radiusMeters,
  }) =>
      GeoMessage(
        id: id,
        senderId: senderId,
        senderName: senderName,
        recipientId: recipientId,
        recipientName: recipientName,
        text: text,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'recipientId': recipientId,
        'recipientName': recipientName,
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
        recipientName: map['recipientName'] as String? ?? '',
        text: map['text'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 10,
        createdAt: DateTime.parse(map['createdAt'] as String),
        status: map['status'] as String? ?? 'pending',
      );
}
