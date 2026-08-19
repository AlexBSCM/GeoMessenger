class Contact {
  final String userId;
  final String contactId;
  final String contactName;
  final String contactPhone;
  final String? nickname;
  final DateTime createdAt;

  Contact({
    required this.userId,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    this.nickname,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayName => (nickname != null && nickname!.isNotEmpty) ? nickname! : contactName;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'contactId': contactId,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'nickname': nickname ?? '',
        'createdAt': createdAt.toIso8601String(),
      };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
        userId: map['userId'] as String,
        contactId: map['contactId'] as String,
        contactName: map['contactName'] as String? ?? '',
        contactPhone: map['contactPhone'] as String? ?? '',
        nickname: (map['nickname'] as String? ?? '').isEmpty ? null : map['nickname'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}