class AppUser {
  final String id;
  final String name;
  final String phone;
  final String? pushToken;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.pushToken,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'pushToken': pushToken ?? '',
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        pushToken: map['pushToken'] as String?,
      );
}
