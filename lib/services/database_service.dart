import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _defaultRadiusMeters = 10.0;

  Future<String> createMessage({
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
    required String text,
    required double latitude,
    required double longitude,
    double radiusMeters = _defaultRadiusMeters,
  }) async {
    final id = const Uuid().v4();
    final message = GeoMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      recipientName: recipientName,
      text: text,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    // Server timestamp: ordering must not depend on the sender's clock.
    final map = message.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('messages').doc(id).set(map);
    return id;
  }

  Future<void> updateMessage(
    String messageId, {
    required String text,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    // Full-document write (see markDelivered for the reason).
    final doc = await _firestore.collection('messages').doc(messageId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    data['text'] = text;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['radiusMeters'] = radiusMeters;
    data['editedAt'] = DateTime.now().toIso8601String();
    await _firestore.collection('messages').doc(messageId).set(data);
  }

  Future<void> deleteMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  Stream<List<GeoMessage>> getIncomingMessages(String userId) {
    // No orderBy: the collection may contain documents with inconsistent
    // createdAt types (string vs Timestamp) or missing the field, which makes
    // any Firestore orderBy query fail for the whole stream. Sort in memory.
    return _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GeoMessage.fromMap(doc.data()))
            .toList());
  }

  Stream<List<GeoMessage>> getSentMessages(String userId) {
    return _firestore
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GeoMessage.fromMap(doc.data()))
            .toList());
  }

  Future<List<GeoMessage>> getActiveGeofences(String userId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((doc) => GeoMessage.fromMap(doc.data())).toList();
  }

  Future<void> markDelivered(String messageId) async {
    // Full-document write: masked updates (update()) are rejected by the
    // Firestore rules for this project, while a full write is allowed.
    final doc = await _firestore.collection('messages').doc(messageId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    data['status'] = 'delivered';
    data['deliveredAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('messages').doc(messageId).set(data);
  }

  Stream<List<Contact>> getContacts(String userId) {
    return _firestore
        .collection('contacts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Contact.fromMap(doc.data())).toList());
  }

  Future<Set<String>> getContactIds(String userId) async {
    final snapshot = await _firestore
        .collection('contacts')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => doc.data()['contactId'] as String)
        .toSet();
  }

  Future<void> addContact(String userId, AppUser user) async {
    final contact = Contact(
      userId: userId,
      contactId: user.id,
      contactName: user.name,
      contactPhone: user.phone,
    );
    await _firestore
        .collection('contacts')
        .doc('${userId}_${user.id}')
        .set(contact.toMap());
  }

  Future<void> removeContact(String userId, String contactId) async {
    await _firestore.collection('contacts').doc('${userId}_$contactId').delete();
  }

  Future<void> setContactNickname(String userId, String contactId, String nickname) async {
    await _firestore
        .collection('contacts')
        .doc('${userId}_$contactId')
        .update({'nickname': nickname});
  }

  Future<List<AppUser>> searchUsers(String query) async {
    // Exact lookup by login (name) or synthetic email (phone). Substring
    // search would require loading the whole users collection.
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final email = q.contains('@') ? q : '$q@geomesenger.local';
    final results = await Future.wait([
      _firestore.collection('users').where('name', isEqualTo: q).get(),
      _firestore.collection('users').where('phone', isEqualTo: email).get(),
    ]);
    final found = <String, AppUser>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        found[doc.id] = AppUser.fromMap(doc.data());
      }
    }
    return found.values.toList();
  }

  Future<AppUser?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }
}
